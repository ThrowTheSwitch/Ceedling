# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/constants'
require 'ceedling/exceptions'
require 'ceedling/plugins/plugin'
require 'ceedling/path_mirror'

PROJECT_BUILD_ROOT           = 'build'     unless defined?(PROJECT_BUILD_ROOT)
PROJECT_BUILD_ARTIFACTS_ROOT = 'artifacts' unless defined?(PROJECT_BUILD_ARTIFACTS_ROOT)

$: << File.expand_path('../../../../plugins/gcov/lib', __FILE__)

require 'gcov_constants'
require 'gcov_types'
require 'gcov_reportinator'
require 'console_reportinator'
require 'gcovr_reportinator'
require 'reportgenerator_reportinator'
require 'gcov'

TOOLS_GCOV_GCC_VERSION = { name: 'gcov_gcc_version' }.freeze unless defined?(TOOLS_GCOV_GCC_VERSION)

# Scoped narrowly to the :mcdc/GCC-version check this pass moved out of setup()
# (finding A.2) -- not full Gcov coverage. Bypasses Plugin#initialize (which
# would run the real setup(), pulling in far more than this check needs) via
# .allocate, setting only the instance variables validate_mcdc_gcc_version!
# and get_gcc_version touch.
describe Gcov do
  let(:loginator)        { double('loginator', log: nil, lazy: nil) }
  let(:reportinator_obj) { double('reportinator', generate_progress: '') }
  let(:tool_executor)    { double('tool_executor') }

  def build_gcov(project_config)
    instance = Gcov.allocate
    instance.instance_variable_set(:@project_config, project_config)
    instance.instance_variable_set(:@loginator, loginator)
    instance.instance_variable_set(:@reportinator, reportinator_obj)
    instance.instance_variable_set(:@tool_executor, tool_executor)
    instance.instance_variable_set(:@mcdc_gcc_checked, false)
    instance
  end

  describe '#validate_mcdc_gcc_version!' do
    it 'never shells out to gcc when :mcdc is not configured' do
      gcov = build_gcov({ gcov_mcdc: false })
      expect(tool_executor).to_not receive(:build_command_line)
      gcov.send(:validate_mcdc_gcc_version!)
    end

    it 'raises CeedlingException when :mcdc is configured against GCC older than 14' do
      gcov = build_gcov({ gcov_mcdc: true })
      allow(tool_executor).to receive(:build_command_line).and_return({})
      allow(tool_executor).to receive(:exec).and_return({ output: "gcc (Ubuntu) 13.2.0\n" })

      expect {
        gcov.send(:validate_mcdc_gcc_version!)
      }.to raise_error(CeedlingException, /:mcdc.*requires GCC 14\.0 or higher \(found 13\.2\)/)
    end

    it 'does not raise when :mcdc is configured against GCC 14+' do
      gcov = build_gcov({ gcov_mcdc: true })
      allow(tool_executor).to receive(:build_command_line).and_return({})
      allow(tool_executor).to receive(:exec).and_return({ output: "gcc (Ubuntu) 14.2.0\n" })

      expect { gcov.send(:validate_mcdc_gcc_version!) }.to_not raise_error
    end

    it 'checks gcc --version at most once even when called repeatedly' do
      gcov = build_gcov({ gcov_mcdc: true })
      allow(tool_executor).to receive(:build_command_line).and_return({})
      expect(tool_executor).to receive(:exec).once.and_return({ output: "gcc (Ubuntu) 14.2.0\n" })

      3.times { gcov.send(:validate_mcdc_gcc_version!) }
    end
  end
end
