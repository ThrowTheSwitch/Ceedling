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
    # Ensure version commit file is cleaned up
    FileUtils.rm_rf( 'GIT_COMMIT_SHA' )
    @c.done!
  end

  before { @proj_name = unique_proj_name("vendor") }

  describe "Deployed in a project's `vendor` directory" do
    before do
      # Ensure version commit file is cleaned up
      FileUtils.rm_rf( 'GIT_COMMIT_SHA' )
      @c.with_context do
        @c.ceedling_appcmd_exec("new --local --docs #{@proj_name}")
      end
    end

    describe "Version reporting" do
      test_case :can_report_version_no_git_commit_sha
      test_case :can_report_version_with_git_commit_sha
    end

    describe "Project creation" do
      test_case :can_create_projects
      test_case :contains_a_vendor_directory
      test_case :contains_documentation
    end

    describe "Help system" do
      test_case :application_commands_help
      test_case :project_build_tasks_plugins_help
    end

    describe "Basic test execution" do
      test_case :test_project_success
      test_case :test_project_with_test_all_alias
      test_case :test_project_success_default_task
      test_case :test_project_fail
      test_case :test_project_fail_alias
      test_case :test_project_fail_default
      test_case :test_project_with_compile_error
      test_case :project_with_test_file_directly_including_source_file
    end

    describe "Test builds with preprocessing" do
      test_case :test_project_preprocessing_undefined_symbols
      test_case :test_project_preprocessing_defined_symbols
      test_case :test_project_with_preprocessing_for_mocks
      test_case :test_project_with_preprocessing_for_missing_mock
      test_case :test_project_with_preprocessing_all
    end

    describe "Defines and configuration" do
      test_case :test_project_with_per_file_defines
      test_case :test_project_with_test_and_vendor_defines
      test_case :test_project_with_both_mock_and_real_header
    end

    describe "Unity features" do
      test_case :test_project_unity_parameterized_test_cases
      test_case :test_project_preprocessed_unity_parameterized_test_cases
      test_case :test_project_with_unity_exec_time
    end

    describe "Edge cases parsing" do
      test_case :space_between_hash_and_include_is_valid
    end

    describe "Verbosity and output" do
      test_case :test_project_with_named_verbosity
      test_case :test_project_with_numerical_verbosity
      test_case :report_tests_raw_output_log_plugin
    end

    describe "Crash handling" do
      test_case :crash_none_reports_executable_crashed
      test_case :crash_none_writes_fail_results_file
      test_case :crash_simple_sigsegv_all_test_cases
      test_case :crash_simple_sigabrt_assert_failure
    end

    describe "Backtrace with GDB" do
      include_context "requires gdb"

      test_case :crash_gdb_sigsegv_all_test_cases
      test_case :crash_gdb_sigsegv_targets_test_case_filter
      test_case :crash_gdb_sigsegv_excludes_test_case_filter
      test_case :crash_gdb_sigabrt_assert_failure
    end

    describe "Test filtering" do
      test_case :run_single_test_with_full_name_filter
      test_case :run_single_test_with_partial_name_filter
      test_case :exclusion_filter_leaves_one_test_case
      test_case :no_tests_run_when_filter_matches_nothing
      test_case :no_tests_run_when_filter_and_exclusion_cancel
      test_case :run_one_test_case_with_name_filter
    end
  end

  describe "Deployed in a project's `vendor` directory with Git support" do
    before do
      @c.with_context do
        @c.ceedling_appcmd_exec("new --local --docs --gitsupport #{@proj_name}")
      end
    end

    describe "Project creation" do
      test_case :can_create_projects
      test_case :has_git_support
      test_case :contains_a_vendor_directory
      test_case :contains_documentation
    end

    describe "Basic test execution" do
      test_case :test_project_success
      test_case :project_with_test_file_directly_including_source_file
    end
  end

  describe "Deployed in a project's `vendor` directory without docs" do
    before do
      @c.with_context do
        @c.ceedling_appcmd_exec("new --local #{@proj_name}")
      end
    end

    describe "Project creation" do
      test_case :can_create_projects
      test_case :contains_a_vendor_directory
      test_case :does_not_contain_documentation
    end

    describe "Help system" do
      test_case :application_commands_help
      test_case :project_build_tasks_plugins_help
    end

    describe "Basic test execution" do
      test_case :test_project_success
      test_case :test_project_with_test_all_alias
      test_case :test_project_success_default_task
      test_case :test_project_fail
      test_case :test_project_fail_alias
      test_case :test_project_fail_default
      test_case :test_project_with_compile_error
      test_case :project_with_test_file_directly_including_source_file
    end

    describe "Test builds with preprocessing" do
      test_case :test_project_preprocessing_undefined_symbols
      test_case :test_project_preprocessing_defined_symbols
      test_case :test_project_with_preprocessing_for_mocks
      test_case :test_project_with_preprocessing_for_missing_mock
      test_case :test_project_with_preprocessing_all
    end

    describe "Defines and configuration" do
      test_case :test_project_with_per_file_defines
      test_case :test_project_with_test_and_vendor_defines
    end

    describe "Unity features" do
      test_case :test_project_unity_parameterized_test_cases
      test_case :test_project_with_unity_exec_time
    end
  end
end