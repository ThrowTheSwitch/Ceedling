# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'
require_relative 'support/cppcheck_common_test_cases'

ceedling_system_tests do
  describe "Cppcheck" do
    include CppcheckCommonTestCases

    before :all do
      @cppcheck_available = begin
        `cppcheck --version 2>&1`
        $?.exitstatus == 0
      rescue
        false
      end

      @c = SystemContext.new
      @c.deploy_gem
    end

    after :all do
      @c.done!
    end

    before { @proj_name = "fake_project" }
    after  { @c.with_context { FileUtils.rm_rf @proj_name } }

    describe "Basic operations" do
      before do
        skip "cppcheck is not installed or not in PATH" unless @cppcheck_available
        @c.with_context do
          @c.ceedling_appcmd_exec("new --local #{@proj_name}")
        end
      end

      test_case :can_fetch_project_help_for_cppcheck
      test_case :can_run_cppcheck_on_whole_project
      test_case :can_run_cppcheck_on_single_file
      test_case :can_list_cppcheck_suppression_files
      test_case :can_create_xml_report
      test_case :can_create_text_report
    end
  end
end
