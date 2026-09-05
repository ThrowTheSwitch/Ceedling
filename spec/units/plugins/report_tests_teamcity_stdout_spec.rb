# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'stringio'
require 'ceedling/plugins/plugin'

$: << File.expand_path('../../../../plugins/report_tests_teamcity_stdout/lib', __FILE__)
require 'report_tests_teamcity_stdout'

describe ReportTestsTeamcityStdout do
  before(:each) do
    @stream = StringIO.new
    @plugin_reportinator = double('plugin_reportinator')

    @plugin = described_class.allocate
    @plugin.instance_variable_set(:@output_enabled, true)
    @plugin.instance_variable_set(:@mutex, Mutex.new)
    @plugin.instance_variable_set(:@flowid_count, 0)
    @plugin.instance_variable_set(:@suites, {})
    @plugin.instance_variable_set(:@stream, @stream)
    @plugin.instance_variable_set(:@ceedling, { plugin_reportinator: @plugin_reportinator })
  end

  describe '#escape' do
    it 'escapes pipe, single-quote, and brackets -- required for every TeamCity value' do
      expect(@plugin.send(:escape, "a|b'c[d]e")).to eq("a||b|'c|[d|]e")
    end
  end

  describe '#pre_test / #post_test' do
    it 'assigns an incrementing flow id per test and brackets it with suite start/finish messages' do
      @plugin.pre_test('test/TestFoo.c')
      @plugin.post_test('test/TestFoo.c')

      lines = @stream.string.lines
      expect(lines[0]).to eq("##teamcity[testSuiteStarted name='TestFoo' flowId='1']\n")
      expect(lines[1]).to eq("##teamcity[testSuiteFinished name='TestFoo' flowId='1']\n")
    end

    it 'gives each successive test its own flow id' do
      @plugin.pre_test('test/TestFoo.c')
      @plugin.pre_test('test/TestBar.c')

      expect(@stream.string).to include("flowId='1']")
      expect(@stream.string).to include("flowId='2']")
    end

    it 'does nothing at all when output is disabled' do
      @plugin.instance_variable_set(:@output_enabled, false)
      @plugin.pre_test('test/TestFoo.c')
      @plugin.post_test('test/TestFoo.c')

      expect(@stream.string).to be_empty
    end
  end

  describe '#post_test_fixture_execute' do
    before(:each) do
      @plugin.instance_variable_get(:@suites)['test/TestFoo.c'] = { flowid: 1 }
    end

    it 'emits a started/finished pair per passing test, apportioning the executable duration evenly' do
      allow(@plugin_reportinator).to receive(:assemble_test_results).and_return({
        total_time: 1.0,
        counts: { passed: 2, failed: 0 },
        successes: [ { source: { dirname: 'test', basename: 'TestFoo.c' },
                       collection: [ { test: 'test_a' }, { test: 'test_b' } ] } ],
        failures: [], ignores: []
      })

      @plugin.post_test_fixture_execute(context: :test, test_filepath: 'test/TestFoo.c', result_file: 'x.pass')

      expect(@stream.string).to include("testStarted name='test.test/TestFoo.test_a' flowId='1'")
      expect(@stream.string).to include("testFinished name='test.test/TestFoo.test_a' duration='500' flowId='1'")
    end

    it 'emits a testFailed message naming the file, line, and escaped message for a failing test' do
      allow(@plugin_reportinator).to receive(:assemble_test_results).and_return({
        total_time: 0.5,
        counts: { passed: 0, failed: 1 },
        successes: [], ignores: [],
        failures: [ { source: { dirname: 'test', basename: 'TestFoo.c', file: 'test/TestFoo.c' },
                      collection: [ { test: 'test_c', line: 10, message: "Expected 'a'" } ] } ]
      })

      @plugin.post_test_fixture_execute(context: :test, test_filepath: 'test/TestFoo.c', result_file: 'x.fail')

      expect(@stream.string).to include(
        "testFailed name='test.test/TestFoo.test_c' message='Expected |'a|'' details='File: test/TestFoo.c Line: 10' flowId='1'"
      )
    end

    it 'emits testIgnored (not started/finished) for an ignored test' do
      allow(@plugin_reportinator).to receive(:assemble_test_results).and_return({
        total_time: 0.0, counts: { passed: 0, failed: 0 },
        successes: [], failures: [],
        ignores: [ { source: { dirname: 'test', basename: 'TestFoo.c' }, collection: [ { test: 'test_d' } ] } ]
      })

      @plugin.post_test_fixture_execute(context: :test, test_filepath: 'test/TestFoo.c', result_file: 'x.ignore')

      expect(@stream.string).to eq("##teamcity[testIgnored name='test.test/TestFoo.test_d' flowId='1']\n")
    end
  end

  # --- Fix below this point: written to fail against pre-fix code ---

  describe '#escape (fix: a real embedded newline/carriage-return is escaped, not passed through)' do
    it 'escapes a real newline as |n, keeping the whole message on one physical output line' do
      expect(@plugin.send(:escape, "line one\nline two")).to eq('line one|nline two')
    end

    it 'escapes a real carriage return as |r' do
      expect(@plugin.send(:escape, "line one\rline two")).to eq('line one|rline two')
    end
  end
end
