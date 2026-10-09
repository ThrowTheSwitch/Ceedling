# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/constants'
require 'ceedling/plugins/plugin'
require 'ceedling/config/config_walkinator'

$: << File.expand_path('../../../../plugins/report_tests_log_factory/lib', __FILE__)
require 'report_tests_log_factory'
require 'tests_reporter'

describe ReportTestsLogFactory do
  before(:each) do
    @plugin = described_class.allocate
    @plugin.instance_variable_set(:@ceedling, { config_walkinator: ConfigWalkinator.new })
  end

  describe '#setup' do
    before(:each) do
      @loginator = double('loginator')
      ceedling = @plugin.instance_variable_get(:@ceedling)
      ceedling[:loginator]    = @loginator
      ceedling[:reportinator] = double('reportinator')
      ceedling[:file_wrapper] = double('file_wrapper')
    end

    def set_up(reports)
      setupinator = double('setupinator', config_hash: { report_tests_log_factory: { reports: reports } })
      @plugin.instance_variable_get(:@ceedling)[:setupinator] = setupinator
      @plugin.setup
    end

    it 'loads a reporter for each configured report' do
      set_up(['json', 'JUnit'])

      reporters = @plugin.instance_variable_get(:@reporters)
      expect(reporters.map(&:class)).to eq([JsonTestsReporter, JunitTestsReporter])
    end

    it 'reports nothing at all when no reports are configured' do
      set_up([])

      expect(@loginator).to_not receive(:log)
      @plugin.post_build(0)
      @plugin.summary
    end
  end

  describe '#load_reporters' do
    it 'builds a working instance of a known built-in reporter, with its own configuration injected' do
      reporters = @plugin.send(:load_reporters, ['json'], { json: { filename: 'custom.json' } })

      expect(reporters.length).to eq(1)
      expect(reporters.first).to be_a(JsonTestsReporter)
      expect(reporters.first.filename).to eq('custom.json')
    end
  end

  describe '#generate_report_name' do
    before(:each) do
      configurator = double('configurator')
      allow(configurator).to receive(:project_name).and_return('MyProject')
      @plugin.instance_variable_get(:@ceedling)[:configurator] = configurator
    end

    it 'uses the project name unprefixed for the default test context' do
      expect(@plugin.send(:generate_report_name, TEST_SYM)).to eq('MyProject')
    end

    it 'prefixes with the bracketed, uppercased context for any non-default context' do
      expect(@plugin.send(:generate_report_name, :gcov)).to eq('[GCOV] MyProject')
    end

    it 'falls back to the default report name for a blank project name' do
      allow(@plugin.instance_variable_get(:@ceedling)[:configurator]).to receive(:project_name).and_return('  ')
      expect(@plugin.send(:generate_report_name, TEST_SYM)).to eq(TestsReporter::DEFAULT_REPORT_NAME)
    end
  end

  # A configured report name maps to a reporter class by convention
  describe '.reporter_class_name' do
    it 'appends TestsReporter to a capitalized single-word report' do
      expect(described_class.reporter_class_name('json')).to eq('JsonTestsReporter')
    end

    it 'camel-cases a snake-case report' do
      expect(described_class.reporter_class_name('fancy_shmancy')).to eq('FancyShmancyTestsReporter')
    end
  end

  describe 'build hooks' do
    let(:reporter) { double('reporter', filename: 'tests_report.json', write: nil) }

    before(:each) do
      stub_const('PROJECT_BUILD_ARTIFACTS_ROOT', 'build/artifacts')

      @loginator           = double('loginator', log: nil)
      @reportinator        = double('reportinator', generate_heading: '', generate_progress: '')
      @plugin_reportinator = double('plugin_reportinator')
      @configurator        = double('configurator', project_name: 'MyProject')
      allow(@plugin_reportinator).to receive(:assemble_test_results) { |*args| { from: args.first } }

      ceedling = @plugin.instance_variable_get(:@ceedling)
      ceedling[:plugin_reportinator] = @plugin_reportinator
      ceedling[:configurator]        = @configurator

      @plugin.instance_variable_set(:@enabled, true)
      @plugin.instance_variable_set(:@reporters, [reporter])
      @plugin.instance_variable_set(:@build_results, {})
      @plugin.instance_variable_set(:@mutex, Mutex.new)
      @plugin.instance_variable_set(:@loginator, @loginator)
      @plugin.instance_variable_set(:@reportinator, @reportinator)
    end

    def run_build(context, start_s: 100, end_s: 160, results: ['a.pass'])
      @plugin.pre_test_build(context, start_s) if start_s
      results.each { |path| @plugin.post_test_fixture_execute(context: context, result_file: path) }
      @plugin.post_test_build(context, end_s) if end_s
      @plugin.post_build(200)
    end

    it "writes each reporter's report for each context under that context's artifacts directory" do
      expect(reporter).to receive(:write).with(hash_including(filepath: 'build/artifacts/test/tests_report.json', name: 'MyProject'))
      expect(reporter).to receive(:write).with(hash_including(filepath: 'build/artifacts/gcov/tests_report.json', name: '[GCOV] MyProject'))

      run_build(TEST_SYM)
      @plugin.pre_test_build(:gcov, 0)
      @plugin.post_test_fixture_execute(context: :gcov, result_file: 'g.pass')
      @plugin.post_build(200)
    end

    it "reports from every result file a context's test fixtures produced" do
      expect(reporter).to receive(:write).with(hash_including(results: { from: ['a.pass', 'b.pass'] }))
      run_build(TEST_SYM, results: ['a.pass', 'b.pass'])
    end

    it 'reports the build duration from the test build start and end' do
      expect(reporter).to receive(:write).with(hash_including(duration_s: 60))
      run_build(TEST_SYM)
    end

    # `ceedling summary` reaches post_test_fixture_execute without pre_test_build
    it 'reports no duration when the test build start is unknown' do
      expect(reporter).to receive(:write).with(hash_including(duration_s: nil))
      run_build(TEST_SYM, start_s: nil)
    end

    it 'writes nothing when no test results were collected' do
      expect(reporter).to_not receive(:write)
      @plugin.post_build(200)
    end

    it 'does nothing at all when no reports are configured' do
      @plugin.instance_variable_set(:@enabled, false)
      expect(reporter).to_not receive(:write)
      run_build(TEST_SYM)
    end
  end

  # `ceedling summary` reports on results already on disk from an earlier build
  describe '#summary' do
    let(:reporter) { double('reporter', filename: 'tests_report.json', write: nil) }

    before(:each) do
      stub_const('PROJECT_BUILD_ARTIFACTS_ROOT', 'build/artifacts')
      stub_const('PROJECT_TEST_RESULTS_PATH', 'build/test/results')
      stub_const('COLLECTION_ALL_TESTS', ['test/test_a.c'])

      @file_path_utils     = double('file_path_utils')
      @plugin_reportinator = double('plugin_reportinator')
      allow(@file_path_utils).to receive(:form_pass_results_filelist)
        .with('build/test/results', ['test/test_a.c']).and_return(['build/test/results/test_a.pass'])
      allow(@plugin_reportinator).to receive(:assemble_test_results)
        .with(['build/test/results/test_a.pass'], { boom: false }).and_return(:assembled)

      @plugin.instance_variable_get(:@ceedling).merge!(
        file_path_utils: @file_path_utils, plugin_reportinator: @plugin_reportinator,
        configurator: double('configurator', project_name: 'MyProject')
      )
      @plugin.instance_variable_set(:@enabled, true)
      @plugin.instance_variable_set(:@reporters, [reporter])
      @plugin.instance_variable_set(:@loginator, double('loginator', log: nil))
      @plugin.instance_variable_set(:@reportinator, double('reportinator', generate_heading: '', generate_progress: ''))
    end

    it "writes each configured report for the test context from the results on disk, with no duration" do
      expect(reporter).to receive(:write).with(
        name: 'MyProject', filepath: 'build/artifacts/test/tests_report.json', results: :assembled, duration_s: nil
      )
      @plugin.summary
    end

    it 'does nothing when no reports are configured' do
      @plugin.instance_variable_set(:@enabled, false)
      expect(reporter).to_not receive(:write)
      @plugin.summary
    end
  end
end
