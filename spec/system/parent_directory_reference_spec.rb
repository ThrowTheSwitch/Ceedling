# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

##
## Parent Directory (..) References
## =================================
##
## Both #include directives and TEST_SOURCE_FILE() are resolved against a test
## file's own directory, exactly as a real compiler resolves a directory-relative
## quoted #include -- a query naming ".." to reach a sibling directory must
## resolve the same way a real filesystem path would, under every preprocessing
## mode a project can select.
##
## Test assets: assets/fixtures/parent_directory_references/
##   - common/helper.h, common/helper.c: declares/defines helper_value() returning 111
##   - unit/test_dotdot_include.c: #include "../common/helper.h", asserts 111
##   - alpha/extra.c: extra_value() returning 222, no corresponding header
##   - unit/test_dotdot_source.c: TEST_SOURCE_FILE("../alpha/extra.c"), asserts 222
##

ceedling_system_tests do

  before :all do
    @c = SystemContext.new
    @c.deploy_gem
  end

  after :all do
    @c.done!
  end

  before { @proj_name = unique_proj_name("dotdot") }

  describe "Deployed as a gem" do
    def copy_dotdot_include_assets(proj_name)
      @c.with_context do
        Dir.chdir proj_name do
          FileUtils.mkdir_p 'test/common'
          FileUtils.mkdir_p 'test/unit'
          FileUtils.cp test_asset_path("parent_directory_references/common/helper.h"), 'test/common/'
          FileUtils.cp test_asset_path("parent_directory_references/common/helper.c"), 'test/common/'
          FileUtils.cp test_asset_path("parent_directory_references/unit/test_dotdot_include.c"), 'test/unit/'
        end
      end
    end

    def copy_dotdot_source_assets(proj_name)
      @c.with_context do
        Dir.chdir proj_name do
          FileUtils.mkdir_p 'test/alpha'
          FileUtils.mkdir_p 'test/unit'
          FileUtils.cp test_asset_path("parent_directory_references/alpha/extra.c"), 'test/alpha/'
          FileUtils.cp test_asset_path("parent_directory_references/unit/test_dotdot_source.c"), 'test/unit/'
        end
      end
    end

    # =========================================================================
    describe "A test file that #includes a header in a sibling directory via .." do
    # =========================================================================

      before do
        @c.with_context do
          @c.ceedling_appcmd_exec("new #{@proj_name}")
        end
        copy_dotdot_include_assets(@proj_name)
      end

      it "compiles, links, and passes with preprocessing disabled -- the bare-scan fallback path" do
        @c.with_context do
          Dir.chdir @proj_name do
            settings = { :project => { :use_test_preprocessor => :none } }
            @c.merge_project_yml_for_test(settings)

            output = @c.ceedling_build_exec("test:all")
            expect(@c.last_exit_status).to eq(0)
            expect(output).to match(/TESTED:\s+1/)
            expect(output).to match(/PASSED:\s+1/)
          end
        end
      end

      it "compiles, links, and passes with full test preprocessing enabled -- the GCC directives-only path" do
        @c.with_context do
          Dir.chdir @proj_name do
            settings = { :project => { :use_test_preprocessor => :all } }
            @c.merge_project_yml_for_test(settings)

            output = @c.ceedling_build_exec("test:all")
            expect(@c.last_exit_status).to eq(0)
            expect(output).to match(/TESTED:\s+1/)
            expect(output).to match(/PASSED:\s+1/)
          end
        end
      end

    end

    # =========================================================================
    describe "A test file with a TEST_SOURCE_FILE() entry naming a sibling directory via .." do
    # =========================================================================

      before do
        @c.with_context do
          @c.ceedling_appcmd_exec("new #{@proj_name}")
        end
        copy_dotdot_source_assets(@proj_name)
      end

      it "compiles, links, and passes, resolving the directive against the test file's own directory" do
        @c.with_context do
          Dir.chdir @proj_name do
            output = @c.ceedling_build_exec("test:all")
            expect(@c.last_exit_status).to eq(0)
            expect(output).to match(/TESTED:\s+1/)
            expect(output).to match(/PASSED:\s+1/)
          end
        end
      end

    end

    # =========================================================================
    describe "A `ceedling test:` task name containing .." do
    # =========================================================================

      before do
        @c.with_context do
          @c.ceedling_appcmd_exec("new #{@proj_name}")
        end
        copy_dotdot_include_assets(@proj_name)
      end

      it "fails clearly, naming .. as unsupported rather than a generic file-not-found" do
        @c.with_context do
          Dir.chdir @proj_name do
            output = @c.ceedling_build_exec("test:../unit/test_dotdot_include")
            expect(@c.last_exit_status).to_not eq(0)
            expect(output).to match(/\.\./)
            expect(output).to match(/context/i)
          end
        end
      end

    end

  end

end
