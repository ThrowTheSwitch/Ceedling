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
require 'cppunit_tests_reporter'

describe CppunitTestsReporter do
  let(:reporter) { described_class.new(handle: :cppunit) }

  let(:results) do
    {
      successes: [ { source: { file: 'test/TestFoo.c' }, collection: [ { test: 'test_a' } ] } ],
      failures:  [ { source: { file: 'test/TestFoo.c' },
                     collection: [ { test: 'test_b', line: 30, message: 'Expected 1 Was 2' } ] } ],
      ignores:   [ { source: { file: 'test/TestFoo.c' }, collection: [ { test: 'test_c' } ] } ],
      counts: { total: 3, passed: 1, failed: 1, ignored: 1 }
    }
  end

  describe 'full render' do
    reporter_calls = ->(reporter, stream, results) do
      reporter.instance_variable_set(:@test_counter, 0) # setup's own responsibility, not under test here
      reporter.header(stream: stream, name: 'Ceedling Test Suite', results: results, duration_s: nil)
      reporter.body(stream: stream, name: 'Ceedling Test Suite', results: results, duration_s: nil)
      reporter.footer(stream: stream, name: 'Ceedling Test Suite', results: results, duration_s: nil)
    end

    it 'nests failed/successful/ignored tests correctly, always reporting zero Errors' do
      stream = StringIO.new
      reporter_calls.call(reporter, stream, results)

      doc = REXML::Document.new(stream.string)
      root = doc.root
      expect(root.name).to eq('TestRun')

      failed_name = root.elements['FailedTests/Test/Name'].text
      expect(failed_name).to eq('test/TestFoo.c::test_b')
      expect(root.elements['FailedTests/Test/Message'].text).to eq('Expected 1 Was 2')

      expect(root.elements['SuccessfulTests/Test/Name'].text).to eq('test/TestFoo.c::test_a')
      expect(root.elements['IgnoredTests/Test/Name'].text).to eq('test/TestFoo.c::test_c')

      expect(root.elements['Statistics/Tests'].text).to eq('3')
      expect(root.elements['Statistics/Ignores'].text).to eq('1')
      expect(root.elements['Statistics/FailuresTotal'].text).to eq('1')
      expect(root.elements['Statistics/Errors'].text).to eq('0')
    end

    it 'self-closes each section when its result list is empty' do
      empty_results = { successes: [], failures: [], ignores: [], counts: { total: 0, passed: 0, failed: 0, ignored: 0 } }
      stream = StringIO.new
      reporter_calls.call(reporter, stream, empty_results)

      expect(stream.string).to include('<FailedTests/>')
      expect(stream.string).to include('<SuccessfulTests/>')
      expect(stream.string).to include('<IgnoredTests/>')
    end

    # --- Fix below this point: written to fail against pre-fix code ---

    it 'escapes XML metacharacters in the test name and message (fix: no escaping at all today)' do
      escaping_results = {
        successes: [], ignores: [],
        failures: [ { source: { file: 'test/TestFoo.c' },
                      collection: [ { test: 'test<b>', line: 30, message: 'Expected "<a>" & more' } ] } ],
        counts: { total: 1, passed: 0, failed: 1, ignored: 0 }
      }
      stream = StringIO.new
      reporter_calls.call(reporter, stream, escaping_results)

      doc = REXML::Document.new(stream.string) # raises REXML::ParseException on malformed XML
      test = doc.root.elements['FailedTests/Test']
      expect(test.elements['Name'].text).to eq('test/TestFoo.c::test<b>')
      expect(test.elements['Message'].text).to eq('Expected "<a>" & more')
    end
  end
end
