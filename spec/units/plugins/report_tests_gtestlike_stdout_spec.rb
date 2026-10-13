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
require 'ceedling/templateinator'
require 'ceedling/plugins/plugin'

$: << File.expand_path('../../../../plugins/report_tests_gtestlike_stdout/lib', __FILE__)
$: << File.expand_path('../../../../lib/ceedling/plugins', __FILE__)
require 'report_tests_gtestlike_stdout'

describe "report_tests_gtestlike_stdout template" do
  # The plugin's default, overridden where a spec exercises the opt-out
  let(:ignored_as_skipped) { true }

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
    plugin = ReportTestsGtestlikeStdout.allocate
    plugin.instance_variable_set( :@ignored_as_skipped, ignored_as_skipped )
    @plugin_reportinator.set_system_objects( { plugin_reportinator: @plugin_reportinator, report_tests_gtestlike_stdout: plugin } )

    template = File.read(File.expand_path('../../../../plugins/report_tests_gtestlike_stdout/assets/test_results.template', __FILE__))
    @plugin_reportinator.register_test_results_template(template)
  end

  def render(results)
    captured = nil
    allow(@loginator).to receive(:log) { |output, *_| captured = output }
    @plugin_reportinator.run_test_results_report({ context: TEST_SYM, results: results })
    captured
  end

  # A suite with no ignored tests renders every test, so its counts are unambiguous

  let(:pass_fail_only) do
    {
      times: { 'test/TestFoo.c' => 0.5 },
      counts: { total: 2, passed: 1, failed: 1, ignored: 0, stdout: 0 },
      successes: [ { source: { file: 'test/TestFoo.c' }, collection: [ { test: 'test_a', line: 5, message: '' } ] } ],
      failures:  [ { source: { file: 'test/TestFoo.c' },
                     collection: [ { test: 'test_b', line: 10, message: 'Expected 1 Was 2.' } ] } ],
      ignores: []
    }
  end

  it 'lists every passed and failed test, with correct header/footer counts, when there are no ignores at all' do
    output = render(pass_fail_only)

    expect(output).to include('Running 2 tests from 1 test suite.')
    expect(output).to include('[       OK ] test/TestFoo.c.test_a (0 ms)')
    expect(output).to include('[  FAILED  ] test/TestFoo.c.test_b (0 ms)')
    expect(output).to include('[  PASSED  ] 1 test.')
    expect(output).to include('[  FAILED  ] 1 test, listed below:')
  end

  # Every reporting plugin receives the same results, so rendering must not alter them
  it 'leaves the results it renders unaltered' do
    results = {
      times: { 'test/TestFoo.c' => 0.5 },
      counts: { total: 2, passed: 1, failed: 1, ignored: 0, stdout: 0 },
      successes: [ { source: { file: 'test/TestFoo.c' }, collection: [ { test: 'test_a', line: 5, message: '' } ] } ],
      failures:  [ { source: { file: 'test/TestFoo.c' }, collection: [ { test: 'test_b', line: 10, message: 'Expected 1 Was 2.' } ] } ],
      ignores: []
    }
    pristine = Marshal.load( Marshal.dump( results ) )

    render(results)

    expect(results).to eq(pristine)
  end

  describe 'with an ignored test present' do
    let(:results) do
      {
        times: { 'test/TestFoo.c' => 0.5 },
        counts: { total: 3, passed: 1, failed: 1, ignored: 1, stdout: 0 },
        successes: [ { source: { file: 'test/TestFoo.c' }, collection: [ { test: 'test_a', line: 5, message: '' } ] } ],
        failures:  [ { source: { file: 'test/TestFoo.c' },
                       collection: [ { test: 'test_b', line: 10, message: 'Expected 1 Was 2.' } ] } ],
        ignores:   [ { source: { file: 'test/TestFoo.c' },
                       collection: [ { test: 'test_ignored', line: 20, message: 'not ready' } ] } ]
      }
    end

    # By default an ignored test reports as a GTest skipped test, counted in the run
    context 'reported as skipped' do
      it 'lists the ignored test as skipped, with its location and message' do
        expect( render(results) ).to include( "[ RUN      ] test/TestFoo.c.test_ignored\ntest/TestFoo.c(20): Skipped\nnot ready\n\n[  SKIPPED ] test/TestFoo.c.test_ignored (0 ms)\n" )
      end

      it 'counts the ignored test in the run and summarizes it as skipped' do
        output = render(results)

        expect( output ).to include( 'Running 3 tests from 1 test suite.' )
        expect( output ).to include( "[  PASSED  ] 1 test.\n[  SKIPPED ] 1 test, listed below:\n[  SKIPPED ] test/TestFoo.c.test_ignored\n" )
      end
    end

    # The opt-out leaves an ignored test out of the report entirely
    context 'left out' do
      let(:ignored_as_skipped) { false }

      it 'never mentions the ignored test at all' do
        expect( render(results) ).not_to include('test_ignored')
      end

      it 'reports the header total as passed plus failed' do
        expect( render(results) ).to include('Running 2 tests from 1 test suite.')
      end

      it 'still reports the real passed and failed footer counts' do
        output = render(results)

        expect( output ).to include('[  PASSED  ] 1 test.')
        expect( output ).to include('[  FAILED  ] 1 test, listed below:')
      end
    end
  end

  # A file's section lists its tests in source order by default
  it 'lists a file\'s tests in source order' do
    results = {
      times: { 'test/TestFoo.c' => 0.5 },
      counts: { total: 2, passed: 1, failed: 1, ignored: 0, stdout: 0 },
      successes: [ { source: { file: 'test/TestFoo.c' }, collection: [ { test: 'test_late', line: 50, message: '' } ] } ],
      failures:  [ { source: { file: 'test/TestFoo.c' }, collection: [ { test: 'test_early', line: 5, message: 'Expected 1 Was 2.' } ] } ],
      ignores: []
    }

    output = render(results)

    expect(output.index('test_early')).to be < output.index('test_late')
  end

  # Source order holds whether or not ignored tests are reported
  context 'left out' do
    let(:ignored_as_skipped) { false }

    it 'still lists a file\'s tests in source order' do
      results = {
        times: { 'test/TestFoo.c' => 0.5 },
        counts: { total: 2, passed: 1, failed: 1, ignored: 0, stdout: 0 },
        successes: [ { source: { file: 'test/TestFoo.c' }, collection: [ { test: 'test_late', line: 50, message: '' } ] } ],
        failures:  [ { source: { file: 'test/TestFoo.c' }, collection: [ { test: 'test_early', line: 5, message: 'Expected 1 Was 2.' } ] } ],
        ignores: []
      }

      output = render(results)

      expect(output.index('test_early')).to be < output.index('test_late')
    end
  end

  # Sections follow each file's first appearance, successes before failures
  it 'orders file sections by first appearance among successes, then failures' do
    results = {
      times: { 'test/TestA.c' => 0.1, 'test/TestB.c' => 0.2 },
      counts: { total: 2, passed: 1, failed: 1, ignored: 0, stdout: 0 },
      successes: [ { source: { file: 'test/TestB.c' }, collection: [ { test: 'test_b', line: 5, message: '' } ] } ],
      failures:  [ { source: { file: 'test/TestA.c' }, collection: [ { test: 'test_a', line: 5, message: 'Expected 1 Was 2.' } ] } ],
      ignores: []
    }

    output = render(results)

    expect(output.index('from test/TestB.c')).to be < output.index('from test/TestA.c')
  end

  # Durations arrive in seconds and print as whole milliseconds, rounded half up
  it 'rounds a file\'s duration to whole milliseconds' do
    results = {
      times: { 'test/TestFoo.c' => 0.0125 },
      counts: { total: 1, passed: 1, failed: 0, ignored: 0, stdout: 0 },
      successes: [ { source: { file: 'test/TestFoo.c' }, collection: [ { test: 'test_a', line: 5, message: '' } ] } ],
      failures: [], ignores: []
    }

    expect(render(results)).to include('test from test/TestFoo.c (13 ms total)')
  end

  describe 'with a file whose only test is ignored' do
    let(:results) do
      {
        times: { 'test/TestOnlyIgnored.c' => 0.1 },
        counts: { total: 1, passed: 0, failed: 0, ignored: 1, stdout: 0 },
        successes: [], failures: [],
        ignores: [ { source: { file: 'test/TestOnlyIgnored.c' }, collection: [ { test: 'test_ignored', line: 5, message: '' } ] } ]
      }
    end

    it 'gives the file a section of skipped tests' do
      output = render(results)

      expect( output ).to include( "[----------] 1 test from test/TestOnlyIgnored.c\n" )
      expect( output ).not_to include('No tests executed.')
    end

    context 'left out' do
      let(:ignored_as_skipped) { false }

      it 'produces no section for the file at all' do
        output = render(results)

        expect( output ).not_to include('TestOnlyIgnored')
        expect( output ).to include('No tests executed.')
      end
    end
  end
end

describe 'ReportTestsGtestlikeStdout' do
  def setup_plugin(configured)
    configurator = double( 'configurator', report_tests_gtestlike_stdout_ignored_as_skipped: configured )
    file_wrapper = double( 'file_wrapper', exist?: true, read: 'gtest template' )
    reportinator = double( 'plugin_reportinator', register_test_results_template: nil )

    system_objects = { configurator: configurator, file_wrapper: file_wrapper, plugin_reportinator: reportinator,
                       file_path_utils: nil, rake_invocation_tracker: nil }

    return ReportTestsGtestlikeStdout.new( system_objects, 'report_tests_gtestlike_stdout', '/plugin' )
  end

  let(:results) do
    {
      times: { 'test/TestFoo.c' => 0.1 },
      counts: { total: 1, passed: 0, failed: 0, ignored: 1, stdout: 0 },
      successes: [], failures: [],
      ignores: [ { source: { file: 'test/TestFoo.c' }, collection: [ { test: 'test_ignored', line: 5, message: '' } ] } ]
    }
  end

  # The option arrives through the plugin's defaults and reaches every report it renders
  it 'reports ignored tests as skipped when configured to' do
    expect( setup_plugin( true ).gtest_report( { context: TEST_SYM, results: results } ) ).to include('[  SKIPPED ]')
  end

  it 'leaves ignored tests out when configured not to' do
    expect( setup_plugin( false ).gtest_report( { context: TEST_SYM, results: results } ) ).not_to include('test_ignored')
  end

  # A quoted 'false' would otherwise read as true and report ignored tests anyway
  it 'rejects a setting that is not a boolean' do
    expect { setup_plugin( 'false' ) }.to raise_error( CeedlingException, /:report_tests_gtestlike_stdout ↳ :ignored_as_skipped/ )
  end

  # The plugin's whole difference from its siblings is the template asset it ships
  it 'reports with the template in its own assets directory' do
    file_wrapper = double('file_wrapper')
    allow(file_wrapper).to receive(:exist?).with('/plugin/assets/test_results.template').and_return(true)
    allow(file_wrapper).to receive(:read).with('/plugin/assets/test_results.template').and_return('gtest template')

    plugin = ReportTestsGtestlikeStdout.allocate
    plugin.instance_variable_set(:@ceedling, { file_wrapper: file_wrapper })
    plugin.instance_variable_set(:@plugin_root_path, '/plugin')

    expect(plugin.send(:load_template)).to eq('gtest template')
  end
end
