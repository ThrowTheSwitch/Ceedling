# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'stringio'
require 'rexml/document'

$: << File.expand_path('../../../../plugins/report_tests_log_factory/lib', __FILE__)
require 'junit_tests_reporter'

describe JunitTestsReporter do
  let(:reporter) { described_class.new(handle: :junit) }

  let(:results) do
    {
      times: { 'test/TestFoo.c' => 0.5 },
      successes: [ { source: { file: 'test/TestFoo.c' },
                     collection: [ { test: 'test_a', unity_test_time: 0 } ] } ],
      failures:  [ { source: { file: 'test/TestFoo.c' },
                     collection: [ { test: 'test_b', unity_test_time: 0, message: 'Expected 1 Was 2' } ] } ],
      ignores:   [ { source: { file: 'test/TestFoo.c' },
                     collection: [ { test: 'test_c', unity_test_time: 0 } ] } ],
      stdout: [],
      counts: { total: 3, passed: 1, failed: 1, ignored: 1 },
      total_time: 0.5
    }
  end

  # reorganize_results groups by test file into one <testsuite> -- real,
  # nontrivial structural logic worth pinning as a whole via a full
  # header+body+footer render, parsed back through REXML rather than
  # asserted against literal text (so incidental whitespace/attribute-order
  # differences don't make this brittle).
  describe 'full render' do
    it 'produces one testsuite per test file with a testcase per result, tagging failure/skipped correctly' do
      stream = StringIO.new
      reporter.header(stream: stream, name: 'Ceedling Test Suite', results: results, duration_s: nil)
      reporter.body(stream: stream, name: 'Ceedling Test Suite', results: results, duration_s: nil)
      reporter.footer(stream: stream, name: 'Ceedling Test Suite', results: results, duration_s: nil)

      doc = REXML::Document.new(stream.string)
      root = doc.root

      expect(root.name).to eq('testsuites')
      expect(root.attributes['tests']).to eq('3')
      expect(root.attributes['failures']).to eq('1')

      suite = root.elements['testsuite']
      expect(suite.attributes['name']).to eq('test/TestFoo')
      expect(suite.attributes['tests']).to eq('3')
      expect(suite.attributes['failures']).to eq('1')
      expect(suite.attributes['skipped']).to eq('1')

      testcases = suite.get_elements('testcase')
      expect(testcases.map { |tc| tc.attributes['name'] }).to contain_exactly('test_a', 'test_b', 'test_c')

      failing = testcases.find { |tc| tc.attributes['name'] == 'test_b' }
      expect(failing.elements['failure'].attributes['message']).to eq('Expected 1 Was 2')

      ignored = testcases.find { |tc| tc.attributes['name'] == 'test_c' }
      expect(ignored.elements['skipped']).not_to be_nil
    end
  end

  def render(results, name: 'Ceedling Test Suite')
    stream = StringIO.new
    reporter.header(stream: stream, name: name, results: results, duration_s: nil)
    reporter.body(stream: stream, name: name, results: results, duration_s: nil)
    reporter.footer(stream: stream, name: name, results: results, duration_s: nil)
    stream.string
  end

  describe 'suite details' do
    it "takes a suite's time from its test file's execution time" do
      suite = REXML::Document.new(render(results)).root.elements['testsuite']
      expect(suite.attributes['time']).to eq('0.500')
    end

    it 'writes an empty failure element for a failure with no message' do
      results[:failures].first[:collection].first[:message] = ''
      failure = REXML::Document.new(render(results)).root.elements['testsuite/testcase/failure']
      expect(failure.attributes['message']).to be_nil
    end

    it "gathers a test file's output, escaped, into its suite's system-out" do
      results[:stdout] = [ { source: { file: 'test/TestFoo.c' }, collection: ['printed <one>', 'two'] } ]
      out = REXML::Document.new(render(results)).root.elements['testsuite/system-out']
      expect(out.text.split("\n").map(&:strip).reject(&:empty?)).to eq(['printed <one>', 'two'])
    end
  end

  describe 'escaping' do
    it 'produces well-formed, parseable XML when a failure message contains XML metacharacters' do
      escaping_results = results.dup
      escaping_results[:failures] = [ { source: { file: 'test/TestFoo.c' },
        collection: [ { test: 'test_b', unity_test_time: 0, message: 'Expected "<a>" Was <b> & more' } ] } ]
      escaping_results[:successes] = []
      escaping_results[:ignores] = []

      stream = StringIO.new
      reporter.header(stream: stream, name: 'x', results: escaping_results, duration_s: nil)
      reporter.body(stream: stream, name: 'x', results: escaping_results, duration_s: nil)
      reporter.footer(stream: stream, name: 'x', results: escaping_results, duration_s: nil)

      doc = REXML::Document.new(stream.string) # raises REXML::ParseException on malformed XML
      message = doc.root.elements['testsuite/testcase/failure'].attributes['message']
      expect(message).to eq('Expected "<a>" Was <b> & more')
    end
  end

  # The same results structure goes to every configured reporter in turn
  describe 'non-mutation' do
    it 'does not mutate the original test-name string other reporters would also read' do
      mutation_results = results.dup
      test_item = { test: 'test&name', unity_test_time: 0 }
      mutation_results[:successes] = [ { source: { file: 'test/TestFoo.c' }, collection: [ test_item ] } ]
      mutation_results[:failures] = []
      mutation_results[:ignores] = []

      stream = StringIO.new
      reporter.body(stream: stream, name: 'x', results: mutation_results, duration_s: nil)

      expect(test_item[:test]).to eq('test&name')
    end

    it 'leaves nil and empty entries in a shared collection in place' do
      collection = [ { test: 'test_a', unity_test_time: 0 }, nil, {} ]
      results[:successes] = [ { source: { file: 'test/TestFoo.c' }, collection: collection } ]

      render(results)

      expect(collection.length).to eq(3)
    end
  end

  it 'escapes the report name and a test file path in suite names' do
    results[:successes] = [ { source: { file: 'test/T&"x".c' }, collection: [ { test: 'test_a', unity_test_time: 0 } ] } ]
    results[:failures]  = []
    results[:ignores]   = []
    results[:times]     = { 'test/T&"x".c' => 0.5 }

    root = REXML::Document.new(render(results, name: 'Q-36 & <Modulator>')).root

    expect(root.attributes['name']).to eq('Q-36 & <Modulator>')
    expect(root.elements['testsuite'].attributes['name']).to eq('test/T&"x"')
  end
end
