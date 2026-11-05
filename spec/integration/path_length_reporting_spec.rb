# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# A build file is created, opened, written, and replaced through separate FileWrapper
# calls, each of which checks its path's length. A path near the platform's limit is
# reported once, however many of them touch it.
#
# The path is sized to sit just inside this platform's warning band, below its limit, so
# every operation succeeds on the real disk.

require 'spec_helper'
require 'tmpdir'
require 'ceedling/filesystem/file_wrapper'
require 'ceedling/system_wrapper'

describe 'Path length reporting (integration)' do
  around(:each) do |example|
    Dir.mktmpdir { |dir| @root = File.realpath( dir ); example.run }
  end

  before(:each) do
    @loginator    = double( 'loginator' )
    @verbosinator = double( 'verbosinator', should_output?: false )
    @messages     = []
    allow(@loginator).to receive(:log) { |message, *| @messages << message }

    @file_wrapper = FileWrapper.new( { loginator: @loginator, verbosinator: @verbosinator } )
  end

  def limit
    return FileWrapper::PATH_LENGTH_LIMITS[:windows] if SystemWrapper.windows?
    return FileWrapper::PATH_LENGTH_LIMITS[:macos] if SystemWrapper.macos?

    return FileWrapper::PATH_LENGTH_LIMITS[:linux]
  end

  # A directory below the warning band, and a file in it inside the band
  def paths
    directory = @root
    directory = File.join( directory, 'd' * [limit - 40 - directory.length - 1, 100].min ) while directory.length < limit - 40

    file = File.join( directory, 'f' * (limit - 10 - directory.length - 1) )
    return [directory, file]
  end

  it 'reports a path in the warning band once across mkdir, open, write, and cp' do
    directory, file = paths
    source = File.join( @root, 'source.c' )
    File.write( source, 'int x;' )

    @file_wrapper.mkdir( directory )
    @file_wrapper.open( file, 'w' ) { |f| f.write( 'int x;' ) }
    @file_wrapper.write( file, 'int y;' )
    @file_wrapper.cp( source, file )

    expect(File.read( file )).to eq( 'int x;' )
    expect(@messages.length).to eq( 1 )
    expect(@messages.first).to include( file )
  end
end
