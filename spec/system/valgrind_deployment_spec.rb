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

    # ASan-instrumented binaries are not supported under Valgrind, and these
    # examples assert Valgrind's own error counts on a fixture that faults by
    # design. See the shared context for why opting out is mandatory.
    include_context "cannot be sanitized"

    before :all do
      @c = SystemContext.new
      @c.deploy_gem
    end

    after :all do
      @c.done!
    end

    before { @proj_name = unique_proj_name("valgrind") }

    describe "Basic operations" do
      include_context "requires valgrind"

      before do
        @c.with_context do
          @c.ceedling_appcmd_exec("new --local #{@proj_name}")
        end
      end

      test_case :project_build_tasks_plugins_help_for_valgrind
      test_case :run_valgrind_on_all_tests
      test_case :run_valgrind_on_single_test
    end

    describe "Memory error detection" do
      include_context "requires valgrind"

      before do
        @c.with_context do
          @c.ceedling_appcmd_exec("new --local #{@proj_name}")
        end
      end

      test_case :run_valgrind_memory_error_fail_build_enabled
      test_case :run_valgrind_memory_error_fail_build_disabled
    end

    describe "Reporting options" do
      include_context "requires valgrind"

      before do
        @c.with_context do
          @c.ceedling_appcmd_exec("new --local #{@proj_name}")
        end
      end

      test_case :run_valgrind_with_xml_report
      test_case :run_valgrind_with_suppressions
    end

    # Gated in the opposite direction from every block above. These assert what the
    # plugin does where Valgrind cannot run, so they are meaningful only where it is
    # absent. That is every non-Linux platform, including this project's macOS and
    # Windows CI legs.
    describe "Platforms without Valgrind" do
      before do
        @c.with_context do
          @c.ceedling_appcmd_exec("new --local #{@proj_name}")
        end
      end

      it "Test build unaffected when valgrind absent",
         skip: (valgrind_available? ? 'Valgrind is installed; this covers hosts without it' : false) do
        test_build_unaffected_when_valgrind_absent
      end

      it "Valgrind task reports platform constraint",
         skip: (valgrind_available? ? 'Valgrind is installed; this covers hosts without it' : false) do
        valgrind_task_reports_platform_constraint
      end
    end
  end
end
