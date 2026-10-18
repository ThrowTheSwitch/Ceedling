# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/constants'
require 'ceedling/reportinator'
require 'ceedling/plugins/plugin'
require 'ceedling/plugins/plugin_reportinator'
require 'ceedling/templateinator'
require 'template_render_cases'

$: << File.expand_path('../../../../plugins/report_tests_ide_stdout/lib', __FILE__)
$: << File.expand_path('../../../../lib/ceedling/plugins', __FILE__)
require 'report_tests_ide_stdout'

# Renders the plugin's template asset through the real PluginReportinator pipeline, with
# the plugin itself writing each failed and ignored test's lines
describe ReportTestsIdeStdout do
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

  let(:root_path) { File.join( TemplateRenderCases::ROOT, 'plugins', 'report_tests_ide_stdout' ) }

  def plugin
    return @system_objects[:report_tests_ide_stdout] ||= described_class.new( @system_objects, 'report_tests_ide_stdout', root_path )
  end

  # Newlines normalized as the golden spec does, so a checkout's line endings don't matter
  def render(hash)
    template = TemplateRenderCases.normalize_newlines( plugin.send(:load_template) )
    @reportinator.run_report( template, hash )
    return @captured
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

  def report(results)
    return render( { context: TEST_SYM, results: results } )
  end

  it 'registers the template in its own assets directory' do
    expect(@reportinator).to receive(:register_test_results_template).with( File.read( File.join( root_path, 'assets', 'test_results.template' ) ) )
    plugin
  end

  it 'lists stdout output by source file' do
    expect(report(results)).to include("test/TestFoo.c: \"debug line\"")
  end

  it 'reports "No tests executed." when nothing ran' do
    empty = results.merge(counts: { total: 0, passed: 0, failed: 0, ignored: 0, stdout: 0 }, failures: [], ignores: [], stdout: [])
    expect(report(empty)).to include('No tests executed.')
  end

  # Every line of a multi-line message stays a link an IDE can follow
  it 'reindents a multi-line failure message, prefixing every continuation line with file:line:test:' do
    expect(report(results)).to include(
      "test/TestFoo.c:30:test_c: \"Expected 1\ntest/TestFoo.c:30:test_c: Was 2\""
    )
  end

  it "decorates the summary banner the same way the pretty report does" do
    report(results)
    expect(@loginator).to have_received(:decorate).with('OVERALL TEST SUMMARY', LogLabels::FAIL)
  end

  # The golden fixtures hold the report as ERB rendered it, so the plugin's own report
  # must match them byte for byte
  describe 'report against the captured ERB output' do
    TemplateRenderCases.cases.each_pair do |case_name, hash|
      it "renders #{case_name} exactly as ERB did" do
        fixture = File.join( TemplateRenderCases::FIXTURES_PATH, "ide__#{case_name}.txt" )

        expect(render( Marshal.load( Marshal.dump( hash ) ) ).b).to eq( File.binread( fixture ) )
      end
    end
  end
end
