# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

##
## TEST_SOURCE_FILE() Directive Path Disambiguation
## ==================================================
##
## TEST_SOURCE_FILE("...") names a source file to compile and link into a test
## executable outside the usual #include-driven convention -- the documented use
## case is a source file with no corresponding header at all. That name is
## resolved through the same FileFinder/PathMatcher path as every other source
## lookup in the project (test_build_planner.rb#extract_sources), so it was never
## given basename-only treatment to begin with: a uniquely-named source resolves
## whether given bare or with a path, while a source name that exists more than
## once in the project is a hard ambiguity error unless enough trailing path is
## given to identify exactly one.
##
## These tests confirm that inheritance actually holds: a project with two
## same-named, header-less source files in different source directories
## (e.g. src/alpha/calc.c and src/beta/calc.c, both defining calc_value())
## hard-errors naming both candidates when a test file's TEST_SOURCE_FILE("calc.c")
## is bare, while TEST_SOURCE_FILE("alpha/calc.c") or TEST_SOURCE_FILE("beta/calc.c")
## (enough trailing path to identify one of them) compiles, links, and runs
## correctly against exactly that one source.
##
## Test assets: assets/fixtures/test_source_file_duplicate_basenames/
##   - alpha/calc.c: calc_value() returning 111, no corresponding header
##   - beta/calc.c: calc_value() returning 222, no corresponding header
##   - test_calc_ambiguous.c: TEST_SOURCE_FILE("calc.c"), bare
##   - test_calc_alpha.c: TEST_SOURCE_FILE("alpha/calc.c"), asserts 111
##   - test_calc_beta.c: TEST_SOURCE_FILE("beta/calc.c"), asserts 222
##

ceedling_system_tests do

  before :all do
    @c = SystemContext.new
    @c.deploy_gem
  end

  after :all do
    @c.done!
  end

  before { @proj_name = unique_proj_name("dup_test_source_file") }

  describe "Deployed as a gem" do

    def copy_duplicate_calc_sources(proj_name)
      @c.with_context do
        Dir.chdir proj_name do
          FileUtils.mkdir_p 'src/alpha'
          FileUtils.mkdir_p 'src/beta'
          FileUtils.cp test_asset_path("test_source_file_duplicate_basenames/alpha/calc.c"), 'src/alpha/'
          FileUtils.cp test_asset_path("test_source_file_duplicate_basenames/beta/calc.c"), 'src/beta/'
        end
      end
    end

    # =========================================================================
    describe "A project with two same-named, header-less sources and a bare TEST_SOURCE_FILE() reference" do
    # =========================================================================

      before do
        @c.with_context do
          @c.ceedling_appcmd_exec("new #{@proj_name}")
        end
        copy_duplicate_calc_sources(@proj_name)
        @c.with_context do
          Dir.chdir @proj_name do
            FileUtils.cp test_asset_path("test_source_file_duplicate_basenames/test_calc_ambiguous.c"), 'test/'
          end
        end
      end

      it "hard-errors naming both candidates" do
        @c.with_context do
          Dir.chdir @proj_name do
            output = @c.ceedling_build_exec("test:all")
            expect(@c.last_exit_status).not_to eq(0)
            expect(output).to match(/Ambiguous/)
            expect(output).to match(/alpha[\/\\]calc\.c/)
            expect(output).to match(/beta[\/\\]calc\.c/)
          end
        end
      end

    end

    # =========================================================================
    describe "A project with two same-named, header-less sources, each identified by a disambiguating TEST_SOURCE_FILE() path" do
    # =========================================================================

      before do
        @c.with_context do
          @c.ceedling_appcmd_exec("new #{@proj_name}")
        end
        copy_duplicate_calc_sources(@proj_name)
        @c.with_context do
          Dir.chdir @proj_name do
            FileUtils.cp test_asset_path("test_source_file_duplicate_basenames/test_calc_alpha.c"), 'test/'
            FileUtils.cp test_asset_path("test_source_file_duplicate_basenames/test_calc_beta.c"), 'test/'
          end
        end
      end

      it "compiles, links, and passes both tests, each correctly linked against its own same-named source" do
        @c.with_context do
          Dir.chdir @proj_name do
            output = @c.ceedling_build_exec("test:all")
            expect(@c.last_exit_status).to eq(0)
            expect(output).to_not match(/Ambiguous/)
            expect(output).to match(/TESTED:\s+2/)
            expect(output).to match(/PASSED:\s+2/)
          end
        end
      end

    end

  end

end
