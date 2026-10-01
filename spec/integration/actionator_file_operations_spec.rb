# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Integration coverage for Actionator, the component that replaced the slice of
# Thor::Actions Ceedling used. Actionator backs `ceedling new`, `ceedling example`,
# `ceedling upgrade`, and the vendoring of Ceedling into a project.
#
# A real FileWrapper against a real temp directory is the only thing that can prove
# the behaviors a double cannot observe. Binary-mode writes are the clearest case.
# A double records that 'wb' was passed, but only a real write proves the bytes
# survive, and a CRLF payload written in text mode on Windows corrupts both the
# vendored launch script and every vendored source file. Real recursive globbing,
# real glob metacharacter escaping, and real permission bits are the same story.
#
# The unit spec at spec/units/bin/actionator_spec.rb owns the status-line format,
# the verb vocabulary, colorization, and the raise paths. Those assert on messages
# to injected doubles and need no filesystem. Only one status-line example appears
# here, confirming the format survives a real tree rather than a stubbed listing.

require 'spec_helper'
require 'spec_integration_helper'
require 'actionator'
require 'ceedling/file_wrapper'

describe 'Actionator file operations (integration)' do
  include IntegrationSpecHelpers

  # Actionator's Loginator cannot be NULL here. Status lines have to be readable
  # back, and `decorators` has to answer a real boolean rather than a null object,
  # which is truthy and would colorize every captured line.
  # Named for this spec alone, since every integration spec shares one RSpec
  # process and Ruby's open classes would let a duplicate name clobber another
  # file's definition.
  class ActionatorCapturingLoginator
    attr_reader :lines

    def initialize
      @lines = []
    end

    def decorators
      return false
    end

    def console(message, _label=nil)
      @lines << message
      return nil
    end
  end

  # Raises on a write to one named destination so an Actionator failure is proven to
  # surface rather than being swallowed. Faults at #write, one level below
  # Actionator's own logic, matching the pattern the transient-I/O retry specs use.
  class ActionatorWriteFaultingFileWrapper < FileWrapper
    def initialize(fault_dest:, **kwargs)
      super(**kwargs)
      @fault_dest = fault_dest
    end

    def write(filepath, contents, flags='w')
      raise Errno::EACCES, "simulated permission failure on #{filepath}" if filepath == @fault_dest
      super
    end
  end

  def build_actionator(dir, file_wrapper: nil)
    file_wrapper ||= FileWrapper.new(
      loginator:    IntegrationSpecHelpers::NULL,
      verbosinator: IntegrationSpecHelpers::NULL
    )

    @loginator = ActionatorCapturingLoginator.new

    # Expanded to match what production does. Actionator captures destination_root
    # from FileWrapper#get_expanded_path, and it shortens status-line paths by
    # prefix-matching destinations that it expands the same way. On Windows a temp
    # directory can arrive with backslashes while File.expand_path yields forward
    # slashes, so an unexpanded root here would never match and every status line
    # would report an absolute path.
    root = File.expand_path( dir )

    actionator = Actionator.new( file_wrapper: file_wrapper, loginator: @loginator )
    actionator.source_root      = root
    actionator.destination_root = root
    return actionator
  end

  describe 'copy_directory' do
    it 'copies a tree while omitting junk files' do
      tree = {
        'tree/keep.txt'        => 'keep me',
        'tree/thumbs.db'       => 'junk',
        'tree/.DS_Store'       => 'junk',
      }

      with_source_tree(tree) do |dir|
        actionator = build_actionator( dir )

        actionator.copy_directory( 'tree', File.join( dir, 'out' ), force: true )

        expect(File.exist?( File.join( dir, 'out', 'keep.txt' ) )).to be true
        expect(File.exist?( File.join( dir, 'out', 'thumbs.db' ) )).to be false
        expect(File.exist?( File.join( dir, 'out', '.DS_Store' ) )).to be false
      end
    end

    it 'recurses into nested directories' do
      with_source_tree({ 'tree/a/b/c.txt' => 'nested' }) do |dir|
        actionator = build_actionator( dir )

        actionator.copy_directory( 'tree', File.join( dir, 'out' ), force: true )

        expect(File.read( File.join( dir, 'out', 'a', 'b', 'c.txt' ) )).to eq( 'nested' )
      end
    end

    # Issue #104. A Ceedling install path can contain literal glob metacharacters,
    # and FileWrapper#directory_listing does not escape them. Proven here against a
    # real Dir.glob rather than a stubbed listing.
    it 'copies from a source path containing glob metacharacters' do
      with_source_tree({ '[legacy]/tree/f.txt' => 'bracketed' }) do |dir|
        actionator = build_actionator( dir )
        actionator.source_root = File.join( dir, '[legacy]' )

        actionator.copy_directory( 'tree', File.join( dir, 'out' ), force: true )

        expect(File.read( File.join( dir, 'out', 'f.txt' ) )).to eq( 'bracketed' )
      end
    end

    it 'reports a real tree with Thor-compatible status lines' do
      with_source_tree({ 'tree/keep.txt' => 'keep me' }) do |dir|
        actionator = build_actionator( dir )

        actionator.copy_directory( 'tree', File.join( dir, 'out' ), force: true )

        expect(@loginator.lines).to eq([
          '      create  out',
          '      create  out/keep.txt',
        ])
      end
    end
  end

  describe 'copy_file' do
    # The assertion that proves binary mode. Text-mode writes translate these bytes
    # on Windows, corrupting the vendored ceedling launch script.
    it 'round-trips CRLF content byte for byte' do
      with_source_tree({}) do |dir|
        File.binwrite( File.join( dir, 'crlf.txt' ), "a\r\nb\r\n" )
        actionator = build_actionator( dir )

        actionator.copy_file( 'crlf.txt', File.join( dir, 'copy.txt' ) )

        expect(File.binread( File.join( dir, 'copy.txt' ) )).to eq( "a\r\nb\r\n" )
      end
    end

    it 'creates missing parent directories' do
      with_source_tree({ 'asset.txt' => 'contents' }) do |dir|
        actionator = build_actionator( dir )

        actionator.copy_file( 'asset.txt', File.join( dir, 'a', 'b', 'asset.txt' ) )

        expect(File.read( File.join( dir, 'a', 'b', 'asset.txt' ) )).to eq( 'contents' )
      end
    end

    it 'leaves a byte-identical destination untouched' do
      with_source_tree({ 'asset.txt' => 'same', 'copy.txt' => 'same' }) do |dir|
        actionator = build_actionator( dir )

        actionator.copy_file( 'asset.txt', File.join( dir, 'copy.txt' ) )

        expect(@loginator.lines).to eq([ '   identical  copy.txt' ])
      end
    end

    it 'overwrites a differing destination when forced' do
      with_source_tree({ 'asset.txt' => 'new', 'copy.txt' => 'old' }) do |dir|
        actionator = build_actionator( dir )

        actionator.copy_file( 'asset.txt', File.join( dir, 'copy.txt' ), force: true )

        expect(File.read( File.join( dir, 'copy.txt' ) )).to eq( 'new' )
        expect(@loginator.lines).to eq([ '       force  copy.txt' ])
      end
    end

    it 'surfaces a write failure rather than swallowing it' do
      with_source_tree({ 'asset.txt' => 'contents' }) do |dir|
        dest = File.join( dir, 'copy.txt' )
        faulting = ActionatorWriteFaultingFileWrapper.new(
          fault_dest:   dest,
          loginator:    IntegrationSpecHelpers::NULL,
          verbosinator: IntegrationSpecHelpers::NULL
        )
        actionator = build_actionator( dir, file_wrapper: faulting )

        expect {
          actionator.copy_file( 'asset.txt', dest )
        }.to raise_error( Errno::EACCES )
      end
    end
  end

  describe 'make_directory' do
    it 'creates a deep path and tolerates a second call' do
      with_source_tree({}) do |dir|
        actionator = build_actionator( dir )
        target = File.join( dir, 'a', 'b', 'c' )

        actionator.make_directory( target )
        expect(Dir.exist?( target )).to be true

        expect { actionator.make_directory( target ) }.to_not raise_error
        expect(@loginator.lines.last).to eq( '       exist  a/b/c' )
      end
    end
  end

  describe 'remove_directory' do
    it 'removes a populated tree' do
      with_source_tree({ 'doomed/a/b.txt' => 'bye' }) do |dir|
        actionator = build_actionator( dir )
        target = File.join( dir, 'doomed' )

        actionator.remove_directory( target )

        expect(Dir.exist?( target )).to be false
      end
    end

    it 'does not raise on an absent path' do
      with_source_tree({}) do |dir|
        actionator = build_actionator( dir )

        expect {
          actionator.remove_directory( File.join( dir, 'never_existed' ) )
        }.to_not raise_error
      end
    end
  end

  describe 'chmod' do
    it 'sets real permission bits', skip: (RUBY_PLATFORM.downcase =~ /mingw|win32/ ? 'chmod is not meaningful on Windows' : false) do
      with_source_tree({ 'launcher' => '#!/bin/sh' }) do |dir|
        actionator = build_actionator( dir )
        target = File.join( dir, 'launcher' )

        actionator.chmod( target, 0755 )

        expect(File.stat( target ).mode & 0777).to eq( 0755 )
      end
    end
  end

  describe 'gsub_file' do
    it 'substitutes matched text in place' do
      with_source_tree({ 'project.yml' => ":ceedling_version: '?'\n" }) do |dir|
        actionator = build_actionator( dir )
        target = File.join( dir, 'project.yml' )

        actionator.gsub_file( target, /:ceedling_version:\s+'\?'/, ':ceedling_version: 1.2.0' )

        expect(File.read( target )).to eq( ":ceedling_version: 1.2.0\n" )
      end
    end
  end

  describe 'touch_file' do
    it 'creates an empty file' do
      with_source_tree({}) do |dir|
        actionator = build_actionator( dir )
        target = File.join( dir, 'marker' )

        actionator.touch_file( target )

        expect(File.exist?( target )).to be true
      end
    end
  end
end
