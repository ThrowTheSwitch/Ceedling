# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

##
## Build Output Mirroring
## =======================
##
## A project may have two source files with the same basename in different
## configured source directories (e.g. src/foo/bar.c and src/baz/bar.c). Ceedling
## mirrors each into its own object path rather than flattening both into one
## shared path keyed only by basename -- collapsing them would leave the reverse
## object-to-source lookup that drives an actual compile with no path information
## left to tell them apart, an ambiguity Ceedling hard-errors on rather than
## silently guessing wrong.
##
## These tests confirm both same-named sources compile to distinct, correctly
## mirrored object paths and link into working binaries: a release build linking
## both into one executable, and two separate single-module tests each exercising
## one of the two same-named sources.
##
## Test assets: assets/fixtures/sources_with_duplicate_basenames/
##   - foo/bar.c, foo/bar.h: defines foo_bar_value() returning 111
##   - baz/bar.c, baz/bar.h: defines baz_bar_value() returning 222
##   - main.c: release entry point calling both and printing their results
##   - test_foo_bar.c: #includes "foo/bar.h", asserts foo_bar_value() == 111
##   - test_baz_bar.c: #includes "baz/bar.h", asserts baz_bar_value() == 222
##

ceedling_system_tests do

  before :all do
    @c = SystemContext.new
    @c.deploy_gem
  end

  after :all do
    @c.done!
  end

  before { @proj_name = unique_proj_name("dup_source_name") }

  describe "Deployed as a gem" do
    before do
      @c.with_context do
        @c.ceedling_appcmd_exec("new #{@proj_name}")

        Dir.chdir @proj_name do
          @c.merge_project_yml_for_test({ :project => { :release_build => true } })

          FileUtils.mkdir_p 'src/foo'
          FileUtils.mkdir_p 'src/baz'
          FileUtils.cp test_asset_path("sources_with_duplicate_basenames/foo/bar.c"), 'src/foo/'
          FileUtils.cp test_asset_path("sources_with_duplicate_basenames/foo/bar.h"), 'src/foo/'
          FileUtils.cp test_asset_path("sources_with_duplicate_basenames/baz/bar.c"), 'src/baz/'
          FileUtils.cp test_asset_path("sources_with_duplicate_basenames/baz/bar.h"), 'src/baz/'
          FileUtils.cp test_asset_path("sources_with_duplicate_basenames/main.c"), 'src/'
          FileUtils.cp test_asset_path("sources_with_duplicate_basenames/test_foo_bar.c"), 'test/'
          FileUtils.cp test_asset_path("sources_with_duplicate_basenames/test_baz_bar.c"), 'test/'
        end
      end
    end

    # =========================================================================
    describe "A project with two same-named source files in different source directories" do
    # =========================================================================

      it "compiles and links both same-named sources into one release binary" do
        @c.with_context do
          Dir.chdir @proj_name do
            output = @c.ceedling_build_exec("release")
            expect(@c.last_exit_status).to eq(0)
            expect(output).to_not match(/Ambiguous/)
            expect(output).to match(/^Linking /)

            expect(File.exist?('build/release/out/foo/bar.o')).to be true
            expect(File.exist?('build/release/out/baz/bar.o')).to be true

            binary = Dir.glob('build/artifacts/release/*.out').first
            run_output = `#{binary}`
            expect(run_output).to match(/foo_bar_value=111/)
            expect(run_output).to match(/baz_bar_value=222/)
          end
        end
      end

      it "compiles, links, and passes two separate tests each exercising one of the same-named sources" do
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
