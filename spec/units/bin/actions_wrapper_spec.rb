# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'tmpdir'
require 'actions_wrapper'

# ActionsWrapper is a thin pass-through onto Thor::Actions -- these specs confirm
# the wrapper methods forward to real Thor behavior against a real filesystem
# rather than re-testing Thor itself.
describe ActionsWrapper do
  before(:each) do
    @actions = described_class.new
  end

  around(:each) do |example|
    Dir.mktmpdir do |dir|
      @tmpdir = dir
      described_class.source_root( dir )
      example.run
    end
  end

  describe '#_directory' do
    it 'copies a source directory to a destination, excluding junk files' do
      src = File.join( @tmpdir, 'src_dir' )
      FileUtils.mkdir_p( src )
      File.write( File.join( src, 'keep.txt' ), 'keep me' )
      File.write( File.join( src, '.DS_Store' ), 'junk' )

      dest = File.join( @tmpdir, 'dest_dir' )
      @actions._directory( 'src_dir', dest, :force => true, :verbose => false )

      expect(File.exist?( File.join( dest, 'keep.txt' ) )).to eq( true )
      expect(File.exist?( File.join( dest, '.DS_Store' ) )).to eq( false )
    end
  end

  describe '#_copy_file' do
    it 'copies a single file to a destination' do
      File.write( File.join( @tmpdir, 'source.txt' ), 'hello' )

      dest = File.join( @tmpdir, 'copy.txt' )
      @actions._copy_file( 'source.txt', dest, :force => true, :verbose => false )

      expect(File.read( dest )).to eq( 'hello' )
    end
  end

  describe '#_touch_file' do
    it 'creates an empty file if none exists' do
      dest = File.join( @tmpdir, 'touched.txt' )

      @actions._touch_file( dest )

      expect(File.exist?( dest )).to eq( true )
    end
  end

  describe '#_chmod' do
    it 'sets file permissions', skip: (RUBY_PLATFORM.downcase =~ /mingw|win32/ ? 'chmod is not meaningful on Windows' : false) do
      dest = File.join( @tmpdir, 'executable.txt' )
      File.write( dest, 'content' )

      @actions._chmod( dest, 0755, :verbose => false )

      expect(File.stat( dest ).mode & 0777).to eq( 0755 )
    end
  end

  describe '#_empty_directory' do
    it 'creates an empty directory' do
      dest = File.join( @tmpdir, 'empty_dir' )

      @actions._empty_directory( dest, :verbose => false )

      expect(File.directory?( dest )).to eq( true )
    end
  end

  describe '#_gsub_file' do
    it 'substitutes matched text in a file' do
      target = File.join( @tmpdir, 'target.txt' )
      File.write( target, "version: '?'\n" )

      @actions._gsub_file( target, /version:\s+'\?'/, "version: '1.0.0'", :verbose => false )

      expect(File.read( target )).to eq( "version: '1.0.0'\n" )
    end
  end
end
