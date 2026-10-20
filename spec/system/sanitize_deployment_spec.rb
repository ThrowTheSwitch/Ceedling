# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'
require_relative 'support/sanitize_common_test_cases'

ceedling_system_tests do
  describe "Sanitize" do
    include SanitizeCommonTestCases

    # The plugin instruments these builds itself, and the harness's own sanitizer flags
    # would instrument them a second time. See the shared context for why.
    include_context "cannot be sanitized"

    before :all do
      @c = SystemContext.new
      @c.deploy_gem
    end

    after :all do
      @c.done!
    end

    before do
      @proj_name = unique_proj_name("sanitize")
      @c.with_context { @c.ceedling_appcmd_exec("new --local #{@proj_name}") }
    end

    describe "Basic operations" do
      test_case :project_build_tasks_plugins_help_for_sanitize
    end

    describe "Findings" do
      include_context "requires sanitizers"

      test_case :run_sanitize_on_clean_tests
      test_case :run_sanitize_build_removed_by_clobber
      test_case :run_sanitize_names_an_asan_finding
      test_case :run_sanitize_names_a_ubsan_finding
      test_case :run_sanitize_counts_a_finding_only_a_rerun_reaches
      test_case :run_sanitize_leaves_a_plain_crash_alone
      test_case :run_sanitize_writes_structured_reports
      test_case :run_sanitize_instruments_test_builds_when_asked
      test_case :run_sanitize_leaves_test_builds_alone
    end

    describe "Leaks" do
      include_context "requires leak detection"

      test_case :run_sanitize_reports_a_leak_as_a_finding
      test_case :run_sanitize_leak_with_fail_build_disabled
    end

    describe "Valgrind builds" do
      include_context "requires valgrind"

      test_case :run_valgrind_refuses_sanitizer_flags
    end
  end
end
