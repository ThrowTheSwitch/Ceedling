# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Integration coverage for QuoteIncludeIsolator, which stages a copy of a file alone in a
# fresh directory.
#
# A quote-include (`#include "..."`) always checks its own file's directory before
# consulting any -I search path. Staging a copy with nothing else beside it forces that
# lookup through -I instead, which is how a mock or a Partial reaches a compile whose
# real header sits next to the file including it.
#
# The directory this creates, the bytes it copies, and what a compiler makes of a staged
# copy are filesystem and toolchain facts. A doubled file layer records only that a copy
# was requested, so a real FileWrapper runs against a real temp directory here. The unit
# spec at spec/units/quote_include_isolator_spec.rb owns everything observable through
# injected doubles alone.

require 'spec_helper'
require 'spec_integration_helper'
require 'fileutils'
require 'tmpdir'
require 'open3'
require 'ceedling/file_wrapper'
require 'ceedling/quote_include_isolator'
require 'ceedling/constants'

describe 'QuoteIncludeIsolator (integration)' do
  before(:each) do
    @loginator    = double('loginator')
    @verbosinator = double('verbosinator')
    allow(@loginator).to receive(:log)
    allow(@verbosinator).to receive(:should_output?).and_return(false)

    file_wrapper = FileWrapper.new({ :loginator => @loginator, :verbosinator => @verbosinator })
    @isolator    = QuoteIncludeIsolator.new({ :file_wrapper => file_wrapper, :loginator => @loginator })

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
    isolation = @isolator.isolate( parent: @parent, files: [@source_a] )

    expect( File.directory?( isolation.dir ) ).to be true
    expect( isolation.dir ).to start_with( @parent )
  end

  # Named by basename alone, since the point is a directory holding nothing but these
  # files. A nested source and a flat one land side by side.
  it 'copies every given file into that directory, named by basename alone' do
    isolation = @isolator.isolate( parent: @parent, files: [@source_a, @source_b] )

    expect( File.read( File.join( isolation.dir, 'source_a.h' ), encoding: 'UTF-8' ) ).to eq( 'a' )
    expect( File.read( isolation.copy_of( @source_b ), encoding: 'UTF-8' ) ).to eq( 'b' )
  end

  it 'stages nothing but an empty directory when given no files' do
    isolation = @isolator.isolate( parent: @parent, files: [] )

    expect( Dir.children( isolation.dir ) ).to eq( [] )
  end

  it 'removes the staged directory when the block of #within ends' do
    dir = nil
    @isolator.within( parent: @parent, files: [@source_a] ) { |isolation| dir = isolation.dir }

    expect( File.directory?( dir ) ).to be false
  end

  # Every byte after the #line directive is the original's, line endings included.
  it 'writes a location-preserving copy as the #line directive followed by the original bytes' do
    original = File.join( @parent, 'crlf.c' )
    File.binwrite( original, "int a;\r\nint b;\r\n" )

    isolation = @isolator.isolate( parent: @parent, files: [original], preserve_location: true )

    expect( File.binread( isolation.copy_of( original ) ) ).to eq( "#line 1 \"#{original}\"\nint a;\r\nint b;\r\n".b )
  end

  it 'rewrites a real dependency file so it names the original' do
    original  = File.join( @parent, 'gpio.c' )
    File.write( original, '' )
    isolation = @isolator.isolate( parent: @parent, files: [original] )
    deps      = File.join( @parent, 'gpio.d' )
    File.write( deps, "gpio.o: #{isolation.copy_of( original )} gpio.h\n" )

    @isolator.restore_dependencies( isolation, deps )

    expect( File.read( deps ) ).to eq( "gpio.o: #{original} gpio.h\n" )
  end

  # The end-to-end claim the isolator exists for: a real compiler, handed a
  # location-preserving copy, reaches the header first on the search path rather than the
  # real one beside the original, yet reports the original file throughout.
  context 'compiling a location-preserving copy with a real gcc' do
    include_context 'requires gcc'

    def compile(tree)
      with_source_tree(tree) do |dir|
        source    = File.join( dir, 'src', 'gpio.c' )
        object    = File.join( dir, 'gpio.o' )
        deps      = File.join( dir, 'gpio.d' )
        program   = File.join( dir, 'gpio' )
        isolation = @isolator.isolate( parent: dir, files: [source], preserve_location: true )

        search = ['-I', File.join( dir, 'shadow' ), '-I', File.join( dir, 'src' )]
        _, status = Open3.capture2e( 'gcc', *search, '-MMD', '-MF', deps, '-c', isolation.copy_of( source ), '-o', object )
        raise 'compile failed' unless status.success?

        @isolator.restore_dependencies( isolation, deps )
        Open3.capture2e( 'gcc', object, '-o', program )
        run, = Open3.capture2e( program )

        @isolator.release( isolation.dir )
        yield source, run, File.read( deps ), isolation.dir
      end
    end

    let(:tree) do
      {
        'src/gpio.c'    => %(#include <stdio.h>\n#include "board.h"\n#include "gpio.h"\n) +
                           %(int main(void) { printf("%s %d %d\\n", __FILE__, BOARD, GPIO); return 0; }\n),
        'src/board.h'   => %(#define BOARD 1\n),
        'src/gpio.h'    => %(#define GPIO 7\n),
        'shadow/board.h' => %(#define BOARD 2\n)
      }
    end

    it 'reaches the header first on the search path instead of the one beside the original' do
      compile( tree ) do |_, run|
        expect( run.split[1] ).to eq( '2' )
      end
    end

    it 'still resolves the original directory through the search path appended last' do
      compile( tree ) do |_, run|
        expect( run.split[2] ).to eq( '7' )
      end
    end

    it 'reports the original file as __FILE__' do
      compile( tree ) do |source, run|
        expect( run.split[0] ).to eq( source )
      end
    end

    it 'leaves the restored dependency file naming the original, never the copy' do
      compile( tree ) do |source, _, deps, staged_dir|
        expect( deps ).to include( source )
        expect( deps ).to_not include( staged_dir )
      end
    end
  end
end
