# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/constants'
require 'ceedling/plugins/plugin_reportinator'

describe PluginReportinator do
  before(:each) do
    @plugin_reportinator_helper = double('plugin_reportinator_helper')
    @plugin_manager             = double('plugin_manager')
    @reportinator                = double('reportinator')
    @loginator                      = double('loginator')

    @reportinator_plugin = described_class.new(
      {
        :plugin_reportinator_helper => @plugin_reportinator_helper,
        :plugin_manager             => @plugin_manager,
        :reportinator               => @reportinator,
        :loginator                  => @loginator
      }
    )
  end

  # A build's own test results -- pass or fail -- are core information a user
  # silencing routine build chatter still wants to see, so every plugin that
  # prints post-build test results (report_tests_stdout_plugin, gcov, bullseye,
  # valgrind) shares this one answer instead of each deciding independently.
  describe '#test_results_floor_verbosity' do
    it 'is ERRORS' do
      expect( @reportinator_plugin.test_results_floor_verbosity ).to eq( Verbosity::ERRORS )
    end
  end

  describe '#run_test_results_report' do
    it 'raises a CeedlingException when no template has ever been registered' do
      expect {
        @reportinator_plugin.run_test_results_report( { context: TEST_SYM, results: {} } )
      }.to raise_error( CeedlingException, /No test results report template/ )
    end

    it 'renders the registered template once one has been set' do
      @reportinator_plugin.register_test_results_template( 'literal output' )
      expect(@loginator).to receive(:log).with( 'literal output', Verbosity::NORMAL, LogLabels::NONE )

      @reportinator_plugin.run_test_results_report( { context: TEST_SYM, results: {} } )
    end
  end

  describe '#assemble_test_results' do
    it 'fetches and merges results for every path in the list, in order' do
      aggregate = nil
      allow(@plugin_reportinator_helper).to receive(:fetch_results).with('a.pass', {boom: false}).and_return({ marker: :a })
      allow(@plugin_reportinator_helper).to receive(:fetch_results).with('b.pass', {boom: false}).and_return({ marker: :b })
      expect(@plugin_reportinator_helper).to receive(:process_results).ordered do |agg, results|
        aggregate = agg
        expect(results).to eq({ marker: :a })
      end
      expect(@plugin_reportinator_helper).to receive(:process_results).ordered do |agg, results|
        expect(agg).to equal(aggregate) # same aggregate object threaded through both calls
        expect(results).to eq({ marker: :b })
      end

      @reportinator_plugin.assemble_test_results( ['a.pass', 'b.pass'] )
    end
  end

  # --- New helper methods below: written to fail until they exist ---

  describe '#test_report_preamble' do
    it 'extracts the counts a stdout report template needs, plus a context-scoped header prefix' do
      hash = { context: :gcov, results: { counts: { ignored: 2, failed: 1, stdout: 3 } } }

      expect(@reportinator_plugin.test_report_preamble(hash)).to eq({
        ignored: 2, failed: 1, stdout_count: 3, header_prepend: 'GCOV: '
      })
    end

    it 'uses no header prefix for the default test context' do
      hash = { context: TEST_SYM, results: { counts: { ignored: 0, failed: 0, stdout: 0 } } }

      expect(@reportinator_plugin.test_report_preamble(hash)[:header_prepend]).to eq('')
    end
  end

  describe '#reflow_message' do
    it 'leaves a single-line message untouched' do
      expect(@reportinator_plugin.reflow_message("only one line", '  ')).to eq("only one line")
    end

    it 'prefixes every continuation line, leaving the first line as-is' do
      expect(@reportinator_plugin.reflow_message("a\nb\nc", '> ')).to eq("a\n> b\n> c")
    end
  end

  describe '#decorate_summary_banner' do
    it 'decorates as FAIL when any test failed' do
      expect(@loginator).to receive(:decorate).with('OVERALL TEST SUMMARY', LogLabels::FAIL)
      @reportinator_plugin.decorate_summary_banner('OVERALL TEST SUMMARY', 1)
    end

    it 'decorates as PASS when nothing failed' do
      expect(@loginator).to receive(:decorate).with('OVERALL TEST SUMMARY', LogLabels::PASS)
      @reportinator_plugin.decorate_summary_banner('OVERALL TEST SUMMARY', 0)
    end
  end
end
