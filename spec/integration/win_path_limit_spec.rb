# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# :project ↳ :win_path_limit set to :auto, with a real WinPathProber probing below a real
# directory. Windows only: elsewhere the setting is ignored.
#
# Hosted Windows runners ship with long paths enabled. Ruby 3.x there can write files past
# 260 characters but can't list directories that deep, so :auto keeps the classic limit and
# says why once. Ruby 4.0 lists them, so :auto lifts the limit and says nothing.

require 'spec_helper'
require 'tmpdir'
require 'tool_executor_integration_helper'
require 'ceedling/filesystem/file_wrapper'
require 'ceedling/system_wrapper'
require 'ceedling/constants'

describe 'Windows path limit (integration)', if: SystemWrapper.windows? do
  around(:each) do |example|
    Dir.mktmpdir { |dir| @root = File.realpath( dir ); example.run }
  end

  before(:each) do
    @loginator = double( 'loginator' )
    @logged    = []
    allow(@loginator).to receive(:log) { |message, verbosity = nil, label = nil| @logged << [message, verbosity, label] }

    @file_wrapper = FileWrapper.new( { loginator: @loginator, verbosinator: double( 'verbosinator', should_output?: false ) } )
    @file_wrapper.configure_win_path_limit( mode: :auto, prober: real_win_path_prober( build_root: @root, loginator: @loginator ) )
  end

  def shown
    return @logged.reject { |_message, verbosity, _label| verbosity == Verbosity::DEBUG }
  end

  it 'reports a 300-character path as this Ruby can work with it' do
    path = File.join( @root, 'p' * (300 - @root.length - 1) )
    @file_wrapper.check_path_length( path, origin: 'Test' )

    if Gem::Version.new( RUBY_VERSION ) >= Gem::Version.new( '4.0' )
      expect(shown).to be_empty
    else
      expect(shown.map { |_message, verbosity, label| [verbosity, label] }).to eq( [[Verbosity::NORMAL, LogLabels::NOTICE], [Verbosity::ERRORS, nil]] )
      expect(shown.first.first).to include( 'cannot list directories past 260 characters' )
    end

    expect(Dir.children( @root )).to be_empty
  end
end
