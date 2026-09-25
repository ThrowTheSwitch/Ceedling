# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Shared rigging for ToolExecutor's integration spec tier.
#
# Wires the real ToolExecutor + ToolExecutorHelper + SystemWrapper + SystemUtils +
# Loginator + Verbosinator + RubyExpandinator graph -- no stand-in for ToolExecutor
# itself, unlike IntegrationSpecHelpers::ShellingToolExecutor (spec_integration_helper.rb),
# which exists precisely because ToolExecutor was untested at that tier. This graph
# genuinely shells out through SystemWrapper#shell_capture3 (Open3.capture3) for real.

require 'rbconfig'

require 'ceedling/tool_executor'
require 'ceedling/tool_executor_helper'
require 'ceedling/system_wrapper'
require 'ceedling/system_utils'
require 'ceedling/loginator'
require 'ceedling/verbosinator'
require 'ceedling/ruby_expandinator'

module ToolExecutorIntegrationHelpers
  # Builds the real collaborator graph. Verbosity stays at the default (NORMAL) so
  # nothing here needs OBNOXIOUS-level logging silenced or asserted on.
  def real_tool_executor
    system_wrapper = SystemWrapper.new
    verbosinator    = Verbosinator.new
    loginator       = Loginator.new(verbosinator: verbosinator, system_wrapper: system_wrapper)
    system_utils    = SystemUtils.new(system_wrapper: system_wrapper)
    helper = ToolExecutorHelper.new(
      loginator: loginator, system_utils: system_utils,
      system_wrapper: system_wrapper, verbosinator: verbosinator
    )
    ToolExecutor.new(
      tool_executor_helper: helper, loginator: loginator,
      verbosinator: verbosinator, system_wrapper: system_wrapper,
      ruby_expandinator: RubyExpandinator.new
    )
  end

  # A tool definition whose executable is the same Ruby running this test suite --
  # genuinely cross-platform-safe (available on every CI platform) unlike assuming
  # gcc/POSIX shell builtins behave identically on Linux/Windows/macOS.
  def ruby_tool_config(name: 'ruby_probe', arguments: [])
    { name: name, executable: RbConfig.ruby, arguments: arguments }
  end
end

RSpec.configure do |config|
  config.include ToolExecutorIntegrationHelpers
end
