# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'stringio'
require 'ceedling/plugins/plugin'
require 'ceedling/file_path_utils'

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
    @plugin.instance_variable_set(:@ceedling, {
      plugin_reportinator: @plugin_reportinator,
      file_path_utils:     FilePathUtils.new( configurator: nil, file_wrapper: nil )
    })
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
      expect(lines[0]).to eq("##teamcity[testSuiteStarted name='test/TestFoo' flowId='1']\n")
      expect(lines[1]).to eq("##teamcity[testSuiteFinished name='test/TestFoo' flowId='1']\n")
    end

    # GH #1364: same-named tests in different directories are different suites
    it 'names each suite by its test, so same-named tests are told apart' do
      @plugin.pre_test('test/a/test_x.c')
      @plugin.pre_test('test/b/test_x.c')

      expect(@stream.string).to include("testSuiteStarted name='test/a/test_x'", "testSuiteStarted name='test/b/test_x'")
    end

    it 'escapes a suite name, as every TeamCity value is' do
      @plugin.pre_test("test/o'neil/test_x.c")
      @plugin.post_test("test/o'neil/test_x.c")

      expect(@stream.string.lines).to all( include("name='test/o|'neil/test_x'") )
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

  # GH #1369: a reserved character in a test's path, case name, or failure location
  # closed the quoted value early, and TeamCity misread or dropped the message
  describe '#post_test_fixture_execute escaping' do
    RESERVED_DIR  = "test/o'neil|x"
    RESERVED_CASE = 'test_value(1, [2])'
    ESCAPED_NAME  = "test.test/o|'neil||x/TestFoo.test_value(1, |[2|])"

    before(:each) do
      @plugin.instance_variable_get(:@suites)['test/TestFoo.c'] = { flowid: 1 }
    end

    def run_with(results)
      allow(@plugin_reportinator).to receive(:assemble_test_results).and_return(
        { total_time: 1.0, counts: { passed: 1, failed: 1 }, successes: [], failures: [], ignores: [] }.merge( results )
      )
      @plugin.post_test_fixture_execute(context: :test, test_filepath: 'test/TestFoo.c', result_file: 'x')
    end

    def source
      { dirname: RESERVED_DIR, basename: 'TestFoo.c', file: "#{RESERVED_DIR}/TestFoo.c" }
    end

    it 'escapes the names of testStarted and testFinished for a passing test' do
      run_with( successes: [ { source: source, collection: [ { test: RESERVED_CASE } ] } ] )

      expect(@stream.string).to include(
        "##teamcity[testStarted name='#{ESCAPED_NAME}' flowId='1']\n",
        "##teamcity[testFinished name='#{ESCAPED_NAME}' duration='500' flowId='1']\n"
      )
    end

    it 'escapes the name and details of testFailed, and the names around it' do
      run_with( failures: [ { source: source, collection: [ { test: RESERVED_CASE, line: 7, message: 'm' } ] } ] )

      expect(@stream.string).to include(
        "##teamcity[testStarted name='#{ESCAPED_NAME}' flowId='1']\n",
        "##teamcity[testFailed name='#{ESCAPED_NAME}' message='m' details='File: test/o|'neil||x/TestFoo.c Line: 7' flowId='1']\n",
        "##teamcity[testFinished name='#{ESCAPED_NAME}' duration='500' flowId='1']\n"
      )
    end

    it 'escapes the name of testIgnored' do
      run_with( ignores: [ { source: source, collection: [ { test: RESERVED_CASE } ] } ] )

      expect(@stream.string).to eq( "##teamcity[testIgnored name='#{ESCAPED_NAME}' flowId='1']\n" )
    end

    it 'keeps each message on one physical line when a name holds a line break' do
      run_with( ignores: [ { source: source, collection: [ { test: "test_a\r\ntest_b" } ] } ] )

      expect(@stream.string.lines.length).to eq( 1 )
      expect(@stream.string).to include( 'TestFoo.test_a|r|ntest_b' )
    end
  end

  # A TeamCity service message must stay on one physical line
  describe '#escape' do
    it 'escapes a real newline as |n, keeping the whole message on one physical output line' do
      expect(@plugin.send(:escape, "line one\nline two")).to eq('line one|nline two')
    end

    it 'escapes a real carriage return as |r' do
      expect(@plugin.send(:escape, "line one\rline two")).to eq('line one|rline two')
    end
  end
end
