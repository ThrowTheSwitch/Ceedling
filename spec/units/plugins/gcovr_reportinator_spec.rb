# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/constants'
require 'ceedling/exceptions'
require 'ceedling/reportinator'

PROJECT_BUILD_ROOT           = 'build'     unless defined?(PROJECT_BUILD_ROOT)
PROJECT_BUILD_ARTIFACTS_ROOT = 'artifacts' unless defined?(PROJECT_BUILD_ARTIFACTS_ROOT)

$: << File.expand_path('../../../../plugins/gcov/lib', __FILE__)

require 'gcov_constants'
require 'gcov_types'
require 'gcov_reportinator'
require 'gcovr_reportinator'

# Dummy tool-config identifiers -- real values are only ever opaque hashes
# ToolExecutor#build_command_line consumes; every spec below stubs
# @tool_executor directly, so these just need to exist.
TOOLS_GCOV_GCOVR_REPORT  = { name: 'gcov_gcovr_report' }.freeze  unless defined?(TOOLS_GCOV_GCOVR_REPORT)
TOOLS_GCOV_GCOVR_VERSION = { name: 'gcov_gcovr_version' }.freeze unless defined?(TOOLS_GCOV_GCOVR_VERSION)

describe GcovrReportinator do
  let(:loginator)       { double('loginator', log: nil, lazy: nil) }
  let(:reportinator_obj) { double('reportinator', generate_heading: '', generate_progress: '') }
  let(:tool_validator)   { double('tool_validator', validate: nil) }
  let(:tool_executor)    { double('tool_executor') }
  let(:configurator) do
    double('configurator',
      gcov_mcdc: false,
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
    }
  end

  # Every spec below stubs gcovr's own detected version directly rather than
  # faking a build_command_line/exec round-trip -- the one seam
  # GcovReportinator#detect_tool_version exists to make stubbable.
  def build_reportinator(config = {}, gcovr_version: ToolVersion.new(8, 3))
    allow_any_instance_of(GcovrReportinator).to receive(:get_gcovr_version).and_return(gcovr_version)
    GcovrReportinator.new(system_objects, config)
  end

  describe '#initialize version gating' do
    it 'does not raise when nothing gated is configured' do
      expect { build_reportinator({}) }.to_not raise_error
    end

    it 'raises when :mcdc is configured against gcovr older than 8.0' do
      config = {}
      allow(configurator).to receive(:gcov_mcdc).and_return(true)
      expect {
        build_reportinator(config, gcovr_version: ToolVersion.new(7, 9))
      }.to raise_error(CeedlingException, /:mcdc.*requires gcovr 8\.0 or higher \(found 7\.9\)/)
    end

    it 'does not raise when :mcdc is configured against gcovr 8.0+' do
      allow(configurator).to receive(:gcov_mcdc).and_return(true)
      expect {
        build_reportinator({}, gcovr_version: ToolVersion.new(8, 0))
      }.to_not raise_error
    end

    it 'raises when :fail_under_decision is configured against gcovr older than 7.0' do
      config = { gcov_gcovr: { fail_under_decision: 90 } }
      expect {
        build_reportinator(config, gcovr_version: ToolVersion.new(6, 9))
      }.to raise_error(CeedlingException, /:fail_under_decision.*requires gcovr 7\.0 or higher \(found 6\.9\)/)
    end

    it 'does not raise when :fail_under_decision is configured against gcovr 7.0+' do
      config = { gcov_gcovr: { fail_under_decision: 90 } }
      expect { build_reportinator(config, gcovr_version: ToolVersion.new(7, 0)) }.to_not raise_error
    end

    # Corrected floor (finding A.1): --decisions was introduced in gcovr 5.1, not 6.0.
    it 'raises when bare :decisions is configured against gcovr older than 5.1' do
      config = { gcov_gcovr: { decisions: true } }
      expect {
        build_reportinator(config, gcovr_version: ToolVersion.new(5, 0))
      }.to raise_error(CeedlingException, /:decisions.*requires gcovr 5\.1 or higher \(found 5\.0\)/)
    end

    it 'does not raise when bare :decisions is configured against gcovr 5.1+' do
      config = { gcov_gcovr: { decisions: true } }
      expect { build_reportinator(config, gcovr_version: ToolVersion.new(5, 1)) }.to_not raise_error
    end
  end

  describe '#args_builder_common' do
    let(:reportinator) { build_reportinator({}) }

    it 'quotes :object_directory and :source_encoding values' do
      gcovr_opts = { object_directory: 'my dir', source_encoding: 'utf 8' }
      args = reportinator.send(:args_builder_common, gcovr_opts, ToolVersion.new(8, 3))
      expect(args).to include('--object-directory "my dir"')
      expect(args).to include('--source-encoding "utf 8"')
    end

    it 'rejects a :fail_under_line value of 0 (the documented range is 1-100)' do
      gcovr_opts = { fail_under_line: 0 }
      expect {
        reportinator.send(:args_builder_common, gcovr_opts, ToolVersion.new(8, 3))
      }.to raise_error(CeedlingException, /must be an integer percentage/)
    end

    it 'accepts a :fail_under_line value of 1' do
      gcovr_opts = { fail_under_line: 1 }
      args = reportinator.send(:args_builder_common, gcovr_opts, ToolVersion.new(8, 3))
      expect(args).to include('--fail-under-line 1')
    end

    it 'implies --decisions when :fail_under_decision is set, even without :decisions' do
      gcovr_opts = { fail_under_decision: 50 }
      args = reportinator.send(:args_builder_common, gcovr_opts, ToolVersion.new(8, 3))
      expect(args).to include('--decisions')
      expect(args).to include('--fail-under-decision 50')
    end

    it 'emits --branches below gcovr 7.0 and --txt-metric branch at 7.0+' do
      gcovr_opts = { branches: true }
      old = reportinator.send(:args_builder_common, gcovr_opts, ToolVersion.new(6, 9))
      new = reportinator.send(:args_builder_common, gcovr_opts, ToolVersion.new(7, 0))
      expect(old).to include('--branches ')
      expect(old).to_not include('--txt-metric')
      expect(new).to include('--txt-metric branch ')
      expect(new).to_not include('--branches ')
    end

    it 'emits --sort-uncovered/--sort-percentage below 7.0 and their replacements at 7.0+' do
      gcovr_opts = { sort_uncovered: true, sort_percentage: true }
      old = reportinator.send(:args_builder_common, gcovr_opts, ToolVersion.new(6, 9))
      new = reportinator.send(:args_builder_common, gcovr_opts, ToolVersion.new(7, 0))
      expect(old).to include('--sort-uncovered ').and include('--sort-percentage ')
      expect(new).to include('--sort uncovered-number ').and include('--sort uncovered-percent ')
    end

    it 'omits --merge-mode-functions below gcovr 6.0 and includes it at 6.0+' do
      gcovr_opts = { merge_mode_function: 'strict' }
      old = reportinator.send(:args_builder_common, gcovr_opts, ToolVersion.new(5, 9))
      new = reportinator.send(:args_builder_common, gcovr_opts, ToolVersion.new(6, 0))
      expect(old).to_not include('--merge-mode-functions')
      expect(new).to include('--merge-mode-functions "strict"')
    end

    it 'applies only --config and :custom_args when a config file is in use' do
      gcovr_opts = { config_file: 'gcovr.cfg', custom_args: ['--verbose'], branches: true }
      args = reportinator.send(:args_builder_common, gcovr_opts, ToolVersion.new(8, 3))
      expect(args).to include('--config "gcovr.cfg"')
      expect(args).to include('"--verbose"')
      expect(args).to_not include('--branches')
      expect(args).to_not include('--txt-metric')
    end
  end

  describe '#check_config_options' do
    it 'logs a COMPLAIN-level warning listing options ignored due to :config_file' do
      config = { gcov_gcovr: { config_file: 'gcovr.cfg', branches: true, decisions: true } }
      expect(loginator).to receive(:log).with(/:branches.*:decisions/, Verbosity::COMPLAIN)
      build_reportinator(config)
    end

    it 'does not warn when no ignored option is configured alongside :config_file' do
      config = { gcov_gcovr: { config_file: 'gcovr.cfg' } }
      expect(loginator).to_not receive(:log).with(any_args, Verbosity::COMPLAIN)
      build_reportinator(config)
    end
  end

  describe '#build_report_exclusions' do
    it 'escapes regex metacharacters in test_prefix and build_root' do
      allow(configurator).to receive(:project_test_file_prefix).and_return('test.')
      allow(configurator).to receive(:project_build_root).and_return('build.out')
      reportinator = build_reportinator({})

      patterns = reportinator.send(:build_report_exclusions)
      combined = patterns.join('|')
      expect(combined).to include('test\\.')
      expect(combined).to include('build\\.out')
      expect(combined).to_not include('test.+')  # unescaped '.' would let literal 'testX' match too
    end
  end

  describe '#gcovr_exec_exception?' do
    let(:reportinator) { build_reportinator({}) }

    it 'raises one exception listing every violated :fail_under_* threshold, not just the first' do
      opts = { fail_under_line: 90, fail_under_branch: 80 }
      # exit code 6 = bit 2 (line) | bit 4 (branch)
      expect {
        reportinator.send(:gcovr_exec_exception?, opts, 6, true, { stderr: '' })
      }.to raise_error(CeedlingException) { |ex|
        expect(ex.message).to match(/Line coverage/)
        expect(ex.message).to match(/Branch coverage/)
      }
    end

    it 'logs (not raises) every violation, clearing their bits, when boom is false' do
      opts = { fail_under_line: 90, fail_under_branch: 80 }
      expect(loginator).to receive(:log).with(/Line coverage/, Verbosity::COMPLAIN)
      expect(loginator).to receive(:log).with(/Branch coverage/, Verbosity::COMPLAIN)
      # exit code 6 (line bit 2 | branch bit 4) is fully explained by the two configured
      # thresholds above -- both bits clear, leaving no unexplained problem.
      expect(
        reportinator.send(:gcovr_exec_exception?, opts, 6, false, { stderr: '' })
      ).to eq(false)
    end

    it 'still reports true when boom is false but the exit code has an unexplained bit left over' do
      opts = { fail_under_line: 90 }
      expect(loginator).to receive(:log).with(/Line coverage/, Verbosity::COMPLAIN)
      # bit 32 has no corresponding :fail_under_* option, so it's never cleared/explained.
      expect(
        reportinator.send(:gcovr_exec_exception?, opts, 2 | 32, false, { stderr: '' })
      ).to eq(true)
    end

    it 'returns false for a plain zero exit code' do
      expect( reportinator.send(:gcovr_exec_exception?, {}, 0, true, { stderr: '' }) ).to eq(false)
    end
  end

  describe '#args_builder_cobertura' do
    let(:reportinator) { build_reportinator({}) }

    it 'returns an empty string when Cobertura is not an enabled report type' do
      expect( reportinator.send(:args_builder_cobertura, { gcov_reports: ['HtmlBasic'] }) ).to eq('')
    end

    it 'uses the default artifact filename when none is configured' do
      args = reportinator.send(:args_builder_cobertura, { gcov_reports: ['Cobertura'] })
      expect(args).to include(GCOV_GCOVR_ARTIFACTS_FILE_COBERTURA)
    end

    it 'joins a custom filename under the gcovr artifacts path' do
      args = reportinator.send(:args_builder_cobertura, { gcov_reports: ['Cobertura'], cobertura_artifact_filename: 'Custom.xml' })
      expect(args).to include(File.join(GCOV_GCOVR_ARTIFACTS_PATH, 'Custom.xml'))
    end

    it 'includes --xml-pretty only when cobertura_pretty is set and no config file is in use' do
      with_pretty = { gcov_reports: ['Cobertura'], cobertura_pretty: true }
      expect( reportinator.send(:args_builder_cobertura, with_pretty) ).to include('--xml-pretty')

      with_pretty_and_config = with_pretty.merge(config_file: 'gcovr.cfg')
      expect( reportinator.send(:args_builder_cobertura, with_pretty_and_config) ).to_not include('--xml-pretty')
    end

    it 'adds --output only when use_output_option is true' do
      gcovr_opts = { gcov_reports: ['Cobertura'] }
      expect( reportinator.send(:args_builder_cobertura, gcovr_opts, true) ).to include('--output')
      expect( reportinator.send(:args_builder_cobertura, gcovr_opts, false) ).to_not include('--output')
    end
  end

  describe '#args_builder_sonarqube' do
    let(:reportinator) { build_reportinator({}) }

    it 'returns an empty string when SonarQube is not enabled, and the default filename when it is' do
      expect( reportinator.send(:args_builder_sonarqube, { gcov_reports: [] }) ).to eq('')
      args = reportinator.send(:args_builder_sonarqube, { gcov_reports: ['SonarQube'] })
      expect(args).to include(GCOV_GCOVR_ARTIFACTS_FILE_SONARQUBE)
    end

    it 'joins a custom filename under the gcovr artifacts path' do
      args = reportinator.send(:args_builder_sonarqube, { gcov_reports: ['SonarQube'], sonarqube_artifact_filename: 'Custom.xml' })
      expect(args).to include(File.join(GCOV_GCOVR_ARTIFACTS_PATH, 'Custom.xml'))
    end
  end

  describe '#args_builder_json' do
    let(:reportinator) { build_reportinator({}) }

    it 'returns an empty string when JSON is not enabled, and the default filename when it is' do
      expect( reportinator.send(:args_builder_json, { gcov_reports: [] }) ).to eq('')
      args = reportinator.send(:args_builder_json, { gcov_reports: ['JSON'] })
      expect(args).to include(GCOV_GCOVR_ARTIFACTS_FILE_JSON)
    end

    it 'includes --json-pretty only when json_pretty is set and no config file is in use' do
      with_pretty = { gcov_reports: ['JSON'], json_pretty: true }
      expect( reportinator.send(:args_builder_json, with_pretty) ).to include('--json-pretty')

      with_pretty_and_config = with_pretty.merge(config_file: 'gcovr.cfg')
      expect( reportinator.send(:args_builder_json, with_pretty_and_config) ).to_not include('--json-pretty')
    end
  end

  describe '#args_builder_html' do
    let(:reportinator) { build_reportinator({}) }

    it 'returns an empty string when neither HTML report type is enabled' do
      expect( reportinator.send(:args_builder_html, { gcov_reports: [] }) ).to eq('')
    end

    it 'is enabled by either HtmlBasic or HtmlDetailed' do
      expect( reportinator.send(:args_builder_html, { gcov_reports: ['HtmlBasic'] }) ).to include('--html ')
      expect( reportinator.send(:args_builder_html, { gcov_reports: ['HtmlDetailed'] }) ).to include('--html ')
    end

    it 'adds --html-details via the HtmlDetailed report type' do
      args = reportinator.send(:args_builder_html, { gcov_reports: ['HtmlDetailed'] })
      expect(args).to include('--html-details')
    end

    it 'adds --html-details via the case-insensitive :gcov_html_report_type string, independent of report type' do
      args = reportinator.send(:args_builder_html, { gcov_reports: ['HtmlBasic'], gcov_html_report_type: 'Detailed' })
      expect(args).to include('--html-details')
    end

    it 'withholds title/absolute-paths/encoding/thresholds when a config file is in use' do
      gcovr_opts = {
        gcov_reports: ['HtmlBasic'], config_file: 'gcovr.cfg',
        html_title: 'T', html_absolute_paths: true, html_encoding: 'UTF-8',
        html_medium_threshold: 75, html_high_threshold: 90
      }
      args = reportinator.send(:args_builder_html, gcovr_opts)
      expect(args).to_not include('--html-title')
      expect(args).to_not include('--html-absolute-paths')
      expect(args).to_not include('--html-encoding')
      expect(args).to_not include('--html-medium-threshold')
      expect(args).to_not include('--html-high-threshold')
      expect(args).to include('--html ')
    end

    it 'joins a custom filename under the gcovr artifacts path' do
      args = reportinator.send(:args_builder_html, { gcov_reports: ['HtmlBasic'], html_artifact_filename: 'Custom.html' })
      expect(args).to include(File.join(GCOV_GCOVR_ARTIFACTS_PATH, 'Custom.html'))
    end
  end

  describe '#generate_reports_modern' do
    let(:reportinator) { build_reportinator({}) }

    it 'never invokes gcovr when no format contributed any arguments' do
      expect(reportinator).to_not receive(:run_gcovr)
      reportinator.send(:generate_reports_modern, { gcov_reports: [] }, '--root x ', false)
    end

    it 'invokes gcovr once when at least one format is enabled' do
      expect(reportinator).to receive(:run_gcovr).once
      reportinator.send(:generate_reports_modern, { gcov_reports: ['HtmlBasic'] }, '--root x ', false)
    end
  end

  describe '#generate_reports_legacy' do
    let(:reportinator) { build_reportinator({}) }

    it 'invokes gcovr separately for HTML and Cobertura, each only when its args are non-empty' do
      allow(reportinator).to receive(:args_builder_html).and_return('')
      allow(reportinator).to receive(:args_builder_cobertura).and_return('--xml x ')
      expect(reportinator).to receive(:run_gcovr).once
      reportinator.send(:generate_reports_legacy, { gcov_reports: [] }, '', false)
    end
  end

  describe '#collect_gcovr_opts' do
    let(:reportinator) { build_reportinator({}) }

    it 'forces :report_exclude to [] (not nil) when a config file is in use' do
      result = reportinator.send(:collect_gcovr_opts, { gcov_gcovr: { config_file: 'gcovr.cfg' } })
      expect(result[:report_exclude]).to eq([])
    end

    it 'prepends user-supplied :report_exclude ahead of the generated exclusions' do
      result = reportinator.send(:collect_gcovr_opts, { gcov_gcovr: { report_exclude: 'user-pattern' } })
      expect(result[:report_exclude].first).to eq('user-pattern')
      expect(result[:report_exclude].length).to be > 1
    end

    it 'accepts an Array for user-supplied :report_exclude without nesting it' do
      result = reportinator.send(:collect_gcovr_opts, { gcov_gcovr: { report_exclude: ['a', 'b'] } })
      expect(result[:report_exclude][0..1]).to eq(['a', 'b'])
    end

    # Confirmed directly (Docker, gcovr 8.6): --decisions has zero effect on GCC's own
    # condition/MC-DC data in either JSON or HTML output -- byte-identical Condition
    # content with and without it, only an additive, separate Decision column changes.
    # collect_gcovr_opts has nothing :mcdc-specific to do; :gcov_mcdc never appears on
    # its returned opts at all.
    it 'never sets :mcdc on the returned opts, regardless of :gcov_mcdc' do
      with_mcdc    = reportinator.send(:collect_gcovr_opts, { gcov_gcovr: {}, gcov_mcdc: true })
      without_mcdc = reportinator.send(:collect_gcovr_opts, { gcov_gcovr: {}, gcov_mcdc: false })
      expect(with_mcdc).to_not have_key(:mcdc)
      expect(without_mcdc).to_not have_key(:mcdc)
    end
  end

  describe '#run_gcovr' do
    let(:reportinator) { build_reportinator({}) }

    it 'sets @summary only when :print_summary is enabled' do
      allow(tool_executor).to receive(:build_command_line).and_return({})
      allow(tool_executor).to receive(:exec).and_return({ exit_code: 0, time: 0.1, stdout: "lines: 90.0% (9 out of 10)\n", stderr: '' })

      reportinator.send(:run_gcovr, { print_summary: true, report_root: '.', report_exclude: [] }, '', false)
      expect(reportinator.summary).to include('90.0%')
    end

    it 'leaves @summary untouched when :print_summary is disabled' do
      allow(tool_executor).to receive(:build_command_line).and_return({})
      allow(tool_executor).to receive(:exec).and_return({ exit_code: 0, time: 0.1, stdout: "lines: 90.0% (9 out of 10)\n", stderr: '' })

      reportinator.send(:run_gcovr, { print_summary: false, report_root: '.', report_exclude: [] }, '', false)
      expect(reportinator.summary).to eq('')
    end

    it 'raises when gcovr_exec_exception? says the failure is real (its own CeedlingException, not the original ShellException)' do
      allow(tool_executor).to receive(:build_command_line).and_return({})
      shell_result = { exit_code: 2, time: 0.1, output: '', stdout: '', stderr: '' }
      allow(tool_executor).to receive(:exec)
        .and_raise(ShellException.new(name: 'gcovr', message: 'failed', shell_result: shell_result))

      # gcovr_exec_exception? itself raises (boom: true) before run_gcovr's own `raise(exception)`
      # line is ever reached -- the surfaced error is its CeedlingException, describing which
      # threshold failed, not a re-raise of the original ShellException.
      expect {
        reportinator.send(:run_gcovr, { fail_under_line: 90, report_root: '.', report_exclude: [] }, '', true)
      }.to raise_error(CeedlingException, /Line coverage/)
    end

    it 'swallows the ShellException and returns its shell_result when gcovr_exec_exception? says the exit code is fine' do
      allow(tool_executor).to receive(:build_command_line).and_return({})
      shell_result = { exit_code: 0, time: 0.1, output: '', stdout: '', stderr: '' }
      allow(tool_executor).to receive(:exec)
        .and_raise(ShellException.new(name: 'gcovr', message: 'failed', shell_result: shell_result))

      result = reportinator.send(:run_gcovr, { report_root: '.', report_exclude: [] }, '', true)
      expect(result).to eq(shell_result)
    end
  end

  describe '#extract_gcovr_error_message' do
    let(:reportinator) { build_reportinator({}) }

    it 'returns nil for a nil shell_result' do
      expect( reportinator.send(:extract_gcovr_error_message, nil) ).to be_nil
    end

    it 'returns nil when stderr is empty' do
      expect( reportinator.send(:extract_gcovr_error_message, { stderr: '' }) ).to be_nil
    end

    it 'captures, trims, and capitalizes an (ERROR)-prefixed line' do
      result = reportinator.send(:extract_gcovr_error_message, { stderr: "(ERROR) something went wrong.\n" })
      expect(result).to eq('Something went wrong.')
    end

    it 'matches case-insensitively' do
      result = reportinator.send(:extract_gcovr_error_message, { stderr: "error: lowercase message\n" })
      expect(result).to eq('Lowercase message')
    end

    it 'uses only the first matching line among several' do
      stderr = "(ERROR) first problem\n(ERROR) second problem\n"
      result = reportinator.send(:extract_gcovr_error_message, { stderr: stderr })
      expect(result).to eq('First problem')
    end

    it 'returns nil when no error-prefixed line exists' do
      result = reportinator.send(:extract_gcovr_error_message, { stderr: "just some noise\n" })
      expect(result).to be_nil
    end
  end

  describe '#extract_gcovr_summary' do
    let(:reportinator) { build_reportinator({}) }

    it 'returns an empty string for nil or empty output' do
      expect( reportinator.send(:extract_gcovr_summary, nil) ).to eq('')
      expect( reportinator.send(:extract_gcovr_summary, '') ).to eq('')
    end

    it 'returns an empty string when no line contains a percent sign' do
      expect( reportinator.send(:extract_gcovr_summary, "no percentages here\n") ).to eq('')
    end

    it 'extracts a single contiguous block of percent-containing lines' do
      output = "some header\nlines: 90.0% (9 out of 10)\nbranches: 80.0% (8 out of 10)\nfooter\n"
      result = reportinator.send(:extract_gcovr_summary, output)
      expect(result).to eq("lines: 90.0% (9 out of 10)\nbranches: 80.0% (8 out of 10)\n")
    end

    it 'returns only the last block when multiple separate percent blocks exist' do
      output = "lines: 10.0% (old)\n\nlines: 90.0% (9 out of 10)\nbranches: 80.0% (8 out of 10)\n"
      result = reportinator.send(:extract_gcovr_summary, output)
      expect(result).to eq("lines: 90.0% (9 out of 10)\nbranches: 80.0% (8 out of 10)\n")
      expect(result).to_not include('10.0%')
    end

    it 'does not underflow when the matching block reaches the very first line' do
      output = "lines: 90.0% (9 out of 10)\nbranches: 80.0% (8 out of 10)\n"
      result = reportinator.send(:extract_gcovr_summary, output)
      expect(result).to eq(output)
    end
  end

  describe '#generate_reports' do
    it 'dispatches to generate_reports_modern for gcovr >= 4.2' do
      reportinator = build_reportinator({}, gcovr_version: ToolVersion.new(8, 3))
      expect(reportinator).to receive(:generate_reports_modern)
      expect(reportinator).to_not receive(:generate_reports_legacy)
      reportinator.generate_reports({ gcov_gcovr: {}, gcov_reports: [] })
    end

    it 'dispatches to generate_reports_legacy below gcovr 4.2' do
      reportinator = build_reportinator({}, gcovr_version: ToolVersion.new(4, 1))
      expect(reportinator).to receive(:generate_reports_legacy)
      expect(reportinator).to_not receive(:generate_reports_modern)
      reportinator.generate_reports({ gcov_gcovr: {}, gcov_reports: [] })
    end

    it 'skips the text report when Text is not an enabled report type' do
      reportinator = build_reportinator({}, gcovr_version: ToolVersion.new(8, 3))
      allow(reportinator).to receive(:generate_reports_modern)
      expect(reportinator).to_not receive(:generate_text_report)
      reportinator.generate_reports({ gcov_gcovr: {}, gcov_reports: ['HtmlBasic'] })
    end

    it 'invokes the text report when Text is an enabled report type' do
      reportinator = build_reportinator({}, gcovr_version: ToolVersion.new(8, 3))
      allow(reportinator).to receive(:generate_reports_modern)
      expect(reportinator).to receive(:generate_text_report)
      reportinator.generate_reports({ gcov_gcovr: {}, gcov_reports: ['Text'] })
    end
  end
end
