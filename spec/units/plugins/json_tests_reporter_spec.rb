# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'json'
require 'stringio'

$: << File.expand_path('../../../../plugins/report_tests_log_factory/lib', __FILE__)
require 'json_tests_reporter'

describe JsonTestsReporter do
  let(:reporter) { described_class.new(handle: :json) }

  # A realistic 2-pass/1-fail/1-ignore result set, shaped exactly like
  # PluginReportinatorHelper#process_results actually aggregates it --
  # nontrivial to construct correctly, valuable to pin end-to-end.
  let(:results) do
    {
      successes: [ { source: { file: 'test/TestFoo.c' },
                     collection: [ { test: 'test_a', line: 10 }, { test: 'test_b', line: 20 } ] } ],
      failures:  [ { source: { file: 'test/TestFoo.c' },
                     collection: [ { test: 'test_c', line: 30, message: 'Expected 1 Was 2' } ] } ],
      ignores:   [ { source: { file: 'test/TestFoo.c' },
                     collection: [ { test: 'test_d', line: 40 } ] } ],
      counts: { total: 4, passed: 2, failed: 1, ignored: 1, stdout: 0 }
    }
  end

  describe '#body' do
    it 'produces the documented JSON shape for a mixed pass/fail/ignore result set' do
      stream = StringIO.new
      reporter.body(stream: stream, name: 'Ceedling Test Suite', results: results, duration_s: 1.5)

      parsed = JSON.parse(stream.string)

      expect(parsed).to eq({
        'Name'          => 'Ceedling Test Suite',
        'BuildDuration' => 1.5,
        'FailedTests'   => [ { 'file' => 'test/TestFoo.c', 'test' => 'test_c', 'line' => 30, 'message' => 'Expected 1 Was 2' } ],
        'PassedTests'   => [ { 'file' => 'test/TestFoo.c', 'test' => 'test_a' }, { 'file' => 'test/TestFoo.c', 'test' => 'test_b' } ],
        'IgnoredTests'  => [ { 'file' => 'test/TestFoo.c', 'test' => 'test_d' } ],
        'Summary'       => { 'total_tests' => 4, 'passed' => 2, 'ignored' => 1, 'failures' => 1 }
      })
    end

    # --- Fix below this point: written to fail against pre-fix code ---

    it 'trusts counts[:passed] directly rather than recomputing it from :total (fix: today it subtracts)' do
      inconsistent_results = results.dup
      # :total is deliberately stale/wrong; :passed is the real, correct aggregate.
      inconsistent_results[:counts] = { total: 999, passed: 2, failed: 1, ignored: 1, stdout: 0 }

      stream = StringIO.new
      reporter.body(stream: stream, name: 'x', results: inconsistent_results, duration_s: nil)

      expect(JSON.parse(stream.string)['Summary']['passed']).to eq(2)
    end
  end
end
