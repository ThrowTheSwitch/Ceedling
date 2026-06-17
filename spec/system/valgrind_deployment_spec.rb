# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'
require_relative 'support/valgrind_common_test_cases'

ceedling_system_tests do
  describe "Valgrind" do
    include ValgrindCommonTestCases

    before :all do
      @valgrind_available = begin
        `valgrind --version 2>&1`
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

    before { @proj_name = unique_proj_name("valgrind") }

    describe "Basic operations" do
      before do
        skip "valgrind is not installed or not in PATH" unless @valgrind_available
        @c.with_context do
          @c.ceedling_appcmd_exec("new --local #{@proj_name}")
        end
      end

      test_case :project_build_tasks_plugins_help_for_valgrind
      test_case :run_valgrind_on_all_tests
      test_case :run_valgrind_on_single_test
    end

    describe "Memory error detection" do
      before do
        skip "valgrind is not installed or not in PATH" unless @valgrind_available
        @c.with_context do
          @c.ceedling_appcmd_exec("new --local #{@proj_name}")
        end
      end

      test_case :run_valgrind_memory_error_suite_completes
      test_case :run_valgrind_memory_error_suite_halts
    end
  end
end
