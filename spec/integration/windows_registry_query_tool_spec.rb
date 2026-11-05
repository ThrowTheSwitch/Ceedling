# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# The default Windows registry query tool, run for real through ToolExecutor. Windows
# only. spec/units/windows_registry_query_tool_spec.rb checks the command it builds
# on every OS.
#
# Hosted Windows runners ship with long paths enabled.

require 'spec_helper'
require 'tool_executor_integration_helper'
require 'ceedling/filesystem/win_long_paths'
require 'ceedling/system_wrapper'

describe 'Windows registry query tool (integration)', if: SystemWrapper.windows? do
  let(:prober) { real_win_path_prober( build_root: Dir.pwd, loginator: double( 'loginator' ).as_null_object ) }

  it 'reads LongPathsEnabled as enabled on a hosted Windows runner' do
    expect(WinLongPaths.registry_enabled?( query: prober.method( :registry_query ) )).to be true
  end

  it 'returns reg query\'s own output with a successful status' do
    output, success = prober.registry_query

    expect(success).to be true
    expect(output).to match( WinLongPaths::ENABLED )
  end

  it 'reports a value that does not exist as a failed query, without raising' do
    executor = real_tool_executor
    tool     = Marshal.load( Marshal.dump( DEFAULT_WINDOWS_REGISTRY_QUERY_TOOL ) )
    command  = executor.build_command_line( tool, [], WinLongPaths::REGISTRY_KEY, 'CeedlingNoSuchValue' )
    command[:options][:boom] = false

    expect(executor.failed?( executor.exec( command ) )).to be true
  end
end
