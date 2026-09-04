# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/constants'
require 'ceedling/exceptions'

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
end
