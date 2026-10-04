# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Integration coverage for FileWrapper#stage_isolated_copies, which stages a copy of
# a file alone in a fresh directory.
#
# A quote-include (`#include "..."`) always checks its own file's directory before
# consulting any -I search path. Staging a copy with nothing else beside it is what
# forces that lookup through -I instead, which is how a mock or a Partial reaches the
# compilation of a test whose real header sits next to the file including it.
#
# The directory this creates, the bytes it copies, and the emptiness of an unstaged
# directory are all filesystem facts. A doubled file layer records that a copy was
# requested; only a real one proves a later compile would find what it needs. So a real
# FileWrapper runs against a real temp directory here, and this belongs at integration
# tier rather than among FileWrapper's unit examples, which touch no filesystem.
#
# The unit spec at spec/units/file_wrapper_spec.rb owns everything observable through
# injected doubles alone.

require 'spec_helper'
require 'fileutils'
require 'tmpdir'
require 'ceedling/file_wrapper'
require 'ceedling/constants'

describe 'FileWrapper isolated copies (integration)' do
  before(:each) do
    @loginator    = double('loginator')
    @verbosinator = double('verbosinator')
    allow(@loginator).to receive(:log)
    allow(@verbosinator).to receive(:should_output?).and_return(false)

    @file_wrapper = FileWrapper.new({
      :loginator    => @loginator,
      :verbosinator => @verbosinator
    })

    @parent   = Dir.mktmpdir
    @source_a = File.join( @parent, 'source_a.h' )
    @source_b = File.join( @parent, 'nested', 'source_b.h' )

    FileUtils.mkdir_p( File.dirname( @source_b ) )
    File.write( @source_a, 'a' )
    File.write( @source_b, 'b' )
  end

  after(:each) do
    FileUtils.rm_rf( @parent )
  end

  it 'creates a new directory nested inside parent' do
    isolation_dir = @file_wrapper.stage_isolated_copies( parent: @parent, files: [@source_a] )

    expect( File.directory?( isolation_dir ) ).to be true
    expect( isolation_dir ).to start_with( @parent )
  end

  # Named by basename alone, since the point is a directory holding nothing but these
  # files -- a nested source and a flat one land side by side.
  it 'copies every given file into that directory, named by basename alone' do
    isolation_dir = @file_wrapper.stage_isolated_copies( parent: @parent, files: [@source_a, @source_b] )

    expect( File.read( File.join( isolation_dir, 'source_a.h' ), encoding: 'UTF-8' ) ).to eq( 'a' )
    expect( File.read( File.join( isolation_dir, 'source_b.h' ), encoding: 'UTF-8' ) ).to eq( 'b' )
  end

  it 'stages nothing but an empty directory when given no files' do
    isolation_dir = @file_wrapper.stage_isolated_copies( parent: @parent, files: [] )

    expect( Dir.children( isolation_dir ) ).to eq( [] )
  end

  it 'logs each staged copy at DEBUG verbosity' do
    @file_wrapper.stage_isolated_copies( parent: @parent, files: [@source_a] )

    expect(@loginator).to have_received(:log).with(
      a_string_including( @source_a ), Verbosity::DEBUG
    )
  end
end
