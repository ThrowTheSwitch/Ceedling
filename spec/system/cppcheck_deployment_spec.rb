# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'
require_relative 'support/cppcheck_common_test_cases'

ceedling_system_tests do
  describe "Cppcheck" do
    include CppcheckCommonTestCases
    include_context "requires cppcheck"

    before :all do
      @c = SystemContext.new
      @c.deploy_gem
    end

    after :all do
      @c.done!
    end

    before { @proj_name = unique_proj_name("cppcheck") }

    describe "Basic operations" do
      before do
        @c.with_context do
          @c.ceedling_appcmd_exec("new --local #{@proj_name}")
        end
      end

      test_case :project_build_tasks_plugins_help_for_cppcheck
      test_case :can_run_cppcheck_on_whole_project
      test_case :can_run_cppcheck_on_single_file
      test_case :can_list_cppcheck_suppression_files
      test_case :can_create_xml_report
      test_case :can_create_text_report
      test_case :warns_when_no_reports_configured
    end

    describe "Findings and build failure" do
      before do
        @c.with_context do
          @c.ceedling_appcmd_exec("new --local #{@proj_name}")
        end
      end

      test_case :reports_findings_by_severity
      test_case :fail_build_breaks_build_on_matching_severity
      test_case :fail_build_passes_when_no_matching_severity
    end

    # The plugin must not make Cppcheck a dependency of unrelated builds. Regression
    # coverage for the same defect class as issue #1252 in the Gcov plugin.
    describe "Tool dependency scope" do
      before do
        @c.with_context do
          @c.ceedling_appcmd_exec("new --local #{@proj_name}")
        end
      end

      test_case :suppression_file_listing_needs_no_cppcheck
    end
  end
end
