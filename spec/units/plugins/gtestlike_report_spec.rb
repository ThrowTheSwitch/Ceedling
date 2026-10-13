# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/constants'

$: << File.expand_path('../../../../plugins/report_tests_gtestlike_stdout/lib', __FILE__)
require 'gtestlike_report'

# GtestlikeReport translates Ceedling's aggregated test results into GoogleTest's
# console report. Every expectation here is pure text and data, with no filesystem.
describe GtestlikeReport do

  def entry(file, *tests)
    return { source: { file: file }, collection: tests }
  end

  def test(name, line, message = '')
    return { test: name, line: line, message: message }
  end

  def results(successes: [], failures: [], ignores: [], times: {})
    count = ->(entries) { entries.sum { |e| e[:collection].length } }
    passed, failed, ignored = count.(successes), count.(failures), count.(ignores)

    return {
      times: times,
      counts: { total: passed + failed + ignored, passed: passed, failed: failed, ignored: ignored, stdout: 0 },
      successes: successes, failures: failures, ignores: ignores, stdout: [],
      total_time: times.values.sum
    }
  end

  let(:mixed) do
    results(
      successes: [ entry('test/TestA.c', test('test_a1', 5), test('test_a2', 9)) ],
      failures:  [ entry('test/TestA.c', test('test_a3', 7, 'Expected 1 Was 2.')),
                   entry('test/TestB.c', test('test_b1', 3, 'Something else')) ],
      times: { 'test/TestA.c' => 0.0125, 'test/TestB.c' => 0.5 }
    )
  end

  describe 'counts' do
    it 'totals the passed and failed tests across every file' do
      report = GtestlikeReport.new( mixed, context: TEST_SYM )

      expect( report.total ).to eq(4)
      expect( report.passed ).to eq(2)
      expect( report.suite_count ).to eq(2)
    end

    it 'lists failures in the order the results carry them' do
      report = GtestlikeReport.new( mixed, context: TEST_SYM )

      expect( report.failures.map( &:full_name ) ).to eq( ['test/TestA.c.test_a3', 'test/TestB.c.test_b1'] )
    end
  end

  describe 'sections' do
    it 'groups tests by file, passes before failures' do
      report = GtestlikeReport.new( mixed, context: TEST_SYM )

      expect( report.sections.map(&:file) ).to eq( ['test/TestA.c', 'test/TestB.c'] )
      expect( report.sections.first.tests.map(&:name) ).to eq( ['test_a1', 'test_a2', 'test_a3'] )
      expect( report.sections.first.tests.map(&:status) ).to eq( [:ok, :ok, :failed] )
    end

    it 'rounds each file\'s duration to whole milliseconds' do
      report = GtestlikeReport.new( mixed, context: TEST_SYM )

      expect( report.sections.map(&:duration_ms) ).to eq( [13, 500] )
    end

    # A file absent from the timing data reports zero rather than failing the report
    it 'reports zero milliseconds for a file with no recorded time' do
      report = GtestlikeReport.new( results( successes: [ entry('test/TestA.c', test('test_a', 5)) ] ), context: TEST_SYM )

      expect( report.sections.first.duration_ms ).to eq(0)
    end
  end

  describe '.expectation' do
    it 'extracts actual and expected values from a Unity comparison message' do
      expect( GtestlikeReport.expectation('Expected 1 Was 2.') ).to eq( ['2', '1'] )
    end

    it 'falls back to a boolean framing for any other message' do
      expect( GtestlikeReport.expectation('Something else') ).to eq( ['FALSE', 'TRUE'] )
      expect( GtestlikeReport.expectation(nil) ).to eq( ['FALSE', 'TRUE'] )
    end
  end

  # Every reporting plugin receives the same results, so the report never alters them
  it 'leaves the results it reads unaltered' do
    pristine = Marshal.load( Marshal.dump( mixed ) )

    GtestlikeReport.new( mixed, context: TEST_SYM ).render

    expect( mixed ).to eq(pristine)
  end

  describe '.count' do
    # GoogleTest's FormatCountableNoun: singular for exactly one, plural otherwise
    it 'uses the singular noun for exactly one and the plural otherwise' do
      expect( GtestlikeReport.count( 0, 'test' ) ).to eq('0 tests')
      expect( GtestlikeReport.count( 1, 'test' ) ).to eq('1 test')
      expect( GtestlikeReport.count( 2, 'test suite' ) ).to eq('2 test suites')
    end
  end

  # Expectations follow GoogleTest's own console output (gtest.cc, PrettyUnitTestResultPrinter)
  describe '#render' do
    it 'prints the full report' do
      expected = <<~REPORT

        [==========] Running 4 tests from 2 test suites.
        [----------] Global test environment set-up.
        [----------] 3 tests from test/TestA.c
        [ RUN      ] test/TestA.c.test_a1
        [       OK ] test/TestA.c.test_a1 (0 ms)
        [ RUN      ] test/TestA.c.test_a2
        [       OK ] test/TestA.c.test_a2 (0 ms)
        [ RUN      ] test/TestA.c.test_a3
        test/TestA.c(7): error: Expected 1 Was 2.
         Actual:   2
         Expected: 1
        [  FAILED  ] test/TestA.c.test_a3 (0 ms)
        [----------] 3 tests from test/TestA.c (13 ms total)

        [----------] 1 test from test/TestB.c
        [ RUN      ] test/TestB.c.test_b1
        test/TestB.c(3): error: Something else
         Actual:   FALSE
         Expected: TRUE
        [  FAILED  ] test/TestB.c.test_b1 (0 ms)
        [----------] 1 test from test/TestB.c (500 ms total)

        [----------] Global test environment tear-down
        [==========] 4 tests from 2 test suites ran. (513 ms total)
        [  PASSED  ] 2 tests.
        [  FAILED  ] 2 tests, listed below:
        [  FAILED  ] test/TestA.c.test_a3
        [  FAILED  ] test/TestB.c.test_b1

         2 FAILED TESTS
      REPORT

      expect( GtestlikeReport.new( mixed, context: TEST_SYM ).render ).to eq(expected)
    end

    it 'names a single failure in the singular' do
      report = GtestlikeReport.new(
        results( failures: [ entry('test/TestA.c', test('test_a', 5, 'Expected 1 Was 2.')) ], times: { 'test/TestA.c' => 0.001 } ),
        context: TEST_SYM
      )

      expect( report.render ).to include( "[  PASSED  ] 0 tests.\n[  FAILED  ] 1 test, listed below:\n" )
      expect( report.render ).to end_with( "\n 1 FAILED TEST\n" )
    end

    # GoogleTest prints its failure list and trailer only when a test failed
    it 'prints no failure summary when every test passes' do
      expected = <<~REPORT

        [==========] Running 1 test from 1 test suite.
        [----------] Global test environment set-up.
        [----------] 1 test from test/TestA.c
        [ RUN      ] test/TestA.c.test_a
        [       OK ] test/TestA.c.test_a (0 ms)
        [----------] 1 test from test/TestA.c (2 ms total)

        [----------] Global test environment tear-down
        [==========] 1 test from 1 test suite ran. (2 ms total)
        [  PASSED  ] 1 test.
      REPORT

      report = GtestlikeReport.new( results( successes: [ entry('test/TestA.c', test('test_a', 5)) ], times: { 'test/TestA.c' => 0.002 } ), context: TEST_SYM )

      expect( report.render ).to eq(expected)
    end

    it 'prints a failure without a message on a line of its own' do
      report = GtestlikeReport.new( results( failures: [ entry('test/TestA.c', test('test_a', 5)) ] ), context: TEST_SYM )

      expect( report.render ).to include( "test/TestA.c(5): fail:\n Actual:   FALSE\n Expected: TRUE\n" )
    end

    it 'prints a multi-line failure message as it arrives' do
      report = GtestlikeReport.new( results( failures: [ entry('test/TestA.c', test('test_a', 5, "Expected 1 Was 2.\nsecond line")) ] ), context: TEST_SYM )

      expect( report.render ).to include( "test/TestA.c(5): error: Expected 1 Was 2.\nsecond line\n Actual:   2\n Expected: 1\n" )
    end

    it 'names a non-test context ahead of the report' do
      report = GtestlikeReport.new( mixed, context: :gcov )

      expect( report.render ).to start_with( "\nRunning testing tasks: GCOV\n[==========] Running 4 tests" )
    end

    it 'reports an empty run as no tests executed' do
      expected = <<~REPORT

        [==========] Running 0 tests from 0 test suites.
        [----------] Global test environment set-up.

        No tests executed.
      REPORT

      expect( GtestlikeReport.new( results, context: TEST_SYM ).render ).to eq(expected)
    end
  end
end
