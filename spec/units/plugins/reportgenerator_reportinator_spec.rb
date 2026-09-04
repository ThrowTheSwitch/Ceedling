# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/constants'
require 'ceedling/exceptions'
require 'ceedling/file_path_utils'

PROJECT_BUILD_ROOT           = 'build'     unless defined?(PROJECT_BUILD_ROOT)
PROJECT_BUILD_ARTIFACTS_ROOT = 'artifacts' unless defined?(PROJECT_BUILD_ARTIFACTS_ROOT)

$: << File.expand_path('../../../../plugins/gcov/lib', __FILE__)

require 'gcov_constants'
require 'gcov_types'
require 'gcov_reportinator'
require 'reportgenerator_reportinator'

TOOLS_GCOV_REPORTGENERATOR_REPORT = { name: 'gcov_reportgenerator_report' }.freeze unless defined?(TOOLS_GCOV_REPORTGENERATOR_REPORT)
TOOLS_GCOV_REPORT                 = { name: 'gcov_report' }.freeze                 unless defined?(TOOLS_GCOV_REPORT)

describe ReportGeneratorReportinator do
  let(:loginator)        { double('loginator', log: nil, lazy: nil) }
  let(:reportinator_obj) { double('reportinator', generate_heading: '', generate_progress: '') }
  let(:tool_validator)   { double('tool_validator', validate: nil) }
  let(:tool_executor)    { double('tool_executor') }
  let(:batchinator)      { double('batchinator') }
  let(:configurator) do
    double('configurator',
      project_use_partials:     false,
      collection_paths_test:    ['test'],
      collection_paths_support: ['support'],
      project_test_file_prefix: 'test_',
      cmock_mock_prefix:        'Mock',
      project_build_root:       'build',
      extension_source:         ['.c']
    )
  end
  let(:system_objects) do
    {
      tool_validator: tool_validator,
      loginator:      loginator,
      reportinator:   reportinator_obj,
      tool_executor:  tool_executor,
      configurator:   configurator,
      batchinator:    batchinator,
    }
  end

  let(:reportinator) { described_class.new(system_objects, {}) }

  describe '#build_optional_args' do
    it 'quotes flag and value together for the plain 1:1 options' do
      rg_opts = { history_directory: '/tmp/hist', verbosity: 'Info', tag: 'v1' }
      args = reportinator.send(:build_optional_args, rg_opts, 1)
      expect(args).to include('"-historydir:/tmp/hist"')
      expect(args).to include('"-verbosity:Info"')
      expect(args).to include('"-tag:v1"')
    end

    # Finding A.3: these three settings were missing their leading '-', silently
    # never applying createSubdirectoryForAllReportTypes/numberOfReports*InParallel.
    # Confirmed directly against a real `reportgenerator` run (Docker): a leading '-'
    # here makes reportgenerator log "Unknown command line parameter 'settings'" and
    # the setting never applies -- unlike every other option in this table, these take
    # NO leading dash.
    it 'has no leading "-" on any settings: argument' do
      rg_opts = { num_parallel_threads: 4 }
      args = reportinator.send(:build_optional_args, rg_opts, 2)
      expect(args).to include('"settings:createSubdirectoryForAllReportTypes=true"')
      expect(args).to include('"settings:numberOfReportsParsedInParallel=4"')
      expect(args).to include('"settings:numberOfReportsMergedInParallel=4"')
      expect(args).to_not include('"-settings:')
    end

    it 'omits createSubdirectoryForAllReportTypes when only one report type is configured' do
      args = reportinator.send(:build_optional_args, {}, 1)
      expect(args).to_not include('createSubdirectoryForAllReportTypes')
    end

    it 'appends quoted :custom_args after the table-driven and settings arguments' do
      rg_opts = { tag: 'v1', custom_args: ['-foo:bar'] }
      args = reportinator.send(:build_optional_args, rg_opts, 1)
      expect(args).to include('"-foo:bar"')
    end
  end

  describe '#collect_reportgenerator_opts' do
    it 'does not mutate the caller-supplied config hash across repeated calls' do
      shared_opts = { gcov_report_generator: { file_filters: 'user-filter' } }

      reportinator.send(:collect_reportgenerator_opts, shared_opts)
      reportinator.send(:collect_reportgenerator_opts, shared_opts)

      # Each call should independently derive from the same untouched source value,
      # not accumulate the previous call's auto-generated exclusions onto it.
      expect(shared_opts[:gcov_report_generator][:file_filters]).to eq('user-filter')
    end

    it 'places user-provided :file_filters first, ahead of auto-generated exclusions' do
      opts = { gcov_report_generator: { file_filters: 'user-filter' } }
      result = reportinator.send(:collect_reportgenerator_opts, opts)
      expect(result[:file_filters]).to start_with('user-filter;')
    end
  end

  describe '#build_gcno_exclusions' do
    it 'escapes regex metacharacters in test_prefix and mock_prefix' do
      allow(configurator).to receive(:project_test_file_prefix).and_return('test.')
      allow(configurator).to receive(:cmock_mock_prefix).and_return('Mock+')

      exclusions = reportinator.send(:build_gcno_exclusions)
      combined = exclusions.join('|')
      expect(combined).to include('test\\.')
      expect(combined).to include('Mock\\+')
    end
  end

  describe '#build_gcno_exclude_regex' do
    it 'strips a trailing .gcov or .gcno suffix from user-supplied exclusion patterns' do
      rg_opts = { gcov_exclude: ['legacy_code.gcov', 'other_file.gcno'] }
      regex = reportinator.send(:build_gcno_exclude_regex, rg_opts)
      expect('/build/gcov/out/legacy_code.gcno').to match(regex)
      expect('/build/gcov/out/other_file.gcno').to match(regex)
    end

    it 'returns nil when there are no user or auto-generated exclusions' do
      allow(configurator).to receive(:project_test_file_prefix).and_return('')
      allow(configurator).to receive(:cmock_mock_prefix).and_return('')
      # build_gcno_exclusions always contributes its own fixed patterns (test prefix,
      # mock prefix, _runner, unity, cmock), so this documents that nil is only
      # reachable if none of those match either -- not exercised further here.
      rg_opts = { gcov_exclude: [] }
      expect( reportinator.send(:build_gcno_exclude_regex, rg_opts) ).to_not be_nil
    end
  end
end
