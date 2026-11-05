# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# The Windows long path probe against the real disk and the real `reg query`.
#
# Hosted Windows runners ship with long paths enabled, and every RubyInstaller Ruby is
# long-path-aware. Ruby 3.x there writes and reads files past 260 characters, but can't
# list directories that deep; Ruby 4.0 can. macOS and Linux have no 260-character limit.

require 'spec_helper'
require 'tmpdir'
require 'ceedling/filesystem/win_long_paths'
require 'ceedling/system_wrapper'

describe 'Windows long path probe (integration)' do
  around(:each) do |example|
    Dir.mktmpdir { |dir| @root = dir; example.run }
  end

  def expected_support
    return :full unless SystemWrapper.windows?

    return Gem::Version.new( RUBY_VERSION ) >= Gem::Version.new( '4.0' ) ? :full : :files_only
  end

  it 'reports what this host and Ruby support past 260 characters' do
    expect(WinLongPaths.probe( @root )[:support]).to eq( expected_support )
  end

  it 'leaves nothing behind' do
    WinLongPaths.probe( @root )

    expect(Dir.children( @root )).to be_empty
  end

  it 'reads the registry as enabled on a hosted Windows runner', if: SystemWrapper.windows? do
    expect(WinLongPaths.registry_enabled?).to be true
  end
end
