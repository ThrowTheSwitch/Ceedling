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
## A test may also mix both conventions: #include a header (implicit convention)
## alongside a TEST_SOURCE_FILE() entry sharing that header's own basename. In that
## case TEST_SOURCE_FILE() is authoritative -- its own resolution wins outright and
## the implicit convention's independent resolution for that basename is skipped
## entirely, rather than both landing in the source list (which would fail to link:
## two same-named files each defining the same functions). This holds even when the
## implicit resolution would already have been unambiguous on its own.
##
## Test assets: assets/fixtures/implicit_source_header_correspondence/
##   - alpha/dup.h, alpha/dup.c: declares/defines dup_value() returning 111
##   - beta/dup.h, beta/dup.c: declares/defines dup_value() returning 222
##   - test_dup_bare.c: #include "dup.h" (bare), asserts 111
##   - test_dup_alpha.c: #include "alpha/dup.h", asserts 111
##   - test_dup_beta.c: #include "beta/dup.h", asserts 222
##   - test_dup_override.c: #include "dup.h" (bare) + TEST_SOURCE_FILE("beta/dup.c"),
##     asserts 222 -- the directive overrides what the bare #include would have
##     implicitly resolved to on its own (alpha, 111)
##

ceedling_system_tests do

  before :all do
    @c = SystemContext.new
    @c.deploy_gem
  end

  after :all do
    @c.done!
  end

  before { @proj_name = unique_proj_name("dup_header_source_pair") }

  describe "Deployed as a gem" do

    def copy_duplicate_dup_pairs(proj_name)
      @c.with_context do
        Dir.chdir proj_name do
          FileUtils.mkdir_p 'src/alpha'
          FileUtils.mkdir_p 'src/beta'
          FileUtils.cp test_asset_path("implicit_source_header_correspondence/alpha/dup.h"), 'src/alpha/'
          FileUtils.cp test_asset_path("implicit_source_header_correspondence/alpha/dup.c"), 'src/alpha/'
          FileUtils.cp test_asset_path("implicit_source_header_correspondence/beta/dup.h"), 'src/beta/'
          FileUtils.cp test_asset_path("implicit_source_header_correspondence/beta/dup.c"), 'src/beta/'
        end
      end
    end

    # =========================================================================
    describe "A project with two same-named header+source pairs and a bare #include" do
    # =========================================================================

      before do
        @c.with_context do
          @c.ceedling_appcmd_exec("new #{@proj_name}")
        end
        copy_duplicate_dup_pairs(@proj_name)
        @c.with_context do
          Dir.chdir @proj_name do
            FileUtils.cp test_asset_path("implicit_source_header_correspondence/test_dup_bare.c"), 'test/'
          end
        end
      end

      it "resolves the header and its implicitly-compiled source to the first candidate by search-path order, logging a NOTICE naming the other" do
        @c.with_context do
          Dir.chdir @proj_name do
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

    end

    # =========================================================================
    describe "A project with two same-named header+source pairs, each identified by a disambiguating #include path" do
    # =========================================================================

      before do
        @c.with_context do
          @c.ceedling_appcmd_exec("new #{@proj_name}")
        end
        copy_duplicate_dup_pairs(@proj_name)
        @c.with_context do
          Dir.chdir @proj_name do
            FileUtils.cp test_asset_path("implicit_source_header_correspondence/test_dup_alpha.c"), 'test/'
            FileUtils.cp test_asset_path("implicit_source_header_correspondence/test_dup_beta.c"), 'test/'
          end
        end
      end

      it "compiles, links, and passes both tests, each correctly linked against its own same-named header/source pair" do
        @c.with_context do
          Dir.chdir @proj_name do
            output = @c.ceedling_build_exec("test:all")
            expect(@c.last_exit_status).to eq(0)
            expect(output).to_not match(/Multiple files matched/)
            expect(output).to match(/TESTED:\s+2/)
            expect(output).to match(/PASSED:\s+2/)
          end
        end
      end

    end

    # =========================================================================
    describe "A test file that both #includes a header and names a same-basename TEST_SOURCE_FILE()" do
    # =========================================================================

      before do
        @c.with_context do
          @c.ceedling_appcmd_exec("new #{@proj_name}")
        end
        copy_duplicate_dup_pairs(@proj_name)
        @c.with_context do
          Dir.chdir @proj_name do
            FileUtils.cp test_asset_path("implicit_source_header_correspondence/test_dup_override.c"), 'test/'
          end
        end
      end

      it "lets TEST_SOURCE_FILE() override the implicit convention's own resolution rather than compiling both same-named sources" do
        @c.with_context do
          Dir.chdir @proj_name do
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

    end

  end

end
