# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'ceedling/project_paths'

# GH #1370 and the path handling audit around it: one place spelled many ways compared
# as text, so `..` "contained" paths above it and build files escaped the build directory
describe ProjectPaths do
  WINDOWS_ONLY = { if: Gem.win_platform? }.freeze
  POSIX_ONLY   = { unless: Gem.win_platform? }.freeze

  around(:each) do |example|
    Dir.mktmpdir do |dir|
      @ws = File.realpath( dir )
      FileUtils.mkdir_p( File.join( @ws, 'app' ) )
      Dir.chdir( File.join( @ws, 'app' ) ) { example.run }
    end
  end

  describe '.standardize' do
    it 'writes a path with forward slashes and no trailing separator' do
      expect(ProjectPaths.standardize( " src\\drv\\ " )).to eq( 'src/drv' )
    end

    it 'reads `~` as the home directory, after any decorator' do
      expect(ProjectPaths.standardize( '~/inc' )).to eq( File.join( Dir.home, 'inc' ) )
      expect(ProjectPaths.standardize( '-:~/inc' )).to eq( "-:#{File.join( Dir.home, 'inc' )}" )
    end

    it 'leaves `~user` as written' do
      expect(ProjectPaths.standardize( '~someone/inc' )).to eq( '~someone/inc' )
    end

    it 'keeps a filesystem root' do
      expect(ProjectPaths.standardize( '/' )).to eq( '/' )
    end

    it 'reads `~` after a decorator and a space, and drops every trailing separator' do
      expect(ProjectPaths.standardize( '+: ~/inc' )).to eq( "+:#{File.join( Dir.home, 'inc' )}" )
      expect(ProjectPaths.standardize( 'src//' )).to eq( 'src' )
    end
  end

  describe '.absolute' do
    # Spelled as the full computation spells it, whatever the shortcut for a clean path
    it 'spells a rooted path with a trailing separator or surrounding space without either' do
      expect(ProjectPaths.absolute( '/a/' )).to eq( '/a' ) unless Gem.win_platform?
      expect(ProjectPaths.absolute( " #{@ws}/x " )).to eq( "#{@ws}/x" )
    end

    it 'reads `~user` as a directory of that name, never the user\'s home' do
      expect(ProjectPaths.absolute( '~nosuchuser/inc' )).to eq( File.join( @ws, 'app', '~nosuchuser/inc' ) )
    end

    it 'reads a doubled leading separator as the filesystem root', **POSIX_ONLY do
      expect(ProjectPaths.absolute( '//usr/include' )).to eq( '/usr/include' )
      expect(ProjectPaths.contains?( '/usr', '//usr/include' )).to be true
    end

    it 'keeps a UNC path\'s `..` below its share', **WINDOWS_ONLY do
      expect(ProjectPaths.absolute( '//srv/sh/a/../../../x' )).to eq( '//srv/sh/x' )
    end
  end

  describe '.canonical' do
    it 'spells every form of one place alike' do
      FileUtils.mkdir_p( 'src/drv' )
      spellings = ['src/drv', './src/drv', 'src/drv/', 'src\\drv', File.join( @ws, 'app/src/drv' ), 'src/../src/drv']

      expect(spellings.map { |spelling| ProjectPaths.canonical( spelling ) }.uniq).to eq( ['src/drv'] )
    end

    it 'resolves a symlink along the existing part of a path', **POSIX_ONLY do
      FileUtils.mkdir_p( 'src' )
      File.symlink( File.join( @ws, 'app' ), File.join( @ws, 'link' ) )

      expect(ProjectPaths.canonical( File.join( @ws, 'link/src/not_yet' ) )).to eq( 'src/not_yet' )
    end

    it 'climbs to a place outside the project' do
      expect(ProjectPaths.canonical( File.join( @ws, 'shared/src' ) )).to eq( '../shared/src' )
    end
  end

  describe '.subdir_below' do
    it 'names the directories from a root down to a path below it' do
      expect(ProjectPaths.subdir_below( 'src', 'src/drv/uart' )).to eq( 'drv/uart' )
      expect(ProjectPaths.subdir_below( 'src', 'src' )).to eq( '' )
    end

    it 'finds nothing below a root that only shares a path\'s leading text' do
      expect(ProjectPaths.subdir_below( 'src', 'src2/x' )).to be_nil
    end

    it 'finds nothing below `..` for a path climbing past it' do
      expect(ProjectPaths.subdir_below( '..', '../../vendor/inc' )).to be_nil
      expect(ProjectPaths.subdir_below( '..', '../vendor/inc' )).to eq( 'vendor/inc' )
    end

    it 'compares every spelling of a root and a path' do
      expect(ProjectPaths.subdir_below( './src', File.join( @ws, 'app/src/a' ) )).to eq( 'a' )
      expect(ProjectPaths.subdir_below( File.join( @ws, 'app/src' ), 'src/a' )).to eq( 'a' )
    end

    it 'never answers a subdirectory that climbs or is absolute' do
      roots = ['..', '../..', '.', 'src', File.join( @ws, 'vendor' ), '/']
      paths = ['../../far/x', '../vendor/inc', 'src/a', '/opt/x', File.join( @ws, 'vendor/inc' )]

      roots.product( paths ).each do |root, path|
        subdir = ProjectPaths.subdir_below( root, path )
        next if subdir.nil?

        expect(subdir.split( '/' )).to_not include( '..' ), "#{root} below #{path}: #{subdir}"
        expect(subdir).to_not start_with( '/' ), "#{root} below #{path}: #{subdir}"
      end
    end

    it 'compares Windows paths without regard to case', **WINDOWS_ONLY do
      expect(ProjectPaths.subdir_below( 'C:/Proj/Src', 'c:/proj/src/a' )).to eq( 'a' )
    end
  end
end
