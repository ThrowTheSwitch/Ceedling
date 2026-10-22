# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

##
## Implicit Source/Header Correspondence Disambiguation
## =======================================================
##
## Beyond the explicit TEST_SOURCE_FILE() build directive macro, Ceedling has a
## second, implicit convention for compiling a module under test into a test
## executable: a test file #includes a header, and -- absent a mock for that
## header -- Ceedling looks for and compiles the header's own same-named source
## file (test_build_planner.rb#extract_sources). That lookup shares the same
## FileFinder/PathMatcher path every other lookup in the project uses, driven
## by whatever path the #include itself carried, so it inherits disambiguation
## for free exactly as TEST_SOURCE_FILE() does.
##
## These tests confirm that inheritance actually holds for the implicit
## convention specifically: a project with two same-named header+source pairs
## in different directories (e.g. src/alpha/dup.{h,c} and src/beta/dup.{h,c})
## resolves a bare #include "dup.h" to the first candidate by search-path order
## (src/alpha), pulling in its correctly matching source and logging an ℹ️
## NOTICE naming src/beta/dup.h as passed over, while #include "alpha/dup.h" or
## #include "beta/dup.h" (enough trailing path to identify one of them) compiles
## and links against exactly that one pair, logging nothing.
##
## Coverage for TEST_SOURCE_FILE() itself -- both mixing with this implicit
## convention (overriding a same-basename match) and its own `-:` removal
## notation -- lives together in spec/system/test_source_file_directive_spec.rb,
## which reuses this same alpha/beta dup.{h,c} fixture pair (via the shared
## copy_duplicate_dup_pairs helper in spec_system_helper.rb).
##
## Test assets: assets/fixtures/implicit_source_header_correspondence/
##   - alpha/dup.h, alpha/dup.c: declares/defines dup_value() returning 111
##   - beta/dup.h, beta/dup.c: declares/defines dup_value() returning 222
##   - test_dup_bare.c: #include "dup.h" (bare), asserts 111
##   - test_dup_alpha.c: #include "alpha/dup.h", asserts 111
##   - test_dup_beta.c: #include "beta/dup.h", asserts 222
##

ceedling_system_tests do
  include_context "a fresh ceedling gem project", "dup_header_source_pair"

  describe "Deployed as a gem" do

    # =========================================================================
    describe "A project with two same-named header+source pairs and a bare #include" do
    # =========================================================================

      before do
        copy_duplicate_dup_pairs
        in_project { copy_fixture("implicit_source_header_correspondence/test_dup_bare.c", 'test') }
      end

      it "resolves the header and its implicitly-compiled source to the first candidate by search-path order, logging a NOTICE naming the other" do
        in_project do
          output = @c.ceedling_build_exec("test:all")
          expect(@c.last_exit_status).to eq(0)
          expect(output).to match(/Multiple files matched/)
          expect(output).to match(/alpha[\/\\]dup\.h/)
          expect(output).to match(/beta[\/\\]dup\.h/)
          expect(output).to match(/TESTED:\s+1/)
          expect(output).to match(/PASSED:\s+1/)
        end
      end

    end

    # =========================================================================
    describe "A project with two same-named header+source pairs, each identified by a disambiguating #include path" do
    # =========================================================================

      before do
        copy_duplicate_dup_pairs
        in_project do
          copy_fixture("implicit_source_header_correspondence/test_dup_alpha.c", 'test')
          copy_fixture("implicit_source_header_correspondence/test_dup_beta.c", 'test')
        end
      end

      it "compiles, links, and passes both tests, each correctly linked against its own same-named header/source pair" do
        in_project do
          output = @c.ceedling_build_exec("test:all")
          expect(@c.last_exit_status).to eq(0)
          expect(output).to_not match(/Multiple files matched/)
          expect(output).to match(/TESTED:\s+2/)
          expect(output).to match(/PASSED:\s+2/)
        end
      end

    end

  end

end
