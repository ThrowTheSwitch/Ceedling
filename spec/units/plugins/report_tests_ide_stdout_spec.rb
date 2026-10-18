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
require 'ceedling/templateinator'

# Renders DEFAULT_TESTS_RESULTS_REPORT_TEMPLATE (lib/ceedling/defaults.rb) --
# this plugin's actual template asset, despite its generic-sounding name --
# through the real PluginReportinator pipeline.
describe "report_tests_ide_stdout template" do
  before(:each) do
    @loginator = double('loginator')
    allow(@loginator).to receive(:decorate) { |str, _label| str }

    @plugin_reportinator = PluginReportinator.new(
      {
        plugin_reportinator_helper: nil, plugin_manager: nil,
        reportinator: Reportinator.new, loginator: @loginator,
        templateinator: Templateinator.new
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

  it 'lists stdout output by source file' do
    expect(render(results)).to include("test/TestFoo.c: \"debug line\"")
  end

  it 'reports "No tests executed." when nothing ran' do
    empty = results.merge(counts: { total: 0, passed: 0, failed: 0, ignored: 0, stdout: 0 }, failures: [], ignores: [], stdout: [])
    expect(render(empty)).to include('No tests executed.')
  end

  # Every line of a multi-line message stays a link an IDE can follow
  it 'reindents a multi-line failure message, prefixing every continuation line with file:line:test:' do
    output = render(results)

    expect(output).to include(
      "test/TestFoo.c:30:test_c: \"Expected 1\ntest/TestFoo.c:30:test_c: Was 2\""
    )
  end

  it "decorates the summary banner the same way the pretty report does" do
    render(results)
    expect(@loginator).to have_received(:decorate).with('OVERALL TEST SUMMARY', LogLabels::FAIL)
  end
end

describe 'ReportTestsIdeStdout' do
  before(:all) do
    require 'ceedling/plugins/plugin'
    $: << File.expand_path('../../../../plugins/report_tests_ide_stdout/lib', __FILE__)
    $: << File.expand_path('../../../../lib/ceedling/plugins', __FILE__)
    require 'report_tests_ide_stdout'
  end

  # The plugin's whole difference from its siblings is the template it reports with
  it "reports with Ceedling's default test results template" do
    plugin = ReportTestsIdeStdout.allocate
    expect(plugin.send(:load_template)).to eq(DEFAULT_TESTS_RESULTS_REPORT_TEMPLATE)
  end

  # The golden fixtures hold the report as ERB rendered it, so the plugin's own report,
  # rendered through the plugin, must match them byte for byte
  describe 'report against the captured ERB output' do
    require 'template_render_cases'

    before(:each) do
      @loginator = double('loginator')
      allow(@loginator).to receive(:decorate) { |str, _label| str }
      allow(@loginator).to receive(:log) { |output, *_| @captured = output }

      @reportinator = PluginReportinator.new(
        { plugin_reportinator_helper: nil, plugin_manager: nil, reportinator: Reportinator.new,
          loginator: @loginator, templateinator: Templateinator.new }
      )

      file_wrapper = double('file_wrapper')
      allow(file_wrapper).to receive(:exist?) { |path| File.exist?( path ) }
      allow(file_wrapper).to receive(:read) { |path| File.read( path ) }

      @system_objects = { plugin_reportinator: @reportinator, file_wrapper: file_wrapper, configurator: nil,
                          file_path_utils: nil, rake_invocation_tracker: nil }
      @reportinator.set_system_objects( @system_objects )
    end

    def plugin
      root = File.join( TemplateRenderCases::ROOT, 'plugins', 'report_tests_ide_stdout' )
      return @system_objects[:report_tests_ide_stdout] = ReportTestsIdeStdout.new( @system_objects, 'report_tests_ide_stdout', root )
    end

    # Newlines normalized as the golden spec does, so a checkout's line endings don't matter
    def render(hash)
      template = TemplateRenderCases.normalize_newlines( plugin.send(:load_template) )
      @reportinator.run_report( template, hash )
      return @captured
    end

    TemplateRenderCases.cases.each_pair do |case_name, hash|
      it "renders #{case_name} exactly as ERB did" do
        fixture = File.join( TemplateRenderCases::FIXTURES_PATH, "ide__#{case_name}.txt" )

        expect(render( Marshal.load( Marshal.dump( hash ) ) ).b).to eq( File.binread( fixture ) )
      end
    end
  end
end
