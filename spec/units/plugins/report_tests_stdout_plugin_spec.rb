# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/constants'
require 'ceedling/plugins/report_tests_stdout_plugin'

# Ceedling normally derives these from project configuration at runtime.
PROJECT_TEST_RESULTS_PATH = 'build/test/results' unless defined?(PROJECT_TEST_RESULTS_PATH)
COLLECTION_ALL_TESTS = [] unless defined?(COLLECTION_ALL_TESTS)

describe ReportTestsStdoutPlugin do
  before(:each) do
    @plugin_reportinator     = double('plugin_reportinator')
    @rake_invocation_tracker = double('rake_invocation_tracker')
    @configurator            = double('configurator')
    @file_path_utils         = double('file_path_utils')

    @plugin = described_class.allocate
    @plugin.instance_variable_set(:@result_list, [])
    @plugin.instance_variable_set(:@mutex, Mutex.new)
    @plugin.instance_variable_set(:@configurator, @configurator)
    @plugin.instance_variable_set(:@plugin_reportinator, @plugin_reportinator)
    @plugin.instance_variable_set(:@file_path_utils, @file_path_utils)
    @plugin.instance_variable_set(:@rake_invocation_tracker, @rake_invocation_tracker)
  end

  describe '#post_test_fixture_execute' do
    it 'collects a result file that lives under the project test results path' do
      @plugin.post_test_fixture_execute(result_file: File.join(PROJECT_TEST_RESULTS_PATH, 'TestFoo.pass'))
      expect(@plugin.instance_variable_get(:@result_list)).to eq([File.join(PROJECT_TEST_RESULTS_PATH, 'TestFoo.pass')])
    end

    it 'ignores a result file outside the project test results path' do
      @plugin.post_test_fixture_execute(result_file: 'somewhere/else/TestFoo.pass')
      expect(@plugin.instance_variable_get(:@result_list)).to be_empty
    end

    it 'never adds the same result file twice' do
      path = File.join(PROJECT_TEST_RESULTS_PATH, 'TestFoo.pass')
      @plugin.post_test_fixture_execute(result_file: path)
      @plugin.post_test_fixture_execute(result_file: path)
      expect(@plugin.instance_variable_get(:@result_list)).to eq([path])
    end

    # Regression lock for #104: a literal `[`/`]` in the build root (legal
    # filename characters) must not silently break this match the way it
    # once did when this comparison was regex-based.
    it 'still matches correctly when the project test results path itself contains brackets' do
      bracket_path = File.join(PROJECT_TEST_RESULTS_PATH, '[unit]', 'TestFoo.pass')
      @plugin.post_test_fixture_execute(result_file: bracket_path)
      expect(@plugin.instance_variable_get(:@result_list)).to eq([bracket_path])
    end
  end

  describe '#post_build' do
    it 'does nothing when no test task was invoked' do
      allow(@rake_invocation_tracker).to receive(:test_task_invoked?).and_return(false)
      expect(@plugin_reportinator).not_to receive(:run_test_results_report)

      @plugin.post_build(0)
    end

    it 'does nothing when raw test results display is configured on' do
      allow(@rake_invocation_tracker).to receive(:test_task_invoked?).and_return(true)
      allow(@configurator).to receive(:plugins_display_raw_test_results).and_return(true)
      expect(@plugin_reportinator).not_to receive(:run_test_results_report)

      @plugin.post_build(0)
    end

    it 'assembles results and runs the report at the shared floor verbosity' do
      @plugin.instance_variable_set(:@result_list, ['TestFoo.pass'])
      allow(@rake_invocation_tracker).to receive(:test_task_invoked?).and_return(true)
      allow(@configurator).to receive(:plugins_display_raw_test_results).and_return(false)
      allow(@plugin_reportinator).to receive(:assemble_test_results).with(['TestFoo.pass']).and_return({ marker: :results })
      allow(@plugin_reportinator).to receive(:test_results_floor_verbosity).and_return(Verbosity::ERRORS)

      expect(@plugin_reportinator).to receive(:run_test_results_report).with(
        { context: TEST_SYM, results: { marker: :results } }, Verbosity::ERRORS
      )

      @plugin.post_build(0)
    end
  end

  describe '#summary' do
    it 'does nothing when raw test results display is configured on' do
      allow(@configurator).to receive(:plugins_display_raw_test_results).and_return(true)
      expect(@plugin_reportinator).not_to receive(:run_test_results_report)

      @plugin.summary
    end

    it 'assembles results tolerantly (never raising) from every known test, not just those already collected' do
      allow(@configurator).to receive(:plugins_display_raw_test_results).and_return(false)
      allow(@file_path_utils).to receive(:form_pass_results_filelist)
        .with(PROJECT_TEST_RESULTS_PATH, COLLECTION_ALL_TESTS).and_return(['TestFoo.pass', 'TestBar.pass'])
      allow(@plugin_reportinator).to receive(:assemble_test_results)
        .with(['TestFoo.pass', 'TestBar.pass'], { boom: false }).and_return({ marker: :results })

      expect(@plugin_reportinator).to receive(:run_test_results_report).with(
        { context: TEST_SYM, results: { marker: :results } }
      )

      @plugin.summary
    end
  end
end
