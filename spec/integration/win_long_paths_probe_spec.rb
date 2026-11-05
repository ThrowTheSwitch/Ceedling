# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# The Windows long path probe against the real disk, reading the registry through the
# default Windows registry query tool and the real ToolExecutor.
#
# Hosted Windows runners ship with long paths enabled, and every RubyInstaller Ruby is
# long-path-aware. Ruby 3.x there writes and reads files past 260 characters, but can't
# list directories that deep; Ruby 4.0 can. macOS and Linux have no 260-character limit.

require 'spec_helper'
require 'tmpdir'
require 'tool_executor_integration_helper'
require 'ceedling/filesystem/win_long_paths'
require 'ceedling/system_wrapper'

describe 'Windows long path probe (integration)' do
  around(:each) do |example|
    Dir.mktmpdir { |dir| @root = dir; example.run }
  end

  def probe
    prober = real_win_path_prober( build_root: @root, loginator: double( 'loginator' ).as_null_object )
    return WinLongPaths.probe( @root, query: prober.method( :registry_query ) )
  end

  def expected_support
    return :full unless SystemWrapper.windows?

    return Gem::Version.new( RUBY_VERSION ) >= Gem::Version.new( '4.0' ) ? :full : :files_only
  end

  it 'reports what this host and Ruby support past 260 characters' do
    expect(probe[:support]).to eq( expected_support )
  end

  it 'leaves nothing behind' do
    probe

    expect(Dir.children( @root )).to be_empty
  end
end
