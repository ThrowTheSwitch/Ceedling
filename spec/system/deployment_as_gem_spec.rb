# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
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
    FileUtils.rm_rf( 'GIT_COMMIT_SHA' )
    @c.done!
  end

  before { @proj_name = "fake_project" }
  after { @c.with_context { FileUtils.rm_rf @proj_name } }

  describe "deployed as a gem" do
    before do
      FileUtils.rm_rf( 'GIT_COMMIT_SHA' )
      @c.with_context do
        `bundle exec ruby -S ceedling new #{@proj_name} 2>&1`
      end
    end

    it { can_report_version_no_git_commit_sha }
    it { can_report_version_with_git_commit_sha }
    it { can_create_projects }
    it { does_not_contain_a_vendor_directory }
    it { can_fetch_non_project_help }
    it { can_fetch_project_help }
    it { can_test_projects_with_success }
    it { can_test_projects_with_success_test_alias }
    it { can_test_projects_with_test_name_replaced_defines_with_success }
    it { can_test_projects_unity_parameterized_test_cases_with_success }
    #it { can_test_projects_unity_parameterized_test_cases_with_preprocessor_with_success }
    it { can_test_projects_with_preprocessing_for_test_files_symbols_undefined }
    it { can_test_projects_with_preprocessing_for_test_files_symbols_defined }
    it { can_test_projects_with_preprocessing_for_mocks_success }
    it { can_test_projects_with_preprocessing_for_mocks_intentional_build_failure }
    it { can_test_projects_with_preprocessing_all }
    it { can_test_projects_with_success_default }
    it { can_test_projects_with_unity_exec_time }
    it { can_test_projects_with_test_and_vendor_defines_with_success }
    it { can_test_projects_with_fail }
    it { can_test_projects_with_fail_alias }
    it { can_test_projects_with_fail_default }
    it { can_test_projects_with_compile_error }
    it { can_test_projects_with_both_mock_and_real_header }
    it { can_test_projects_with_success_when_space_appears_between_hash_and_include }
    it { can_test_projects_with_named_verbosity }
    it { can_test_projects_with_numerical_verbosity }
    it { uses_report_tests_raw_output_log_plugin }
    it { test_run_of_projects_fail_because_of_crash_without_report }
    it { test_run_of_projects_fail_because_of_crash_with_report }
    it { execute_all_test_cases_from_crashing_test_runner_and_return_test_report_with_failue }
    it { execute_and_collect_debug_logs_from_crashing_test_case_defined_by_test_case_argument_with_enabled_debug }
    it { execute_and_collect_debug_logs_from_crashing_test_case_defined_by_exclude_test_case_argument_with_enabled_debug }
    it { confirm_if_notification_for_cmdline_args_not_enabled_is_disabled }
    it { can_run_single_test_with_full_test_case_name_from_test_file_with_success }
    it { can_run_single_test_with_partial_test_case_name_from_test_file_with_success }
    it { exclude_test_case_name_filter_works_and_only_one_test_case_is_executed }
    it { none_of_test_is_executed_if_test_case_name_passed_does_not_fit_defined_in_test_file }
    it { none_of_test_is_executed_if_test_case_name_and_exclude_test_case_name_is_the_same }
    it { run_one_testcase_from_one_test_file_when_test_case_name_is_passed }
  end

end
