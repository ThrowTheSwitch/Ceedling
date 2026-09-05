# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/constants'
require 'ceedling/reportinator'
require 'ceedling/plugins/plugin_reportinator'

describe "report_tests_gtestlike_stdout template" do
  before(:each) do
    @loginator = double('loginator')
    allow(@loginator).to receive(:decorate) { |str, _label| str }

    @plugin_reportinator = PluginReportinator.new(
      {
        plugin_reportinator_helper: nil, plugin_manager: nil,
        reportinator: Reportinator.new, loginator: @loginator
      }
    )
    @plugin_reportinator.set_system_objects({ plugin_reportinator: @plugin_reportinator })

    template = File.read(File.expand_path('../../../../plugins/report_tests_gtestlike_stdout/assets/template.erb', __FILE__))
    @plugin_reportinator.register_test_results_template(template)
  end

  def render(results)
    captured = nil
    allow(@loginator).to receive(:log) { |output, *_| captured = output }
    @plugin_reportinator.run_test_results_report({ context: TEST_SYM, results: results })
    captured
  end

  # --- Baseline: a pass/fail-only fixture must render identically before
  # and after the ignore-handling fix, since the fix only touches how
  # ignored tests are handled. ---

  let(:pass_fail_only) do
    {
      times: { 'test/TestFoo.c' => 0.5 },
      counts: { total: 2, passed: 1, failed: 1, ignored: 0, stdout: 0 },
      successes: [ { source: { file: 'test/TestFoo.c' }, collection: [ { test: 'test_a', pass: true } ] } ],
      failures:  [ { source: { file: 'test/TestFoo.c' },
                     collection: [ { test: 'test_b', line: 10, message: 'Expected 1 Was 2.' } ] } ],
      ignores: []
    }
  end

  it 'lists every passed and failed test, with correct header/footer counts, when there are no ignores at all' do
    output = render(pass_fail_only)

    expect(output).to include('Running 2 tests from 1 test cases.')
    expect(output).to include('[       OK ] test/TestFoo.c.test_a (0 ms)')
    expect(output).to include('[  FAILED  ] test/TestFoo.c.test_b (0 ms)')
    expect(output).to include('[  PASSED  ] 1 tests.')
    expect(output).to include('[  FAILED  ] 1 tests, listed below:')
  end

  # --- Fix below this point: written to fail against pre-fix code ---

  describe 'with an ignored test present' do
    let(:results) do
      {
        times: { 'test/TestFoo.c' => 0.5 },
        counts: { total: 3, passed: 1, failed: 1, ignored: 1, stdout: 0 },
        successes: [ { source: { file: 'test/TestFoo.c' }, collection: [ { test: 'test_a', pass: true } ] } ],
        failures:  [ { source: { file: 'test/TestFoo.c' },
                       collection: [ { test: 'test_b', line: 10, message: 'Expected 1 Was 2.' } ] } ],
        ignores:   [ { source: { file: 'test/TestFoo.c' },
                       collection: [ { test: 'test_ignored', line: 20, message: 'not ready' } ] } ]
      }
    end

    it 'never mentions the ignored test at all -- no [ OK ], no [ FAILED ], no line for it' do
      output = render(results)
      expect(output).not_to include('test_ignored')
    end

    it "reports the header total as passed+failed, not counts[:total] which includes the ignore" do
      output = render(results)
      expect(output).to include('Running 2 tests from 1 test cases.')
    end

    it 'still reports the real passed/failed footer counts, unaffected by the ignore' do
      output = render(results)
      expect(output).to include('[  PASSED  ] 1 tests.')
      expect(output).to include('[  FAILED  ] 1 tests, listed below:')
    end
  end

  it 'produces no per-file section at all for a file whose only test is ignored' do
    results = {
      times: { 'test/TestOnlyIgnored.c' => 0.1 },
      counts: { total: 1, passed: 0, failed: 0, ignored: 1, stdout: 0 },
      successes: [], failures: [],
      ignores: [ { source: { file: 'test/TestOnlyIgnored.c' }, collection: [ { test: 'test_ignored', line: 5, message: '' } ] } ]
    }

    output = render(results)

    expect(output).not_to include('TestOnlyIgnored')
    expect(output).to include('No tests executed.')
  end
end
