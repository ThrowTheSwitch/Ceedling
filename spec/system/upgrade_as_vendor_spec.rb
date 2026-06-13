# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

ceedling_system_tests do
  include CommonSystemTestCases

  before :all do
    @c = SystemContext.new
    @c.deploy_gem
  end

  after :all do
    @c.done!
  end

  before { @proj_name = unique_proj_name("upgrade") }

  describe "Upgrade a project's `vendor` directory" do
    before do
      @c.with_context do
        @c.ceedling_appcmd_exec("new --local #{@proj_name}")
      end
    end

    describe "Initial project state" do
      describe "Project creation" do
        test_case :can_create_projects
        test_case :contains_a_vendor_directory
        test_case :does_not_contain_documentation
      end

      describe "Help system" do
        test_case :can_fetch_non_project_help
        test_case :can_fetch_project_help
      end

      describe "Basic test execution" do
        test_case :can_test_projects_with_success
        test_case :can_test_projects_with_success_test_alias
        test_case :can_test_projects_with_success_default
        test_case :can_test_projects_with_fail
        test_case :can_test_projects_with_fail_alias
        test_case :can_test_projects_with_fail_default
        test_case :can_test_projects_with_compile_error
        test_case :can_test_projects_with_test_file_directly_including_source_file
      end

      describe "Unity features" do
        test_case :can_test_projects_with_unity_exec_time
      end

      describe "Defines and configuration" do
        test_case :can_test_projects_with_test_and_vendor_defines_with_success
      end
    end

    describe "After upgrade" do
      describe "Upgrade operations" do
        test_case :can_upgrade_projects
        test_case :can_upgrade_projects_even_if_test_support_folder_does_not_exist
      end

      describe "Project structure" do
        test_case :contains_a_vendor_directory
        test_case :does_not_contain_documentation
      end

      describe "Help system" do
        test_case :can_fetch_non_project_help
        test_case :can_fetch_project_help
      end

      describe "Basic test execution" do
        test_case :can_test_projects_with_success
        test_case :can_test_projects_with_success_test_alias
        test_case :can_test_projects_with_success_default
        test_case :can_test_projects_with_fail
        test_case :can_test_projects_with_fail_alias
        test_case :can_test_projects_with_fail_default
        test_case :can_test_projects_with_compile_error
        test_case :can_test_projects_with_test_file_directly_including_source_file
      end

      describe "Unity features" do
        test_case :can_test_projects_with_unity_exec_time
      end

      describe "Defines and configuration" do
        test_case :can_test_projects_with_test_and_vendor_defines_with_success
      end
    end
  end

  describe "Upgrade error handling" do
    test_case :cannot_upgrade_non_existing_project
  end
end
