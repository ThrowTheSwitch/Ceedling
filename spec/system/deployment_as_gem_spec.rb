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
      test_case :application_commands_help
      test_case :project_build_tasks_plugins_help
    end

    describe "Basic test project execution" do
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
      #test_case :test_project_preprocessed_unity_parameterized_test_cases
      test_case :test_project_with_unity_exec_time
    end

    describe "Edge case parsing" do
      test_case :space_between_hash_and_include_is_valid
    end

    describe "Verbosity and output" do
      test_case :test_project_with_named_verbosity
      test_case :test_project_with_numerical_verbosity
      test_case :report_tests_raw_output_log_plugin
    end

    describe "Crash handling" do
      test_case :project_fail_because_of_crash_without_report
      test_case :project_fail_because_of_crash_with_report
    end

    describe "Backtrace with GDB" do
      before :all do
        @gdb_available = begin
          `gdb --version 2>&1`
          $?.exitstatus == 0
        rescue
          false
        end
      end

      before do
        skip "gdb is not installed or not in PATH" unless @gdb_available
      end

      test_case :backtrace_all_crash_test_cases_and_report
      test_case :backtrace_crash_targets_test_case_filter
      test_case :backtrace_crash_excludes_test_case_filter
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
end
