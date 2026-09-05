# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/constants'
require 'ceedling/reportinator'
require 'ceedling/defaults'
require 'ceedling/plugins/plugin_reportinator'

# Renders DEFAULT_TESTS_RESULTS_REPORT_TEMPLATE (lib/ceedling/defaults.rb) --
# this plugin's actual template asset, despite its generic-sounding name --
# through the real ERB/PluginReportinator pipeline.
describe "report_tests_ide_stdout template" do
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
    @plugin_reportinator.register_test_results_template(DEFAULT_TESTS_RESULTS_REPORT_TEMPLATE)
  end

  def render(results)
    captured = nil
    allow(@loginator).to receive(:log) { |output, *_| captured = output }
    @plugin_reportinator.run_test_results_report({ context: TEST_SYM, results: results })
    captured
  end

  let(:results) do
    {
      counts: { total: 2, passed: 0, failed: 1, ignored: 1, stdout: 1 },
      successes: [],
      failures: [ { source: { file: 'test/TestFoo.c' },
                    collection: [ { test: 'test_c', line: 30, message: "Expected 1\nWas 2" } ] } ],
      ignores:   [ { source: { file: 'test/TestFoo.c' },
                     collection: [ { test: 'test_d', line: 40, message: '' } ] } ],
      stdout:    [ { source: { file: 'test/TestFoo.c' }, collection: [ 'debug line' ] } ]
    }
  end

  # --- Behavior unaffected by this pass, pinned as a baseline ---

  it 'lists stdout output by source file' do
    expect(render(results)).to include("test/TestFoo.c: \"debug line\"")
  end

  it 'reports "No tests executed." when nothing ran' do
    empty = results.merge(counts: { total: 0, passed: 0, failed: 0, ignored: 0, stdout: 0 }, failures: [], ignores: [], stdout: [])
    expect(render(empty)).to include('No tests executed.')
  end

  # --- Fixes below this point: written to fail against pre-fix code ---

  it 'reindents a multi-line failure message, re-prefixing every continuation line with file:line:test: (fix)' do
    output = render(results)

    expect(output).to include(
      "test/TestFoo.c:30:test_c: \"Expected 1\ntest/TestFoo.c:30:test_c: Was 2\""
    )
  end

  it "decorates the summary banner the same way pretty's does (fix: today it never decorates at all)" do
    render(results)
    expect(@loginator).to have_received(:decorate).with('OVERALL TEST SUMMARY', LogLabels::FAIL)
  end
end
