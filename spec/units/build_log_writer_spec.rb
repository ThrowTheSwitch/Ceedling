# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'tmpdir'
require 'ceedling/build_log_writer'
require 'ceedling/file_wrapper'

describe BuildLogWriter do
  let(:file_wrapper) { double('file_wrapper') }
  let(:writer)       { described_class.new( file_wrapper: file_wrapper ) }

  before(:each) do
    allow(file_wrapper).to receive(:mkdir_for) { |path| path }
    allow(file_wrapper).to receive(:write)
  end

  it "replaces an earlier build's log with this build's first entry" do
    writer.write( 'logs/test/test/test_foo/test_a.gdb.log', "first\n" )

    expect(file_wrapper).to have_received(:mkdir_for).with( 'logs/test/test/test_foo/test_a.gdb.log' )
    expect(file_wrapper).to have_received(:write).with( 'logs/test/test/test_foo/test_a.gdb.log', "first\n", 'w' )
  end

  it 'appends later entries in the same build, after the separator' do
    writer.write( 'a.log', 'one', separator: "\n" )
    writer.write( 'a.log', 'two', separator: "\n" )

    expect(file_wrapper).to have_received(:write).with( 'a.log', 'one', 'w' ).ordered
    expect(file_wrapper).to have_received(:write).with( 'a.log', "\ntwo", 'a' ).ordered
  end

  it 'replaces each log separately' do
    writer.write( 'a.log', 'one' )
    writer.write( 'b.log', 'two' )

    expect(file_wrapper).to have_received(:write).with( 'a.log', 'one', 'w' )
    expect(file_wrapper).to have_received(:write).with( 'b.log', 'two', 'w' )
  end

  it 'keeps every entry when build threads write one log at once' do
    Dir.mktmpdir do |dir|
      loginator = double( 'loginator', log: nil )
      real      = described_class.new( file_wrapper: FileWrapper.new( loginator: loginator, verbosinator: double( 'verbosinator', should_output?: false ) ) )
      log       = File.join( dir, 'test', 'unit', 'test_foo.log' )

      threads = Array.new( 8 ) { |index| Thread.new { real.write( log, "entry #{index}\n" ) } }
      threads.each( &:join )

      expect( File.readlines( log ).map( &:chomp ) ).to match_array( Array.new( 8 ) { |index| "entry #{index}" } )
    end
  end
end
