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
  let(:file_wrapper)     { double('file_wrapper') }
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
      file_wrapper:   file_wrapper,
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

  describe '#build_report_types' do
    it 'maps configured report types to ReportGenerator names, silently dropping unrecognized ones' do
      result = reportinator.send(:build_report_types, { gcov_reports: ['HtmlBasic', 'Cobertura', 'NotARealType'] })
      expect(result).to eq(['HtmlSummary', 'Cobertura'])
    end
  end

  # All real filesystem I/O in this class is routed through @file_wrapper --
  # no real files or directories are touched by any spec in this describe block.
  describe '#run_gcov' do
    def stub_exec(exit_code:, output:)
      allow(tool_executor).to receive(:build_command_line).and_return({ options: {} })
      allow(tool_executor).to receive(:exec).and_return({ exit_code: exit_code, output: output })
    end

    it 'renames the file gcov reports creating, extracted from "Creating \'file.gcov\'" output' do
      stub_exec(exit_code: 0, output: "Creating 'a1b2.gcov'\n")
      allow(file_wrapper).to receive(:exist?).with('a1b2.gcov').and_return(true)
      expect(file_wrapper).to receive(:mv).with('a1b2.gcov', File.join('build/gcov/out/test_foo', 'a1b2.gcov'))
      reportinator.send(:run_gcov, 'build/gcov/out/test_foo/foo.c.gcno', '/proj/')
    end

    it 'renames every file mentioned across multiple "Creating" lines in one invocation' do
      stub_exec(exit_code: 0, output: "Creating 'a1b2.gcov'\nCreating 'c3d4.gcov'\n")
      allow(file_wrapper).to receive(:exist?).and_return(true)
      expect(file_wrapper).to receive(:mv).with('a1b2.gcov', anything)
      expect(file_wrapper).to receive(:mv).with('c3d4.gcov', anything)
      reportinator.send(:run_gcov, 'build/gcov/out/test_foo/foo.c.gcno', '/proj/')
    end

    it 'skips the rename when the file does not exist' do
      stub_exec(exit_code: 0, output: "Creating 'a1b2.gcov'\n")
      allow(file_wrapper).to receive(:exist?).and_return(false)
      expect(file_wrapper).to_not receive(:mv)
      reportinator.send(:run_gcov, 'build/gcov/out/test_foo/foo.c.gcno', '/proj/')
    end

    it 'skips the rename when source and destination are already identical' do
      stub_exec(exit_code: 0, output: "Creating 'build/gcov/out/test_foo/a1b2.gcov'\n")
      allow(file_wrapper).to receive(:exist?).and_return(true)
      expect(file_wrapper).to_not receive(:mv)
      reportinator.send(:run_gcov, 'build/gcov/out/test_foo/foo.c.gcno', '/proj/')
    end

    it 'logs a COMPLAIN on non-zero exit but still proceeds to scan and rename (documented non-fatal behavior)' do
      stub_exec(exit_code: 1, output: "Creating 'a1b2.gcov'\n")
      allow(file_wrapper).to receive(:exist?).and_return(true)
      expect(loginator).to receive(:log).with(/could not process/, Verbosity::COMPLAIN)
      expect(file_wrapper).to receive(:mv)
      reportinator.send(:run_gcov, 'build/gcov/out/test_foo/foo.c.gcno', '/proj/')
    end
  end

  describe '#generate_gcov_files' do
    it 'discovers directories containing .gcno files and dispatches sorted, per-dir work to the batchinator' do
      allow(file_wrapper).to receive(:directory_listing)
        .with(File.join(GCOV_BUILD_OUTPUT_PATH, '**', "*#{EXTENSION_GCNO}"))
        .and_return([
          'build/gcov/out/test_foo/src/foo.c.gcno',
          'build/gcov/out/test_foo/src/ceedling_partial_foo_impl.c.gcno',
        ])
      allow(file_wrapper).to receive(:directory_listing)
        .with(File.join('build/gcov/out/test_foo/src', "*#{EXTENSION_GCNO}"))
        .and_return([
          # Deliberately listed partial-first -- generate_gcov_files must still sort the
          # partial after its non-partial counterpart regardless of listing order.
          'build/gcov/out/test_foo/src/ceedling_partial_foo_impl.c.gcno',
          'build/gcov/out/test_foo/src/foo.c.gcno',
        ])

      dispatched = nil
      allow(batchinator).to receive(:exec) { |workload:, things:, &_blk| dispatched = { workload: workload, things: things } }

      reportinator.send(:generate_gcov_files, nil)

      expect(dispatched[:workload]).to eq(:compile)
      expect(dispatched[:things].length).to eq(1)
      expect(dispatched[:things].first[:gcno_files]).to eq([
        'build/gcov/out/test_foo/src/foo.c.gcno',
        'build/gcov/out/test_foo/src/ceedling_partial_foo_impl.c.gcno',
      ])
    end

    it 'excludes .gcno files matching gcno_exclude_regex, dropping a directory entirely once empty' do
      allow(file_wrapper).to receive(:directory_listing)
        .with(File.join(GCOV_BUILD_OUTPUT_PATH, '**', "*#{EXTENSION_GCNO}"))
        .and_return(['build/gcov/out/test_foo/test_foo_runner.c.gcno'])
      allow(file_wrapper).to receive(:directory_listing)
        .with(File.join('build/gcov/out/test_foo', "*#{EXTENSION_GCNO}"))
        .and_return(['build/gcov/out/test_foo/test_foo_runner.c.gcno'])

      dispatched = nil
      allow(batchinator).to receive(:exec) { |workload:, things:, &_blk| dispatched = things }

      reportinator.send(:generate_gcov_files, /test_foo_runner/)

      expect(dispatched).to eq([])
    end
  end

  describe '#run_reportgenerator' do
    it 'logs a COMPLAIN and returns nil without ever building a command when no .gcov files exist' do
      allow(file_wrapper).to receive(:directory_listing).and_return([])
      expect(tool_executor).to_not receive(:build_command_line)
      expect(loginator).to receive(:log).with(/No matching \.gcno coverage files found/, Verbosity::COMPLAIN)

      result = reportinator.send(:run_reportgenerator, { gcov_reports: [], collection_paths_source: [] }, {})
      expect(result).to be_nil
    end

    it 'proceeds normally when .gcov files are present' do
      allow(file_wrapper).to receive(:directory_listing).and_return(['build/gcov/out/test_foo/foo.c.gcov'])
      allow(tool_executor).to receive(:build_command_line).and_return({})
      expect(tool_executor).to receive(:exec).and_return({ exit_code: 0 })

      result = reportinator.send(
        :run_reportgenerator,
        { gcov_reports: ['HtmlBasic'], collection_paths_source: ['src'] },
        { file_filters: 'x' }
      )
      expect(result).to eq({ exit_code: 0 })
    end
  end
end
