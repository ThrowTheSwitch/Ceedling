# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/defaults'
require 'ceedling/tool_executor'
require 'ceedling/ruby_expandinator'
require 'ceedling/filesystem/win_long_paths'

# The default tool the long path probe reads the Windows registry with. Commands are built
# by a real ToolExecutor and never run, so this runs on every OS.
# spec/integration/windows_registry_query_tool_spec.rb runs it on Windows.
describe 'Default Windows registry query tool' do
  before(:each) do
    helper = double('tool_executor_helper').as_null_object
    allow(helper).to receive(:osify_path_separators) { |path| path }
    system_wrapper = double('system_wrapper').as_null_object
    allow(system_wrapper).to receive(:constants_include?).and_return( false )

    @tool_executor = ToolExecutor.new(
      {
        :tool_executor_helper => helper,
        :loginator            => double('loginator').as_null_object,
        :verbosinator         => double('verbosinator').as_null_object,
        :system_wrapper       => system_wrapper,
        :ruby_expandinator    => RubyExpandinator.new
      }
    )
  end

  # Configuration hands Ceedling an unfrozen copy of each default tool
  def tool
    return Marshal.load( Marshal.dump( DEFAULT_WINDOWS_REGISTRY_QUERY_TOOL ) )
  end

  it 'is optional, so a missing reg.exe never stops a build' do
    expect( DEFAULT_WINDOWS_REGISTRY_QUERY_TOOL[:optional] ).to be true
  end

  it 'queries one value below one key, its backslashes intact' do
    line = @tool_executor.build_command_line( tool, [], WinLongPaths::REGISTRY_KEY, WinLongPaths::REGISTRY_VALUE )[:line]

    expect( line ).to eq( "#{FilePathUtils.os_executable_ext( 'reg' )} query \"HKLM\\SYSTEM\\CurrentControlSet\\Control\\FileSystem\" /v LongPathsEnabled" )
  end

  it 'is named for its log lines and errors' do
    expect( @tool_executor.build_command_line( tool, [], 'HKLM\\X', 'Y' )[:name] ).to eq( 'default_windows_registry_query' )
  end
end
