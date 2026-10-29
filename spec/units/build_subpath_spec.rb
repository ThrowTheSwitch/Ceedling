# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'ceedling/build_subpath'

# GH #1370 and the path handling audit around it: a build file placed by text could land
# outside the build directory
describe BuildSubpath do
  WINDOWS_ONLY_BUILD = { if: Gem.win_platform? }.freeze

  around(:each) do |example|
    Dir.mktmpdir do |dir|
      @ws = File.realpath( dir )
      FileUtils.mkdir_p( File.join( @ws, 'app' ) )
      Dir.chdir( File.join( @ws, 'app' ) ) { example.run }
    end
  end

  describe '.encode and .decode' do
    {
      'a file in the project'    => ['src/drv/uart', 'src/drv/uart'],
      'a sibling of the project' => ['../shared/src', '_up_/shared/src'],
      'the working directory'    => ['.', '']
    }.each do |label, (path, encoded)|
      it "places #{label} by its path from the project root, and reads it back" do
        expect(BuildSubpath.encode( path )).to eq( encoded )
        expect(BuildSubpath.decode( encoded )).to eq( path == '.' ? '' : path )
      end
    end

    # A project's own directory may carry a marker's name, which must read back as itself
    it 'places a directory named like a marker apart from the marker, and reads it back' do
      ['_up_/x', 'src/a/_up_', '_ceedling_/src', '_abs_/C/x', '_unc_/srv', 'src/__up_/x'].each do |path|
        encoded = BuildSubpath.encode( path )

        expect(BuildSubpath.decode( encoded )).to eq( path ), "#{path} => #{encoded}"
      end
      expect(BuildSubpath.encode( '_up_/x' )).to_not eq( BuildSubpath.encode( '../x' ) )
      # macOS and Windows file systems fold case
      expect(BuildSubpath.encode( '_UP_/x' ).downcase).to_not eq( BuildSubpath.encode( '../x' ).downcase )
      expect(BuildSubpath.decode( BuildSubpath.encode( '_UP_/x' ) )).to eq( '_UP_/x' )
    end

    # Windows has no relative path from one drive to another
    it 'places a file of the running Ceedling on another drive below `_ceedling_` too' do
      file = File.join( BuildSubpath::INSTALLATION_ROOT, 'plugins/fff/src' )
      allow(ProjectPaths).to receive(:relative).and_call_original
      allow(ProjectPaths).to receive(:relative).with( file ).and_return( file )

      expect(BuildSubpath.encode( file )).to eq( '_ceedling_/plugins/fff/src' )
    end

    it 'places an absolute path below the project as a relative one' do
      expect(BuildSubpath.encode( File.join( @ws, 'app/src/x' ) )).to eq( 'src/x' )
    end

    it 'places a file of the running Ceedling outside the project below `_ceedling_`, and reads it back' do
      file = File.join( BuildSubpath::INSTALLATION_ROOT, 'plugins/fff/src' )

      expect(BuildSubpath.encode( file )).to eq( '_ceedling_/plugins/fff/src' )
      expect(File.expand_path( BuildSubpath.decode( '_ceedling_/plugins/fff/src' ) )).to eq( file )
    end

    # A project may itself sit inside a Ceedling checkout, as the system specs' projects do.
    # Only what Ceedling ships places below `_ceedling_`.
    it 'places a directory beside a project inside the installation by its path from the project root' do
      root = BuildSubpath::INSTALLATION_ROOT
      allow(ProjectPaths).to receive(:working_dir).and_return( File.join( root, 'specout/proj/app' ) )

      expect(BuildSubpath.encode( File.join( root, 'specout/proj/shared/src' ) )).to eq( '_up_/shared/src' )
      expect(BuildSubpath.encode( File.join( root, 'plugins/fff/src' ) )).to eq( '_ceedling_/plugins/fff/src' )
    end

    it 'places a file of the running Ceedling inside the project by its path from the project root' do
      Dir.chdir( BuildSubpath::INSTALLATION_ROOT ) do
        expect(BuildSubpath.encode( 'plugins/fff/src' )).to eq( 'plugins/fff/src' )
      end
    end

    it 'places a path on another drive below `_abs_`, and reads it back', **WINDOWS_ONLY_BUILD do
      other = Dir.pwd.start_with?( 'C' ) ? 'D' : 'C'

      expect(BuildSubpath.encode( "#{other}:/x/inc" )).to eq( "_abs_/#{other}/x/inc" )
      expect(BuildSubpath.decode( "_abs_/#{other}/x/inc" )).to eq( "#{other}:/x/inc" )
    end

    it 'places a UNC path below `_unc_`, and reads it back', **WINDOWS_ONLY_BUILD do
      expect(BuildSubpath.encode( '//server/share/inc' )).to eq( '_unc_/server/share/inc' )
      expect(BuildSubpath.decode( '_unc_/server/share/inc' )).to eq( '//server/share/inc' )
    end

    it 'never places a file outside the build subpath it names' do
      ['../../far/x', '/opt/x', '../shared', File.join( @ws, 'app/../../x' )].each do |path|
        encoded = BuildSubpath.encode( path )

        expect(encoded.split( '/' )).to_not include( '..' ), "#{path}: #{encoded}"
        expect(encoded).to_not start_with( '/' ), "#{path}: #{encoded}"
      end
    end
  end

  describe '.of_directory' do
    it 'is the encoding of a directory, with the working directory as empty' do
      expect(BuildSubpath.of_directory( 'src/drv' )).to eq( 'src/drv' )
      expect(BuildSubpath.of_directory( '.' )).to eq( '' )
    end
  end
end
