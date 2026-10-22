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
  include_context "a fresh ceedling gem project", "dotdot"

  describe "Deployed as a gem" do
    def copy_dotdot_include_assets
      in_project do
        copy_fixture("parent_directory_references/common/helper.h", 'test/common')
        copy_fixture("parent_directory_references/common/helper.c", 'test/common')
        copy_fixture("parent_directory_references/unit/test_dotdot_include.c", 'test/unit')
      end
    end

    def copy_dotdot_source_assets
      in_project do
        copy_fixture("parent_directory_references/alpha/extra.c", 'test/alpha')
        copy_fixture("parent_directory_references/unit/test_dotdot_source.c", 'test/unit')
      end
    end

    # =========================================================================
    describe "A test file that #includes a header in a sibling directory via .." do
    # =========================================================================

      before { copy_dotdot_include_assets }

      it "compiles, links, and passes with preprocessing disabled -- the bare-scan fallback path" do
        in_project do
          settings = { :project => { :use_test_preprocessor => :none } }
          @c.merge_project_yml_for_test(settings)

          output = @c.ceedling_build_exec("test:all")
          expect(@c.last_exit_status).to eq(0)
          expect(output).to match(/TESTED:\s+1/)
          expect(output).to match(/PASSED:\s+1/)
        end
      end

      it "compiles, links, and passes with full test preprocessing enabled -- the GCC directives-only path" do
        in_project do
          settings = { :project => { :use_test_preprocessor => :all } }
          @c.merge_project_yml_for_test(settings)

          output = @c.ceedling_build_exec("test:all")
          expect(@c.last_exit_status).to eq(0)
          expect(output).to match(/TESTED:\s+1/)
          expect(output).to match(/PASSED:\s+1/)
        end
      end

    end

    # =========================================================================
    describe "A test file with a TEST_SOURCE_FILE() entry naming a sibling directory via .." do
    # =========================================================================

      before { copy_dotdot_source_assets }

      it "compiles, links, and passes, resolving the directive against the test file's own directory" do
        in_project do
          output = @c.ceedling_build_exec("test:all")
          expect(@c.last_exit_status).to eq(0)
          expect(output).to match(/TESTED:\s+1/)
          expect(output).to match(/PASSED:\s+1/)
        end
      end

    end

    # =========================================================================
    describe "A `ceedling test:` task name containing .." do
    # =========================================================================

      before { copy_dotdot_include_assets }

      it "fails clearly, naming .. as unsupported rather than a generic file-not-found" do
        in_project do
          output = @c.ceedling_build_exec("test:../unit/test_dotdot_include")
          expect(@c.last_exit_status).to_not eq(0)
          expect(output).to match(/\.\./)
          expect(output).to match(/context/i)
        end
      end

    end

  end

end
