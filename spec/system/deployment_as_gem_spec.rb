# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
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
    FileUtils.rm_rf( 'GIT_COMMIT_SHA' )
    @c.done!
  end

  before { @proj_name = unique_proj_name("gem") }

  describe "Deployed as a gem" do
    before do
      FileUtils.rm_rf( 'GIT_COMMIT_SHA' )
      @c.with_context do
        @c.ceedling_appcmd_exec("new #{@proj_name}")
      end
    end

    describe "Version reporting" do
      test_case :can_report_version_no_git_commit_sha
      test_case :can_report_version_with_git_commit_sha
    end

    describe "Project creation" do
      test_case :can_create_projects
      test_case :does_not_contain_a_vendor_directory
    end

    describe "Help system" do
      test_case :can_fetch_non_project_help
      test_case :can_fetch_project_help
    end

    describe "Basic test project execution" do
      test_case :can_test_projects_with_success
      test_case :can_test_projects_with_success_test_alias
      test_case :can_test_projects_with_success_default
      test_case :can_test_projects_with_fail
      test_case :can_test_projects_with_fail_alias
      test_case :can_test_projects_with_fail_default
      test_case :can_test_projects_with_compile_error
      test_case :can_test_projects_with_test_file_directly_including_source_file
    end

    describe "Test builds with preprocessing" do
      test_case :can_test_projects_with_preprocessing_for_test_files_symbols_undefined
      test_case :can_test_projects_with_preprocessing_for_test_files_symbols_defined
      test_case :can_test_projects_with_preprocessing_for_mocks_success
      test_case :can_test_projects_with_preprocessing_for_mocks_intentional_build_failure
      test_case :can_test_projects_with_preprocessing_all
    end

    describe "Defines and configuration" do
      test_case :can_test_projects_with_test_name_replaced_defines_with_success
      test_case :can_test_projects_with_test_and_vendor_defines_with_success
      test_case :can_test_projects_with_both_mock_and_real_header
    end

    describe "Unity features" do
      test_case :can_test_projects_unity_parameterized_test_cases_with_success
      #test_case :can_test_projects_unity_parameterized_test_cases_with_preprocessor_with_success
      test_case :can_test_projects_with_unity_exec_time
    end

    describe "Edge case parsing" do
      test_case :can_test_projects_with_success_when_space_appears_between_hash_and_include
    end

    describe "Verbosity and output" do
      test_case :can_test_projects_with_named_verbosity
      test_case :can_test_projects_with_numerical_verbosity
      test_case :uses_report_tests_raw_output_log_plugin
    end

    describe "Crash handling" do
      test_case :test_run_of_projects_fail_because_of_crash_without_report
      test_case :test_run_of_projects_fail_because_of_crash_with_report
      test_case :execute_all_test_cases_from_crashing_test_runner_and_return_test_report_with_failue
      test_case :execute_and_collect_debug_logs_from_crashing_test_case_defined_by_test_case_argument_with_enabled_debug
      test_case :execute_and_collect_debug_logs_from_crashing_test_case_defined_by_exclude_test_case_argument_with_enabled_debug
    end

    describe "Test filtering" do
      test_case :can_run_single_test_with_full_test_case_name_from_test_file_with_success
      test_case :can_run_single_test_with_partial_test_case_name_from_test_file_with_success
      test_case :exclude_test_case_name_filter_works_and_only_one_test_case_is_executed
      test_case :none_of_test_is_executed_if_test_case_name_passed_does_not_fit_defined_in_test_file
      test_case :none_of_test_is_executed_if_test_case_name_and_exclude_test_case_name_is_the_same
      test_case :run_one_testcase_from_one_test_file_when_test_case_name_is_passed
    end
  end
end
