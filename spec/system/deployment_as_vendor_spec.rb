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
    # Ensure version commit file is cleaned up
    FileUtils.rm_rf( 'GIT_COMMIT_SHA' )
    @c.done!
  end

  before { @proj_name = "fake_project" }
  after { @c.with_context { FileUtils.rm_rf @proj_name } }

  describe "Deployed in a Project's `vendor` Directory" do
    before do
      # Ensure version commit file is cleaned up
      FileUtils.rm_rf( 'GIT_COMMIT_SHA' )
      @c.with_context do
        `bundle exec ruby -S ceedling new --local --docs #{@proj_name} 2>&1`
      end
    end

    describe "Version Reporting" do
      test_case :can_report_version_no_git_commit_sha
      test_case :can_report_version_with_git_commit_sha
    end

    describe "Project Creation" do
      test_case :can_create_projects
      test_case :contains_a_vendor_directory
      test_case :contains_documentation
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

    describe "Test Builds with Preprocessing" do
      test_case :can_test_projects_with_preprocessing_for_test_files_symbols_undefined
      test_case :can_test_projects_with_preprocessing_for_test_files_symbols_defined
      test_case :can_test_projects_with_preprocessing_for_mocks_success
      test_case :can_test_projects_with_preprocessing_for_mocks_intentional_build_failure
      test_case :can_test_projects_with_preprocessing_all
    end

    describe "Defines and Configuration" do
      test_case :can_test_projects_with_test_name_replaced_defines_with_success
      test_case :can_test_projects_with_test_and_vendor_defines_with_success
      test_case :can_test_projects_with_both_mock_and_real_header
    end

    describe "Unity Features" do
      test_case :can_test_projects_unity_parameterized_test_cases_with_success
      #test_case :can_test_projects_unity_parameterized_test_cases_with_preprocessor_with_success
      test_case :can_test_projects_with_unity_exec_time
    end

    describe "Edge Cases Parsing" do
      test_case :can_test_projects_with_success_when_space_appears_between_hash_and_include
    end

    describe "Verbosity and Output" do
      test_case :can_test_projects_with_named_verbosity
      test_case :can_test_projects_with_numerical_verbosity
      test_case :uses_report_tests_raw_output_log_plugin
    end

    describe "Crash Handling" do
      test_case :test_run_of_projects_fail_because_of_crash_without_report
      test_case :test_run_of_projects_fail_because_of_crash_with_report
      test_case :execute_all_test_cases_from_crashing_test_runner_and_return_test_report_with_failue
      test_case :execute_and_collect_debug_logs_from_crashing_test_case_defined_by_test_case_argument_with_enabled_debug
      test_case :execute_and_collect_debug_logs_from_crashing_test_case_defined_by_exclude_test_case_argument_with_enabled_debug
    end

    describe "Command-line Argument Handling" do
      test_case :confirm_if_notification_for_cmdline_args_not_enabled_is_disabled
    end

    describe "Test Filtering" do
      test_case :can_run_single_test_with_full_test_case_name_from_test_file_with_success
      test_case :can_run_single_test_with_partial_test_case_name_from_test_file_with_success
      test_case :exclude_test_case_name_filter_works_and_only_one_test_case_is_executed
      test_case :none_of_test_is_executed_if_test_case_name_passed_does_not_fit_defined_in_test_file
      test_case :none_of_test_is_executed_if_test_case_name_and_exclude_test_case_name_is_the_same
      test_case :run_one_testcase_from_one_test_file_when_test_case_name_is_passed
    end
  end

  describe "Deployed in a Project's `vendor` Directory with Git Support" do
    before do
      @c.with_context do
        `bundle exec ruby -S ceedling new --local --docs --gitsupport #{@proj_name} 2>&1`
      end
    end

    describe "Project Creation" do
      test_case :can_create_projects
      test_case :has_git_support
      test_case :contains_a_vendor_directory
      test_case :contains_documentation
    end

    describe "Basic Test Execution" do
      test_case :can_test_projects_with_success
    end
  end

  describe "Deployed in a Project's `vendor` Directory Without Docs" do
    before do
      @c.with_context do
        `bundle exec ruby -S ceedling new --local #{@proj_name} 2>&1`
      end
    end

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

    describe "Test Builds with Preprocessing" do
      test_case :can_test_projects_with_preprocessing_for_test_files_symbols_undefined
      test_case :can_test_projects_with_preprocessing_for_test_files_symbols_defined
      test_case :can_test_projects_with_preprocessing_for_mocks_success
      test_case :can_test_projects_with_preprocessing_for_mocks_intentional_build_failure
      test_case :can_test_projects_with_preprocessing_all
    end

    describe "Defines and Configuration" do
      test_case :can_test_projects_with_test_name_replaced_defines_with_success
      test_case :can_test_projects_with_test_and_vendor_defines_with_success
    end

    describe "Unity Features" do
      test_case :can_test_projects_unity_parameterized_test_cases_with_success
      test_case :can_test_projects_with_unity_exec_time
    end
  end
end