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

  # --- Fixes below this point: written to fail against pre-fix code ---

  describe 'escaping (fix: failure message is escaped, not just the test name)' do
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

  describe 'non-mutation (fix: escaping must not alter the shared results structure)' do
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
  end
end
