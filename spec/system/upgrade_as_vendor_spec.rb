# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

describe "Ceedling" do
  include CeedlingTestCases

  before :all do
    @c = SystemContext.new
    @c.deploy_gem
  end

  after :all do
    @c.done!
  end

  before { @proj_name = "fake_project" }
  after { @c.with_context { FileUtils.rm_rf @proj_name } }

  describe "Upgrade a Project's `vendor` Directory" do
    before do
      @c.with_context do
        `bundle exec ruby -S ceedling new --local #{@proj_name} 2>&1`
      end
    end

    describe "Initial Project State" do
      describe "Project Creation" do
        test_case :can_create_projects
        test_case :contains_a_vendor_directory
        test_case :does_not_contain_documentation
      end

      describe "Help System" do
        test_case :can_fetch_non_project_help
        test_case :can_fetch_project_help
      end

      describe "Basic Test Execution" do
        test_case :can_test_projects_with_success
        test_case :can_test_projects_with_success_test_alias
        test_case :can_test_projects_with_success_default
        test_case :can_test_projects_with_fail
        test_case :can_test_projects_with_fail_alias
        test_case :can_test_projects_with_fail_default
        test_case :can_test_projects_with_compile_error
      end

      describe "Unity Features" do
        test_case :can_test_projects_with_unity_exec_time
      end

      describe "Defines and Configuration" do
        test_case :can_test_projects_with_test_and_vendor_defines_with_success
      end
    end

    describe "After Upgrade" do
      describe "Upgrade Operations" do
        test_case :can_upgrade_projects
        test_case :can_upgrade_projects_even_if_test_support_folder_does_not_exist
      end

      describe "Project Structure" do
        test_case :contains_a_vendor_directory
        test_case :does_not_contain_documentation
      end

      describe "Help System" do
        test_case :can_fetch_non_project_help
        test_case :can_fetch_project_help
      end

      describe "Basic Test Execution" do
        test_case :can_test_projects_with_success
        test_case :can_test_projects_with_success_test_alias
        test_case :can_test_projects_with_success_default
        test_case :can_test_projects_with_fail
        test_case :can_test_projects_with_fail_alias
        test_case :can_test_projects_with_fail_default
        test_case :can_test_projects_with_compile_error
      end

      describe "Unity Features" do
        test_case :can_test_projects_with_unity_exec_time
      end

      describe "Defines and Configuration" do
        test_case :can_test_projects_with_test_and_vendor_defines_with_success
      end
    end
  end

  describe "Upgrade Error Handling" do
    test_case :cannot_upgrade_non_existing_project
  end
end
