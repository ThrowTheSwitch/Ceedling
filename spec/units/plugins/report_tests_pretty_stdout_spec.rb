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

# Renders the real template asset through the real ERB/PluginReportinator
# pipeline -- not a reimplementation of the template's own logic -- so this
# proves actual rendered output, including the exact multi-line message
# reindentation that must survive the upcoming refactor to shared helpers
# byte-for-byte.
describe "report_tests_pretty_stdout template" do
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

    template = File.read(File.expand_path('../../../../plugins/report_tests_pretty_stdout/assets/template.erb', __FILE__))
    @plugin_reportinator.register_test_results_template(template)
  end

  def render(results)
    captured = nil
    allow(@loginator).to receive(:log) { |output, *_| captured = output }
    @plugin_reportinator.run_test_results_report({ context: TEST_SYM, results: results })
    captured
  end

  let(:results) do
    {
      counts: { total: 4, passed: 2, failed: 1, ignored: 1, stdout: 0 },
      successes: [],
      failures: [ { source: { file: 'test/TestFoo.c' },
                    collection: [ { test: 'test_c', line: 30, message: "Expected 1\nWas 2" } ] } ],
      ignores:   [ { source: { file: 'test/TestFoo.c' },
                     collection: [ { test: 'test_d', line: 40, message: '' } ] } ],
      stdout: []
    }
  end

  it 'reindents a multi-line failure message so continuation lines align under the line-number header' do
    output = render(results)

    expect(output).to include("Test: test_c\n  At line (30): \"Expected 1\n                Was 2\"")
  end

  it 'reports TESTED/PASSED/FAILED/IGNORED counts and decorates the summary banner red on any failure' do
    output = render(results)

    expect(output).to include("TESTED:  4")
    expect(output).to include("PASSED:  2")
    expect(output).to include("FAILED:  1")
    expect(output).to include("IGNORED: 1")
    expect(@loginator).to have_received(:decorate).with('OVERALL TEST SUMMARY', LogLabels::FAIL)
  end

  it 'decorates the summary banner green when nothing failed' do
    passing = results.merge(counts: { total: 1, passed: 1, failed: 0, ignored: 0, stdout: 0 }, failures: [])
    render(passing)

    expect(@loginator).to have_received(:decorate).with('OVERALL TEST SUMMARY', LogLabels::PASS)
  end

  it 'reports "No tests executed." when nothing ran' do
    output = render(results.merge(counts: { total: 0, passed: 0, failed: 0, ignored: 0, stdout: 0 }, failures: [], ignores: []))
    expect(output).to include('No tests executed.')
  end
end
