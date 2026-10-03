# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/constants'
require 'ceedling/exceptions'
require 'ceedling/path_mirror'
require 'ceedling/file_path_utils'

PROJECT_BUILD_ROOT           = 'build'     unless defined?(PROJECT_BUILD_ROOT)
PROJECT_BUILD_ARTIFACTS_ROOT = 'artifacts' unless defined?(PROJECT_BUILD_ARTIFACTS_ROOT)

$: << File.expand_path('../../../../plugins/gcov/lib', __FILE__)

require 'gcov_constants'
require 'gcov_types'
require 'gcov_reportinator'
require 'console_reportinator'

TOOLS_GCOV_SUMMARY = { name: 'gcov_summary' }.freeze unless defined?(TOOLS_GCOV_SUMMARY)

describe ConsoleReportinator do
  let(:loginator)           { double('loginator', log: nil, lazy: nil) }
  let(:plugin_reportinator) { double('plugin_reportinator', generate_banner: 'BANNER', generate_heading: 'HEADING') }
  let(:test_invoker)        { double('test_invoker') }
  let(:tool_executor)       { double('tool_executor') }
  let(:configurator) do
    double('configurator', paths_source: ['src'], paths_support: ['support'], cmock_mock_prefix: 'mock_')
  end
  # Real, so reversing a generated Partial filename here exercises the same code that
  # builds those filenames rather than a restatement of it. Touches no filesystem.
  let(:file_path_utils) do
    FilePathUtils.new({ configurator: configurator, file_wrapper: double('file_wrapper') })
  end
  let(:system_objects) do
    {
      configurator:        configurator,
      loginator:            loginator,
      plugin_reportinator:  plugin_reportinator,
      test_invoker:         test_invoker,
      tool_executor:        tool_executor,
      file_path_utils:      file_path_utils,
    }
  end

  let(:reportinator) { described_class.new(system_objects, {}) }

  describe '#remap_partial_sources' do
    it 'passes sources through unchanged when there are no Partials' do
      sources = ['src/foo.c', 'src/bar.c']
      expect( reportinator.send(:remap_partial_sources, sources) ).to eq(sources)
    end

    it 'drops the original source a Partial replaces' do
      sources = ['src/foo.c', 'src/ceedling_partial_foo_impl.c']
      result = reportinator.send(:remap_partial_sources, sources)
      expect(result).to eq(['src/ceedling_partial_foo_impl.c'])
    end

    it 'leaves an unrelated source alone when its module has no matching Partial' do
      sources = ['src/foo.c', 'src/bar.c', 'src/ceedling_partial_foo_impl.c']
      result = reportinator.send(:remap_partial_sources, sources)
      expect(result).to eq(['src/bar.c', 'src/ceedling_partial_foo_impl.c'])
    end

    # A Partial replaces one module, identified by its path. Matching on basename alone
    # drops every same-named module, so a module nobody Partialized loses its coverage
    # report entirely.
    it 'keeps a same-named module that no Partial replaces' do
      sources = [
        'src/drivers/uart/config.c',
        'src/drivers/spi/config.c',
        'build/test/partials/t/drivers/uart/ceedling_partial_config_impl.c'
      ]

      result = reportinator.send(:remap_partial_sources, sources)

      expect(result).to eq([
        'src/drivers/spi/config.c',
        'build/test/partials/t/drivers/uart/ceedling_partial_config_impl.c'
      ])
    end

    it 'drops each same-named module when a Partial replaces both' do
      sources = [
        'src/drivers/uart/config.c',
        'src/drivers/spi/config.c',
        'build/test/partials/t/drivers/uart/ceedling_partial_config_impl.c',
        'build/test/partials/t/drivers/spi/ceedling_partial_config_impl.c'
      ]

      result = reportinator.send(:remap_partial_sources, sources)

      expect( result.select { |s| s.start_with?('src/') } ).to be_empty
      expect( result.length ).to eq(2)
    end

    it 'handles multiple Partials, each dropping only its own original' do
      sources = ['src/foo.c', 'src/bar.c', 'src/ceedling_partial_foo_impl.c', 'src/ceedling_partial_bar_impl.c']
      result = reportinator.send(:remap_partial_sources, sources)
      expect(result).to eq(['src/ceedling_partial_foo_impl.c', 'src/ceedling_partial_bar_impl.c'])
    end
  end

  describe '#extract_gcov_source_path' do
    it 'matches the File header for the queried source filename among several' do
      results = "File '/proj/src/stdio_stub.h'\nLines executed:10.00% of 1\nFile '/proj/src/foo.c'\nLines executed:80.00% of 5\n"
      path = reportinator.send(:extract_gcov_source_path, results, 'test_foo', 'src/foo.c')
      expect(path).to eq(File.expand_path('/proj/src/foo.c'))
    end

    it 'falls back to the first File header when the exact filename never appears (Partial remapping)' do
      results = "File '/proj/src/foo.c'\nLines executed:80.00% of 5\n"
      path = reportinator.send(:extract_gcov_source_path, results, 'test_foo', 'src/ceedling_partial_foo_impl.c')
      expect(path).to eq(File.expand_path('/proj/src/foo.c'))
    end

    it 'returns an empty string and logs when no File header can be parsed at all' do
      expect(loginator).to receive(:lazy).with(Verbosity::DEBUG, LogLabels::ERROR)
      path = reportinator.send(:extract_gcov_source_path, "no file headers here\n", 'test_foo', 'src/foo.c')
      expect(path).to eq('')
    end
  end

  describe '#log_coverage_report' do
    let(:results) do
      "File '/proj/src/foo.c'\n" \
      "Lines executed:80.00% of 5\n" \
      "File '/proj/src/bar.c'\n" \
      "Lines executed:50.00% of 2\n"
    end

    it 'extracts and logs only the section between the matching File header and the next one' do
      expect(loginator).to receive(:log).with("foo.c | Lines executed:80.00% of 5\n")
      reportinator.send(:log_coverage_report, 'test_foo', 'src/foo.c', results, File.expand_path('src/foo.c'))
    end

    it 'uses the original module name (gcov_source) for a Partial, not the Partial filename' do
      expect(loginator).to receive(:log).with("foo.c | Lines executed:80.00% of 5\n")
      reportinator.send(
        :log_coverage_report, 'test_foo', 'src/ceedling_partial_foo_impl.c', results, File.expand_path('src/foo.c')
      )
    end

    it 'labels the report line with a supplied disambiguating label' do
      expect(loginator).to receive(:log).with("drivers/uart/foo.c | Lines executed:80.00% of 5\n")
      reportinator.send(
        :log_coverage_report, 'test_foo', 'src/foo.c', results, File.expand_path('src/foo.c'),
        label: 'drivers/uart/foo.c'
      )
    end

    it 'logs a COMPLAIN and does not crash when a Partial\'s coverage cannot be matched at all' do
      expect(loginator).to receive(:lazy).with(Verbosity::COMPLAIN)
      reportinator.send(:log_coverage_report, 'test_foo', 'src/ceedling_partial_foo_impl.c', results, '')
    end

    it 'logs a COMPLAIN for a non-Partial source with no matching coverage results' do
      expect(loginator).to receive(:lazy).with(Verbosity::COMPLAIN)
      reportinator.send(:log_coverage_report, 'test_foo', 'src/other.c', results, File.expand_path('src/elsewhere.c'))
    end

    it 'filters out gcov informational lines that echo the source filename' do
      noisy_results = "File '/proj/src/foo.c'\nfoo.c: some gcov note\nLines executed:80.00% of 5\n"
      expect(loginator).to receive(:log).with("foo.c | Lines executed:80.00% of 5\n")
      reportinator.send(:log_coverage_report, 'test_foo', 'src/foo.c', noisy_results, File.expand_path('src/foo.c'))
    end
  end

  describe '#run_gcov_summary' do
    # build_command_line's real return shape always includes :options -- run_gcov_summary
    # mutates command[:options][:boom], so the stub must include an empty :options hash.
    def stub_exec(exit_code:, output:)
      allow(tool_executor).to receive(:build_command_line).and_return({ options: {} })
      allow(tool_executor).to receive(:exec).and_return({ exit_code: exit_code, output: output })
    end

    it 'passes -g only when :gcov_mcdc is configured' do
      stub_exec(exit_code: 0, output: 'coverage text')
      expect(tool_executor).to receive(:build_command_line).with(TOOLS_GCOV_SUMMARY, ['-g'], any_args).and_return({ options: {} })
      reportinator.send(:run_gcov_summary, 'test_foo', 'src/foo.c', { gcov_mcdc: true })
    end

    it 'omits -g when :gcov_mcdc is not configured' do
      stub_exec(exit_code: 0, output: 'coverage text')
      expect(tool_executor).to receive(:build_command_line).with(TOOLS_GCOV_SUMMARY, [], any_args).and_return({ options: {} })
      reportinator.send(:run_gcov_summary, 'test_foo', 'src/foo.c', {})
    end

    it 'searches a nested source\'s mirrored subdirectory, not the flat test-output root' do
      allow(configurator).to receive(:paths_source).and_return(['src'])
      allow(configurator).to receive(:paths_support).and_return([])
      stub_exec(exit_code: 0, output: 'coverage text')
      expect(tool_executor).to receive(:build_command_line)
        .with(TOOLS_GCOV_SUMMARY, [], 'foo.c', File.join('build/gcov/out/test_foo', 'nested'))
        .and_return({ options: {} })
      reportinator.send(:run_gcov_summary, 'test_foo', 'src/nested/foo.c', {})
    end

    it 'searches the flat test-output root for a source directly under a configured path' do
      allow(configurator).to receive(:paths_source).and_return(['src'])
      allow(configurator).to receive(:paths_support).and_return([])
      stub_exec(exit_code: 0, output: 'coverage text')
      expect(tool_executor).to receive(:build_command_line)
        .with(TOOLS_GCOV_SUMMARY, [], 'foo.c', 'build/gcov/out/test_foo')
        .and_return({ options: {} })
      reportinator.send(:run_gcov_summary, 'test_foo', 'src/foo.c', {})
    end

    # A generated Partial sits below its own test's Partials build root, not a configured
    # source root, so measuring against the source roots yields no subdirectory at all and
    # gcov is pointed at the flat root while the coverage data sits one level down.
    it 'searches a generated Partial\'s own mirrored subdirectory' do
      allow(configurator).to receive(:paths_source).and_return(['src'])
      allow(configurator).to receive(:paths_support).and_return([])
      allow(configurator).to receive(:project_test_partials_path).and_return('build/test/partials')
      stub_exec(exit_code: 0, output: 'coverage text')

      expect(tool_executor).to receive(:build_command_line)
        .with(TOOLS_GCOV_SUMMARY, [], 'ceedling_partial_config_impl.c',
              File.join('build/gcov/out/test_foo', 'drivers/uart'))
        .and_return({ options: {} })

      reportinator.send(
        :run_gcov_summary,
        'test_foo',
        'build/test/partials/test_foo/drivers/uart/ceedling_partial_config_impl.c',
        {}
      )
    end

    it 'searches the flat root for a Partial of a module named without a directory' do
      allow(configurator).to receive(:paths_source).and_return(['src'])
      allow(configurator).to receive(:paths_support).and_return([])
      allow(configurator).to receive(:project_test_partials_path).and_return('build/test/partials')
      stub_exec(exit_code: 0, output: 'coverage text')

      expect(tool_executor).to receive(:build_command_line)
        .with(TOOLS_GCOV_SUMMARY, [], 'ceedling_partial_config_impl.c', 'build/gcov/out/test_foo')
        .and_return({ options: {} })

      reportinator.send(
        :run_gcov_summary,
        'test_foo',
        'build/test/partials/test_foo/ceedling_partial_config_impl.c',
        {}
      )
    end

    it 'returns nil and logs when gcov exits non-zero' do
      stub_exec(exit_code: 1, output: 'gcov: error')
      expect(loginator).to receive(:lazy).with(Verbosity::DEBUG, LogLabels::ERROR)
      expect(loginator).to receive(:lazy).with(Verbosity::COMPLAIN)
      expect( reportinator.send(:run_gcov_summary, 'test_foo', 'src/foo.c', {}) ).to be_nil
    end

    it 'returns nil and logs when gcov succeeds but produces blank output' do
      stub_exec(exit_code: 0, output: '   ')
      expect(loginator).to receive(:lazy).with(Verbosity::COMPLAIN, LogLabels::NOTICE)
      expect( reportinator.send(:run_gcov_summary, 'test_foo', 'src/foo.c', {}) ).to be_nil
    end

    it 'returns the stripped output on success' do
      stub_exec(exit_code: 0, output: "  coverage text  \n")
      expect( reportinator.send(:run_gcov_summary, 'test_foo', 'src/foo.c', {}) ).to eq('coverage text')
    end

    it 'never raises on a non-zero exit (boom disabled for the summary tool)' do
      command_capture = nil
      allow(tool_executor).to receive(:build_command_line) { |*| command_capture = { options: {} }; command_capture }
      allow(tool_executor).to receive(:exec).and_return({ exit_code: 1, output: 'error' })
      reportinator.send(:run_gcov_summary, 'test_foo', 'src/foo.c', {})
      expect(command_capture[:options]).to eq({ boom: false })
    end
  end

  describe '#log_untested_sources_section' do
    it 'sorts entries by basename, not full path' do
      expect(loginator).to receive(:log).with('a.c | No tests executed: 0% coverage').ordered
      expect(loginator).to receive(:log).with('z.c | No tests executed: 0% coverage').ordered
      # 'zzz/a.c' sorts after 'aaa/z.c' by full path, but must log a.c first by basename.
      reportinator.send(:log_untested_sources_section, ['aaa/z.c', 'zzz/a.c'])
    end
  end

  # Every reported file is labeled by basename, so two same-named modules in one test are
  # indistinguishable in the summary. Only a label that carries enough trailing path tells
  # the reader which module a line belongs to.
  describe '#disambiguated_labels' do
    it 'labels a unique basename by basename alone' do
      labels = reportinator.send(:disambiguated_labels, ['src/foo.c', 'src/bar.c'])

      expect( labels ).to eq({ 'src/foo.c' => 'foo.c', 'src/bar.c' => 'bar.c' })
    end

    it 'extends a duplicated basename by one directory' do
      paths = ['src/drivers/uart/config.c', 'src/drivers/spi/config.c']

      expect( reportinator.send(:disambiguated_labels, paths) ).to eq({
        'src/drivers/uart/config.c' => 'uart/config.c',
        'src/drivers/spi/config.c'  => 'spi/config.c'
      })
    end

    # Only as much trailing path as it takes, so a label never carries noise.
    it 'extends only as far as it takes to distinguish' do
      paths = ['a/shared/net/config.c', 'b/shared/net/config.c']

      expect( reportinator.send(:disambiguated_labels, paths) ).to eq({
        'a/shared/net/config.c' => 'a/shared/net/config.c',
        'b/shared/net/config.c' => 'b/shared/net/config.c'
      })
    end

    it 'leaves an unrelated unique basename alone while extending a duplicated one' do
      paths = ['src/drivers/uart/config.c', 'src/drivers/spi/config.c', 'src/main.c']

      labels = reportinator.send(:disambiguated_labels, paths)

      expect( labels['src/main.c'] ).to eq('main.c')
      expect( labels['src/drivers/uart/config.c'] ).to eq('uart/config.c')
    end

    it 'preserves case, these being read by a person' do
      paths = ['src/Drivers/UART/Config.c', 'src/drivers/spi/Config.c']

      labels = reportinator.send(:disambiguated_labels, paths)

      expect( labels['src/Drivers/UART/Config.c'] ).to eq('UART/Config.c')
    end

    it 'handles a repeated path appearing twice' do
      labels = reportinator.send(:disambiguated_labels, ['src/foo.c', 'src/foo.c'])

      expect( labels ).to eq({ 'src/foo.c' => 'foo.c' })
    end
  end

  describe '#generate_reports' do
    it 'skips extraction/logging for a source whose gcov summary comes back nil' do
      allow(test_invoker).to receive(:each_test_with_sources).and_yield('test_foo', ['src/foo.c'])
      allow(reportinator).to receive(:remap_partial_sources).and_return(['src/foo.c'])
      allow(reportinator).to receive(:run_gcov_summary).and_return(nil)
      expect(reportinator).to_not receive(:extract_gcov_source_path)
      expect(reportinator).to_not receive(:log_coverage_report)

      reportinator.generate_reports({})
    end

    it 'skips the untested-sources section when the list is empty' do
      allow(test_invoker).to receive(:each_test_with_sources)
      expect(reportinator).to_not receive(:log_untested_sources_section)
      reportinator.generate_reports({}, untested_sources: [])
    end

    it 'logs the untested-sources section when the list is non-empty' do
      allow(test_invoker).to receive(:each_test_with_sources)
      expect(reportinator).to receive(:log_untested_sources_section).with(['src/untested.c'])
      reportinator.generate_reports({}, untested_sources: ['src/untested.c'])
    end
  end
end
