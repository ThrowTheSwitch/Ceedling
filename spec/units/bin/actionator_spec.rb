# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'actionator'

# Actionator reaches the filesystem only through FileWrapper and stdout only
# through Loginator. Both are injected, so these examples assert entirely on the
# messages sent to those two doubles. Real filesystem behavior lives in
# spec/integration/actionator_file_operations_spec.rb.
describe Actionator do
  # Actionator resolves both roots through File.expand_path, and Windows expands a
  # bare '/foo' by prepending the current drive letter. Every root and expected path
  # is therefore derived the same way rather than written as a POSIX literal, so the
  # arithmetic that shortens a path against the destination root lines up on every
  # platform.
  def src_path(*parts)
    return File.join( File.expand_path( '/src' ), *parts )
  end

  def dest_path(*parts)
    return File.join( File.expand_path( '/dest' ), *parts )
  end

  before(:each) do
    @file_wrapper = double('file_wrapper')
    @loginator    = double('loginator')

    # setup() captures destination_root from FileWrapper, so this stub has to be in
    # place before construction. A null-object double would hand back a double here
    # and every relative-path assertion below would compare against garbage.
    allow(@file_wrapper).to receive(:get_expanded_path).with('.').and_return( dest_path )

    # Color off unless an example opts in, so status-line assertions stay readable.
    allow(@loginator).to receive(:decorators).and_return(false)
    allow(@loginator).to receive(:console)

    @actionator = described_class.new({
      :file_wrapper => @file_wrapper,
      :loginator    => @loginator
    })

    @actionator.source_root = src_path
  end

  # Most examples copy a file that does not yet exist at its destination.
  def expect_absent_destination(path)
    allow(@file_wrapper).to receive(:exist?).with( src_path('asset.txt') ).and_return( true )
    allow(@file_wrapper).to receive(:exist?).with( path ).and_return( false )
    allow(@file_wrapper).to receive(:read_binary).with( src_path('asset.txt') ).and_return( 'contents' )
    allow(@file_wrapper).to receive(:dirname).with( path ).and_return( File.dirname(path) )
    allow(@file_wrapper).to receive(:mkdir)
    allow(@file_wrapper).to receive(:write)
  end

  describe '#copy_file' do
    it 'creates an absent destination, writes in binary mode, and reports a relative path' do
      expect_absent_destination( dest_path('sub', 'asset.txt') )

      expect(@file_wrapper).to receive(:mkdir).with( dest_path('sub') )
      expect(@file_wrapper).to receive(:write).with( dest_path('sub', 'asset.txt'), 'contents', 'wb' )
      expect(@loginator).to receive(:console).with( '      create  sub/asset.txt', LogLabels::NONE )

      @actionator.copy_file( 'asset.txt', 'sub/asset.txt' )
    end

    it 'reports an existing byte-identical destination as identical and does not write' do
      allow(@file_wrapper).to receive(:exist?).and_return( true )
      allow(@file_wrapper).to receive(:compare).with( src_path('asset.txt'), dest_path('sub', 'asset.txt') ).and_return( true )

      expect(@file_wrapper).to_not receive(:write)
      expect(@loginator).to receive(:console).with( '   identical  sub/asset.txt', LogLabels::NONE )

      @actionator.copy_file( 'asset.txt', 'sub/asset.txt' )
    end

    it 'overwrites a differing destination when forced' do
      allow(@file_wrapper).to receive(:exist?).and_return( true )
      allow(@file_wrapper).to receive(:compare).and_return( false )
      allow(@file_wrapper).to receive(:read_binary).and_return( 'contents' )
      allow(@file_wrapper).to receive(:dirname).and_return( dest_path('sub') )
      allow(@file_wrapper).to receive(:mkdir)

      expect(@file_wrapper).to receive(:write).with( dest_path('sub', 'asset.txt'), 'contents', 'wb' )
      expect(@loginator).to receive(:console).with( '       force  sub/asset.txt', LogLabels::NONE )

      @actionator.copy_file( 'asset.txt', 'sub/asset.txt', force: true )
    end

    # Every Ceedling call site passes force, so reaching this is a programming error
    # rather than a user-facing condition. Thor prompted on stdin here, which would
    # hang a build.
    it 'raises rather than prompting when a differing destination is not forced' do
      allow(@file_wrapper).to receive(:exist?).and_return( true )
      allow(@file_wrapper).to receive(:compare).and_return( false )

      expect(@file_wrapper).to_not receive(:write)

      expect {
        @actionator.copy_file( 'asset.txt', 'sub/asset.txt' )
      }.to raise_error( CeedlingException, /sub\/asset\.txt/ )
    end

    it 'prints no status line when verbose is false' do
      expect_absent_destination( dest_path('sub', 'asset.txt') )

      expect(@loginator).to_not receive(:console)

      @actionator.copy_file( 'asset.txt', 'sub/asset.txt', verbose: false )
    end

    it 'resolves a relative source against the source root' do
      expect_absent_destination( dest_path('copy.txt') )

      expect(@file_wrapper).to receive(:read_binary).with( src_path('asset.txt') )

      @actionator.copy_file( 'asset.txt', 'copy.txt' )
    end

    # cli_helper.rb hands over absolute paths for gathered docs and license files
    # while cli_handler.rb hands over paths relative to the Ceedling install.
    it 'leaves an absolute source untouched' do
      absolute_source = File.expand_path( '/elsewhere/asset.txt' )

      allow(@file_wrapper).to receive(:exist?).with( absolute_source ).and_return( true )
      allow(@file_wrapper).to receive(:exist?).with( dest_path('copy.txt') ).and_return( false )
      allow(@file_wrapper).to receive(:dirname).and_return( dest_path )
      allow(@file_wrapper).to receive(:mkdir)
      allow(@file_wrapper).to receive(:write)

      expect(@file_wrapper).to receive(:read_binary).with( absolute_source ).and_return( 'contents' )

      @actionator.copy_file( absolute_source, 'copy.txt' )
    end

    it 'raises naming both the source and the search root when the source is missing' do
      allow(@file_wrapper).to receive(:exist?).and_return( false )

      expect {
        @actionator.copy_file( 'nope.txt', 'copy.txt' )
      }.to raise_error( CeedlingException, /nope\.txt/ )
    end

    it 'names the search root in that same failure, so the user learns where it looked' do
      allow(@file_wrapper).to receive(:exist?).and_return( false )

      expect {
        @actionator.copy_file( 'nope.txt', 'copy.txt' )
      }.to raise_error( CeedlingException, /#{Regexp.escape( src_path )}/ )
    end
  end

  describe 'status line colorization' do
    # Bold, then color, then reset -- and the reset lands before the two-space
    # gutter so only the verb is colored, matching what Thor::Actions emitted.
    {
      :create    => "\e[32m",
      :identical => "\e[34m",
      :force     => "\e[33m",
    }.each_pair do |verb, sgr|
      it "wraps #{verb} in bold plus its own color when decorators are enabled on a tty" do
        allow(@loginator).to receive(:decorators).and_return( true )
        allow($stdout).to receive(:tty?).and_return( true )

        case verb
        when :create
          expect_absent_destination( dest_path('sub', 'asset.txt') )
          force = false
        when :identical
          allow(@file_wrapper).to receive(:exist?).and_return( true )
          allow(@file_wrapper).to receive(:compare).and_return( true )
          force = false
        when :force
          allow(@file_wrapper).to receive(:exist?).and_return( true )
          allow(@file_wrapper).to receive(:compare).and_return( false )
          allow(@file_wrapper).to receive(:read_binary).and_return( 'contents' )
          allow(@file_wrapper).to receive(:dirname).and_return( dest_path('sub') )
          allow(@file_wrapper).to receive(:mkdir)
          allow(@file_wrapper).to receive(:write)
          force = true
        end

        expected = "\e[1m#{sgr}#{verb.to_s.rjust(12)}\e[0m  sub/asset.txt"
        expect(@loginator).to receive(:console).with( expected, LogLabels::NONE )

        @actionator.copy_file( 'asset.txt', 'sub/asset.txt', force: force )
      end
    end

    # Thor gated color on the stream being a tty. Ceedling's decorator policy is
    # tty-blind, so without this check a redirected `ceedling new` would start
    # carrying escape sequences it never carried before.
    it 'emits no color when decorators are enabled but the stream is not a tty' do
      allow(@loginator).to receive(:decorators).and_return( true )
      allow($stdout).to receive(:tty?).and_return( false )
      expect_absent_destination( dest_path('sub', 'asset.txt') )

      expect(@loginator).to receive(:console).with( '      create  sub/asset.txt', LogLabels::NONE )

      @actionator.copy_file( 'asset.txt', 'sub/asset.txt' )
    end
  end

  describe '#copy_directory' do
    before(:each) do
      # Sources exist, destinations do not, so every copy takes the create path.
      allow(@file_wrapper).to receive(:exist?) { |path| path.start_with?( src_path ) }
      allow(@file_wrapper).to receive(:read_binary).and_return( 'contents' )
      allow(@file_wrapper).to receive(:dirname) { |path| File.dirname( path ) }
      allow(@file_wrapper).to receive(:mkdir)
      allow(@file_wrapper).to receive(:write)
      allow(@file_wrapper).to receive(:directory?).and_return( false )
    end

    it 'copies files and omits junk files' do
      allow(@file_wrapper).to receive(:directory_listing).and_return([
        src_path('tree', 'keep.txt'),
        src_path('tree', 'thumbs.db'),
        src_path('tree', '.DS_Store'),
      ])

      expect(@file_wrapper).to receive(:write).with( dest_path('out', 'keep.txt'), 'contents', 'wb' )
      expect(@file_wrapper).to_not receive(:write).with( /thumbs\.db/, anything, anything )
      expect(@file_wrapper).to_not receive(:write).with( /DS_Store/, anything, anything )

      @actionator.copy_directory( 'tree', 'out', force: true )
    end

    it 'rebases nested sources onto the destination' do
      allow(@file_wrapper).to receive(:directory_listing).and_return([ src_path('tree', 'a', 'b', 'c.txt') ])

      expect(@file_wrapper).to receive(:write).with( dest_path('out', 'a', 'b', 'c.txt'), 'contents', 'wb' )

      @actionator.copy_directory( 'tree', 'out', force: true )
    end

    it 'skips directory entries in the listing' do
      allow(@file_wrapper).to receive(:directory_listing).and_return([ src_path('tree', 'sub') ])
      allow(@file_wrapper).to receive(:directory?).with( src_path('tree', 'sub') ).and_return( true )

      expect(@file_wrapper).to_not receive(:write).with( /sub/, anything, anything )

      @actionator.copy_directory( 'tree', 'out', force: true )
    end

    # Thor reported the destination directory itself before any of its contents.
    it 'reports the destination directory before its files' do
      allow(@file_wrapper).to receive(:directory_listing).and_return([ src_path('tree', 'keep.txt') ])

      reported = []
      allow(@loginator).to receive(:console) { |message, _label| reported << message }

      @actionator.copy_directory( 'tree', 'out', force: true )

      expect(reported).to eq([
        '      create  out',
        '      create  out/keep.txt',
      ])
    end

    # Issue #104: a Ceedling install path can contain literal glob metacharacters.
    # FileWrapper#directory_listing does not escape, so Actionator has to.
    it 'escapes glob metacharacters in the source path' do
      bracketed_root = File.expand_path( '/src/[legacy]' )
      @actionator.source_root = bracketed_root
      allow(@file_wrapper).to receive(:directory_listing).and_return([])

      escaped = bracketed_root.gsub( /[*?{}\[\]]/ ) { |char| '\\' + char }
      expect(@file_wrapper).to receive(:directory_listing).with( File.join( escaped, 'tree', '**', '*' ) )

      @actionator.copy_directory( 'tree', 'out', force: true )
    end

    # cli_helper.rb passes component paths with a trailing separator.
    it 'tolerates a trailing separator on the source' do
      allow(@file_wrapper).to receive(:directory_listing).and_return([ src_path('tree', 'keep.txt') ])

      expect(@file_wrapper).to receive(:directory_listing).with( File.join( src_path('tree'), '**', '*' ) )
      expect(@file_wrapper).to receive(:write).with( dest_path('out', 'keep.txt'), 'contents', 'wb' )

      @actionator.copy_directory( 'tree/', 'out', force: true )
    end
  end

  describe '#make_directory' do
    it 'creates an absent directory and reports it created' do
      allow(@file_wrapper).to receive(:exist?).with( dest_path('sub') ).and_return( false )

      expect(@file_wrapper).to receive(:mkdir).with( dest_path('sub') )
      expect(@loginator).to receive(:console).with( '      create  sub', LogLabels::NONE )

      @actionator.make_directory( 'sub' )
    end

    it 'reports an existing directory without recreating it' do
      allow(@file_wrapper).to receive(:exist?).with( dest_path('sub') ).and_return( true )

      expect(@file_wrapper).to_not receive(:mkdir)
      expect(@loginator).to receive(:console).with( '       exist  sub', LogLabels::NONE )

      @actionator.make_directory( 'sub' )
    end

    # cli_handler.rb builds the project root as File.join( dest, '.' ).
    it 'normalizes a trailing dot segment' do
      allow(@file_wrapper).to receive(:exist?).and_return( false )
      allow(@file_wrapper).to receive(:mkdir)

      expect(@loginator).to receive(:console).with( '      create  proj', LogLabels::NONE )

      @actionator.make_directory( 'proj/.' )
    end

    it 'reports a destination outside the destination root by its absolute path' do
      outside = File.expand_path( '/elsewhere/sub' )

      allow(@file_wrapper).to receive(:exist?).and_return( false )
      allow(@file_wrapper).to receive(:mkdir)

      expect(@loginator).to receive(:console).with( "      create  #{outside}", LogLabels::NONE )

      @actionator.make_directory( outside )
    end

    it 'reports the destination root itself as an empty path' do
      allow(@file_wrapper).to receive(:exist?).and_return( true )

      expect(@loginator).to receive(:console).with( '       exist  ', LogLabels::NONE )

      @actionator.make_directory( dest_path )
    end
  end

  describe '#remove_directory' do
    it 'removes an existing directory and reports it' do
      allow(@file_wrapper).to receive(:exist?).with( dest_path('vendor') ).and_return( true )

      expect(@file_wrapper).to receive(:rm_rf).with( dest_path('vendor') )
      expect(@loginator).to receive(:console).with( '      remove  vendor', LogLabels::NONE )

      @actionator.remove_directory( 'vendor' )
    end

    # cli_handler.rb's upgrade path removes a vendor directory that may not exist,
    # and Thor reported the removal before checking. Preserved so upgrade output is
    # unchanged.
    it 'reports an absent directory without attempting removal' do
      allow(@file_wrapper).to receive(:exist?).with( dest_path('vendor') ).and_return( false )

      expect(@file_wrapper).to_not receive(:rm_rf)
      expect(@loginator).to receive(:console).with( '      remove  vendor', LogLabels::NONE )

      @actionator.remove_directory( 'vendor' )
    end
  end

  describe '#chmod' do
    it 'changes the mode and reports it' do
      expect(@file_wrapper).to receive(:chmod).with( dest_path('bin', 'ceedling'), 0755 )
      expect(@loginator).to receive(:console).with( '       chmod  bin/ceedling', LogLabels::NONE )

      @actionator.chmod( 'bin/ceedling', 0755 )
    end
  end

  describe '#gsub_file' do
    it 'substitutes matched text and writes in binary mode' do
      allow(@file_wrapper).to receive(:read_binary).with( dest_path('project.yml') ).and_return( "version: '?'\n" )

      expect(@file_wrapper).to receive(:write).with( dest_path('project.yml'), "version: '1.2.0'\n", 'wb' )
      expect(@loginator).to receive(:console).with( '        gsub  project.yml', LogLabels::NONE )

      @actionator.gsub_file( 'project.yml', /version:\s+'\?'/, "version: '1.2.0'" )
    end

    # Both call sites stamp conditionally, so a pattern that matches nothing is a
    # legitimate outcome. Thor's non-bang gsub_file did not raise either.
    it 'does not raise when the pattern matches nothing' do
      allow(@file_wrapper).to receive(:read_binary).and_return( "unrelated\n" )

      expect(@file_wrapper).to receive(:write).with( dest_path('project.yml'), "unrelated\n", 'wb' )

      expect {
        @actionator.gsub_file( 'project.yml', /nope/, 'replacement' )
      }.to_not raise_error
    end

    it 'prints no status line when verbose is false' do
      allow(@file_wrapper).to receive(:read_binary).and_return( 'contents' )
      allow(@file_wrapper).to receive(:write)

      expect(@loginator).to_not receive(:console)

      @actionator.gsub_file( 'project.yml', /nope/, 'replacement', verbose: false )
    end
  end

  describe '#touch_file' do
    # Never went through Thor, so it never printed a status line. Adding one now
    # would change `ceedling new --gitsupport` output.
    it 'touches the file and prints no status line' do
      expect(@file_wrapper).to receive(:touch).with( 'proj/test/support/.gitkeep' )
      expect(@loginator).to_not receive(:console)

      @actionator.touch_file( 'proj/test/support/.gitkeep' )
    end
  end
end
