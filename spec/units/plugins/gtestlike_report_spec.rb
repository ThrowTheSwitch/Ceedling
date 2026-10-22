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
    it 'groups tests by file in source order' do
      report = GtestlikeReport.new( mixed, context: TEST_SYM )

      expect( report.sections.map(&:file) ).to eq( ['test/TestA.c', 'test/TestB.c'] )
      expect( report.sections.first.tests.map(&:name) ).to eq( ['test_a1', 'test_a3', 'test_a2'] )
    end

    it 'groups tests by file in source order when ignored tests are left out' do
      report = GtestlikeReport.new( mixed, context: TEST_SYM, ignored_as_skipped: false )

      expect( report.sections.first.tests.map(&:name) ).to eq( ['test_a1', 'test_a3', 'test_a2'] )
      expect( report.sections.first.tests.map(&:status) ).to eq( [:ok, :failed, :ok] )
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

  # A Unity ignore is a runtime decision, like GoogleTest's GTEST_SKIP(), so an ignored
  # test reports as skipped. Without the option, ignored tests are left out entirely.
  describe 'ignored tests' do
    # The worked example: an all-pass file, a mixed file with an ignore, an all-ignored
    # file, and a file with a failure
    let(:suite) do
      results(
        successes: [ entry('test/TestA.c', test('a1', 1), test('a2', 2), test('a3', 3), test('a4', 4)),
                     entry('test/TestB.c', test('b1', 1), test('b3', 9)),
                     entry('test/TestD.c', test('d1', 1)) ],
        failures:  [ entry('test/TestD.c', test('d2', 8, 'Expected 1 Was 2.')) ],
        ignores:   [ entry('test/TestB.c', test('b2', 5, 'Waiting on driver rewrite')),
                     entry('test/TestC.c', test('c1', 3), test('c2', 7, 'not ready')) ],
        times: { 'test/TestA.c' => 0.1, 'test/TestB.c' => 0.1, 'test/TestC.c' => 0.1, 'test/TestD.c' => 0.1 }
      )
    end

    context 'reported as skipped' do
      let(:report) { GtestlikeReport.new( suite, context: TEST_SYM, ignored_as_skipped: true ) }

      it 'counts every test and every file' do
        expect( report.total ).to eq(11)
        expect( report.suite_count ).to eq(4)
        expect( report.passed ).to eq(7)
        expect( report.skipped.length ).to eq(3)
        expect( report.failures.length ).to eq(1)
      end

      it 'gives a file of only ignored tests its own section' do
        expect( report.sections.map(&:file) ).to include('test/TestC.c')
        expect( report.render ).to include( "[----------] 2 tests from test/TestC.c\n" )
      end

      it 'lists a file\'s tests in source order' do
        section = report.sections.find { |s| s.file == 'test/TestB.c' }

        expect( section.tests.map(&:name) ).to eq( ['b1', 'b2', 'b3'] )
        expect( section.tests.map(&:status) ).to eq( [:ok, :skipped, :ok] )
      end

      it 'frames the run with every test counted' do
        output = report.render

        expect( output ).to include( '[==========] Running 11 tests from 4 test suites.' )
        expect( output ).to include( '[==========] 11 tests from 4 test suites ran.' )
      end

      it 'prints a skipped test with its location and message' do
        expect( report.render ).to include( <<~BLOCK )
          [ RUN      ] test/TestB.c.b2
          test/TestB.c(5): Skipped
          Waiting on driver rewrite

          [  SKIPPED ] test/TestB.c.b2 (0 ms)
        BLOCK
      end

      it 'prints a skipped test without a message line when it has none' do
        expect( report.render ).to include( <<~BLOCK )
          [ RUN      ] test/TestC.c.c1
          test/TestC.c(3): Skipped

          [  SKIPPED ] test/TestC.c.c1 (0 ms)
        BLOCK
      end

      it 'prints a multi-line ignore message as it arrives' do
        report = GtestlikeReport.new(
          results( ignores: [ entry('test/TestA.c', test('a', 4, "first line\nsecond line")) ] ),
          context: TEST_SYM, ignored_as_skipped: true
        )

        expect( report.render ).to include( "test/TestA.c(4): Skipped\nfirst line\nsecond line\n\n[  SKIPPED ]" )
      end

      it 'summarizes passed, then skipped, then failed tests' do
        expect( report.render ).to end_with( <<~FOOTER )
          [  PASSED  ] 7 tests.
          [  SKIPPED ] 3 tests, listed below:
          [  SKIPPED ] test/TestB.c.b2
          [  SKIPPED ] test/TestC.c.c1
          [  SKIPPED ] test/TestC.c.c2
          [  FAILED  ] 1 test, listed below:
          [  FAILED  ] test/TestD.c.d2

           1 FAILED TEST
        FOOTER
      end

      it 'reports a run of only ignored tests rather than no tests executed' do
        report = GtestlikeReport.new(
          results( ignores: [ entry('test/TestC.c', test('c1', 3)) ] ), context: TEST_SYM, ignored_as_skipped: true
        )

        expect( report.render ).to end_with( "[  PASSED  ] 0 tests.\n[  SKIPPED ] 1 test, listed below:\n[  SKIPPED ] test/TestC.c.c1\n" )
      end

      it 'leaves the results it reads unaltered' do
        pristine = Marshal.load( Marshal.dump( suite ) )

        report.render

        expect( suite ).to eq(pristine)
      end

      it 'prints no skipped summary when nothing was ignored' do
        expect( GtestlikeReport.new( mixed, context: TEST_SYM, ignored_as_skipped: true ).render ).not_to include('SKIPPED')
      end
    end

    context 'left out' do
      let(:report) { GtestlikeReport.new( suite, context: TEST_SYM, ignored_as_skipped: false ) }

      it 'counts only passed and failed tests and the files holding them' do
        expect( report.total ).to eq(8)
        expect( report.suite_count ).to eq(3)
        expect( report.passed ).to eq(7)
        expect( report.skipped ).to be_empty
      end

      it 'omits a file of only ignored tests' do
        expect( report.render ).not_to include('TestC.c')
        expect( report.render ).to include( "[----------] 2 tests from test/TestB.c\n" )
      end

      it 'lists a file\'s remaining tests in source order' do
        section = report.sections.find { |s| s.file == 'test/TestB.c' }

        expect( section.tests.map(&:name) ).to eq( ['b1', 'b3'] )
      end

      it 'never mentions an ignored test' do
        output = report.render

        expect( output ).not_to include('SKIPPED')
        expect( output ).not_to include('b2')
        expect( output ).to include( '[==========] Running 8 tests from 3 test suites.' )
      end
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
        [ RUN      ] test/TestA.c.test_a3
        test/TestA.c(7): error: Expected 1 Was 2.
         Actual:   2
         Expected: 1
        [  FAILED  ] test/TestA.c.test_a3 (0 ms)
        [ RUN      ] test/TestA.c.test_a2
        [       OK ] test/TestA.c.test_a2 (0 ms)
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
