# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

##
## TEST_SOURCE_FILE() Build Directive
## ====================================
##
## Everything TEST_SOURCE_FILE() itself is responsible for, collected in one
## file: resolving a bare or path-disambiguated entry the same way any other
## source lookup in the project resolves (test_source_file_directive_resolver.rb),
## overriding the implicit header/source convention when an entry shares a
## header's own basename, and -- the `-:` addition -- removing a named file
## from a test's final compile/link list outright, regardless of how that
## file got there in the first place.
##
## Path disambiguation (bare vs. path-qualified entries):
##
## TEST_SOURCE_FILE("...") names a source file to compile and link into a test
## executable outside the usual #include-driven convention -- the documented use
## case is a source file with no corresponding header at all. That name is
## resolved through the same FileFinder/PathMatcher path as every other source
## lookup in the project, so it was never given basename-only treatment to begin
## with: a uniquely-named source resolves whether given bare or with a path,
## while a source name that exists more than once in the project resolves to
## the first candidate by :paths search-path order (with an ℹ️ NOTICE naming
## what else matched) unless enough trailing path is given to identify exactly
## one outright.
##
## Test assets: assets/fixtures/test_source_file_duplicate_basenames/
##   - alpha/calc.c: calc_value() returning 111, no corresponding header
##   - beta/calc.c: calc_value() returning 222, no corresponding header
##   - test_calc_ambiguous.c: TEST_SOURCE_FILE("calc.c"), bare
##   - test_calc_alpha.c: TEST_SOURCE_FILE("alpha/calc.c"), asserts 111
##   - test_calc_beta.c: TEST_SOURCE_FILE("beta/calc.c"), asserts 222
##
## Overriding and removing (assets/fixtures/implicit_source_header_correspondence/):
##
## A test may mix TEST_SOURCE_FILE() with the implicit header/source convention.
## When a directive entry shares a header's own basename, the directive is
## authoritative outright -- its own resolution wins and the implicit
## convention's independent resolution for that basename is skipped entirely,
## rather than both landing in the source list (which would fail to link: two
## same-named files each defining the same functions). This holds even when the
## implicit resolution would already have been unambiguous on its own.
##
## A `-:`-prefixed entry goes further: it removes a named file from the final
## compile/link list outright, independent of the basename-override mechanism
## above and regardless of how the file arrived there -- the implicit
## convention, a positive directive, or a Partial.
##
##   - alpha/dup.h, alpha/dup.c: declares/defines dup_value() returning 111
##   - beta/dup.h, beta/dup.c: declares/defines dup_value() returning 222
##   - gamma/dup_gamma.c: defines dup_value() returning 333, no header of its
##     own -- only ever enters a build via a positive TEST_SOURCE_FILE() entry,
##     and its basename shares no stem with "dup", so referencing it never
##     engages the basename-stem override mechanism either
##   - test_dup_override.c: #include "dup.h" (bare) + TEST_SOURCE_FILE("beta/dup.c"),
##     asserts 222 -- the directive overrides what the bare #include would have
##     implicitly resolved to on its own (alpha, 111)
##   - test_dup_subtractive.c: #include "alpha/dup.h" (unambiguous, no other
##     entry shares its "dup" stem) + TEST_SOURCE_FILE("-:alpha/dup.c") +
##     TEST_SOURCE_FILE("gamma/dup_gamma.c"), asserts 333 -- the unambiguous
##     implicit match is removed outright, independent of the basename-override
##     mechanism above, and a differently-named file supplied in its place
##   - test_dup_subtractive_noop.c: #include "alpha/dup.h" +
##     TEST_SOURCE_FILE("-:beta/dup.c"), asserts 111 -- removing a real file
##     that was never part of this test's own list changes nothing
##
## copy_duplicate_dup_pairs (the alpha/beta dup.{h,c} fixture pair used by the
## "overriding and removing" scenarios below) is shared with
## implicit_source_header_correspondence_disambiguation_spec.rb via
## spec_system_helper.rb -- both files build scenarios around this same
## same-basename ambiguity.
##

ceedling_system_tests do
  include_context "a fresh ceedling gem project", "test_source_file_directive"

  describe "Deployed as a gem" do

    # Unique to this file -- the same-basename-but-no-header shape TEST_SOURCE_FILE()
    # itself is documented for, distinct from copy_duplicate_dup_pairs's header+source
    # pairs (which exercise TEST_SOURCE_FILE() overriding/removing an implicit match).
    def copy_duplicate_calc_sources
      in_project do
        copy_fixture("test_source_file_duplicate_basenames/alpha/calc.c", 'src/alpha')
        copy_fixture("test_source_file_duplicate_basenames/beta/calc.c", 'src/beta')
      end
    end

    def copy_gamma_dup_replacement
      in_project { copy_fixture("implicit_source_header_correspondence/gamma/dup_gamma.c", 'src/gamma') }
    end

    # =========================================================================
    describe "A project with two same-named, header-less sources and a bare TEST_SOURCE_FILE() reference" do
    # =========================================================================

      before do
        copy_duplicate_calc_sources
        in_project { copy_fixture("test_source_file_duplicate_basenames/test_calc_ambiguous.c", 'test') }
      end

      it "resolves to the first candidate by search-path order, logging a NOTICE naming the other" do
        in_project do
          output = @c.ceedling_build_exec("test:all")
          expect(@c.last_exit_status).to eq(0)
          expect(output).to match(/Multiple files matched/)
          expect(output).to match(/alpha[\/\\]calc\.c/)
          expect(output).to match(/beta[\/\\]calc\.c/)
          expect(output).to match(/TESTED:\s+1/)
          expect(output).to match(/PASSED:\s+1/)
        end
      end

    end

    # =========================================================================
    describe "A project with two same-named, header-less sources, each identified by a disambiguating TEST_SOURCE_FILE() path" do
    # =========================================================================

      before do
        copy_duplicate_calc_sources
        in_project do
          copy_fixture("test_source_file_duplicate_basenames/test_calc_alpha.c", 'test')
          copy_fixture("test_source_file_duplicate_basenames/test_calc_beta.c", 'test')
        end
      end

      it "compiles, links, and passes both tests, each correctly linked against its own same-named source" do
        in_project do
          output = @c.ceedling_build_exec("test:all")
          expect(@c.last_exit_status).to eq(0)
          expect(output).to_not match(/Ambiguous/)
          expect(output).to match(/TESTED:\s+2/)
          expect(output).to match(/PASSED:\s+2/)
        end
      end

    end

    # =========================================================================
    describe "A test file that both #includes a header and names a same-basename TEST_SOURCE_FILE()" do
    # =========================================================================

      before do
        copy_duplicate_dup_pairs
        in_project { copy_fixture("implicit_source_header_correspondence/test_dup_override.c", 'test') }
      end

      it "lets TEST_SOURCE_FILE() override the implicit convention's own resolution rather than compiling both same-named sources" do
        in_project do
          output = @c.ceedling_build_exec("test:all")
          expect(@c.last_exit_status).to eq(0)
          expect(output).to match(/TESTED:\s+1/)
          expect(output).to match(/PASSED:\s+1/)

          # The bare #include "dup.h" is still itself ambiguous (validate_header_includes
          # is untouched by the override), so its own NOTICE still fires -- but the
          # correctly-linked pass above already proves only beta/dup.c was ever compiled,
          # not both. A duplicate-symbol link error would have failed the build otherwise.
          expect(File.exist?('build/test/out/test_dup_override/beta/dup.o')).to be true
          expect(File.exist?('build/test/out/test_dup_override/alpha/dup.o')).to be false

          # A second, distinct NOTICE -- from extract_sources's own override, not the
          # header-ambiguity NOTICE above -- names the winning TEST_SOURCE_FILE() entry
          # and the #include it overrode.
          expect(output).to match(/TEST_SOURCE_FILE\(\).*beta[\/\\]dup\.c/)
          expect(output).to match(/dup\.h/)
        end
      end

    end

    # =========================================================================
    describe "A test file that removes an unambiguously-matched implicit source and supplies a different one" do
    # =========================================================================

      before do
        copy_duplicate_dup_pairs
        copy_gamma_dup_replacement
        in_project { copy_fixture("implicit_source_header_correspondence/test_dup_subtractive.c", 'test') }
      end

      it "never compiles the removed file, compiles and links the supplied one instead, and logs a NOTICE naming the removal" do
        in_project do
          output = @c.ceedling_build_exec("test:all")
          expect(@c.last_exit_status).to eq(0)
          expect(output).to match(/TESTED:\s+1/)
          expect(output).to match(/PASSED:\s+1/)

          expect(File.exist?('build/test/out/test_dup_subtractive/alpha/dup.o')).to be false
          expect(File.exist?('build/test/out/test_dup_subtractive/gamma/dup_gamma.o')).to be true

          expect(output).to match(/TEST_SOURCE_FILE\(.*-:alpha[\/\\]dup\.c.*\)/)
          expect(output).to match(/removed/)
          expect(output).to match(/alpha[\/\\]dup\.c/)
        end
      end

    end

    # =========================================================================
    describe "A test file whose subtractive entry names a file never part of its own compile/link list" do
    # =========================================================================

      before do
        copy_duplicate_dup_pairs
        in_project { copy_fixture("implicit_source_header_correspondence/test_dup_subtractive_noop.c", 'test') }
      end

      it "builds and passes normally, logging no removal NOTICE" do
        in_project do
          output = @c.ceedling_build_exec("test:all")
          expect(@c.last_exit_status).to eq(0)
          expect(output).to match(/TESTED:\s+1/)
          expect(output).to match(/PASSED:\s+1/)

          expect(File.exist?('build/test/out/test_dup_subtractive_noop/alpha/dup.o')).to be true

          expect(output).to_not match(/TEST_SOURCE_FILE\(.*removed/)
        end
      end

    end

  end

end
