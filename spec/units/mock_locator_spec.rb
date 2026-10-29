# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/constants'
require 'ceedling/includes/includes'
require 'ceedling/test_invoker/mock_locator'

describe MockLocator do
  before(:each) do
    @configurator       = double( "Configurator", cmock_mock_prefix: 'Mock', cmock_mock_name_include_folder: true )
    @include_pathinator = double( "IncludePathinator" )
    @file_finder        = double( "FileFinder" )
    @file_path_utils    = double( "FilePathUtils" )

    allow(@file_path_utils).to receive(:form_mock_output_path) do |root, subdir|
      subdir.nil? || subdir.empty? ? root : File.join( root, subdir )
    end

    @locator = described_class.new(
      configurator: @configurator, include_pathinator: @include_pathinator, file_finder: @file_finder, file_path_utils: @file_path_utils
    )
  end

  describe "#header_collection" do
    it "orders the headers on a test's search paths without its own mock directories" do
      expect(@include_pathinator).to receive(:ordered_header_files).with( ['src'] ).and_return( ['src/foo.h'] )

      expect(@locator.header_collection( ['mocks/drivers', 'src'], ['mocks/drivers'] )).to eq( ['src/foo.h'] )
    end
  end

  describe "#locate" do
    it "resolves a mock's real header and its mirrored subdirectory against a collection" do
      allow(@file_finder).to receive(:resolve_mock).with( 'MockFoo.h', collection: ['src/drivers/foo.h'], complain: :error )
        .and_return( ['src/drivers/foo.h', 'drivers'] )

      expect(@locator.locate( MockInclude.new( 'MockFoo.h' ), collection: ['src/drivers/foo.h'] )).to eq( ['src/drivers/foo.h', 'drivers'] )
    end

    it "passes on how to treat a missing header" do
      expect(@file_finder).to receive(:resolve_mock).with( 'MockFoo.h', collection: [], complain: :ignore ).and_return( [nil, nil] )

      expect(@locator.locate( MockInclude.new( 'MockFoo.h' ), collection: [], complain: :ignore )).to eq( [nil, nil] )
    end
  end

  describe "#directories" do
    it "gives each mock's mirrored directory below the mock root, once" do
      allow(@file_finder).to receive(:resolve_mock).with( 'MockFoo.h', collection: [], complain: :error ).and_return( ['src/drivers/foo.h', 'drivers'] )
      allow(@file_finder).to receive(:resolve_mock).with( 'MockBar.h', collection: [], complain: :error ).and_return( ['src/drivers/bar.h', 'drivers'] )
      allow(@file_finder).to receive(:resolve_mock).with( 'MockBaz.h', collection: [], complain: :error ).and_return( ['src/baz.h', ''] )
      mocks = %w[MockFoo.h MockBar.h MockBaz.h].map { |name| MockInclude.new( name ) }

      expect(@locator.directories( mocks, mocks_root: 'mocks', collection: [] )).to eq( ['mocks/drivers', 'mocks'] )
    end

    # GH #1370's path handling audit: CMock's root plus a climbing folder must not leave the mock root
    it "adds the root CMock climbs from for a mock whose #include folder climbs" do
      allow(@file_finder).to receive(:resolve_mock).with( '../x/MockFoo.h', collection: [], complain: :error ).and_return( ['../x/foo.h', ''] )

      expect(@locator.directories( [MockInclude.new( '../x/MockFoo.h' )], mocks_root: 'mocks', collection: [] ))
        .to eq( ['mocks/_up_/x', 'mocks/_up_/_up_'] )
    end

    it "adds the directory a folder that ends the mirror leads down from" do
      allow(@file_finder).to receive(:resolve_mock).with( 'uart/MockFoo.h', collection: [], complain: :error ).and_return( ['src/drivers/uart/foo.h', 'drivers/uart'] )

      expect(@locator.directories( [MockInclude.new( 'uart/MockFoo.h' )], mocks_root: 'mocks', collection: [] ))
        .to eq( ['mocks/drivers/uart', 'mocks/drivers'] )
    end

    it "skips a Partial mock, which has no real header" do
      expect(@file_finder).to_not receive(:resolve_mock)

      expect(@locator.directories( [MockInclude.new( "Mock#{PARTIAL_FILENAME_PREFIX}foo_interface.h" )], mocks_root: 'mocks', collection: [] )).to eq( [] )
    end

    it "skips a mock whose missing header the caller tolerates" do
      allow(@file_finder).to receive(:resolve_mock).with( 'MockGone.h', collection: [], complain: :ignore ).and_return( [nil, nil] )

      expect(@locator.directories( [MockInclude.new( 'MockGone.h' )], mocks_root: 'mocks', collection: [], complain: :ignore )).to eq( [] )
    end
  end
  # CMock writes a mock below its root at the folder the #include names, and names the mock
  # by that folder. The compiler reaches the mock through the #include as written, from
  # the directory that folder leads down or climbs from (`reach`).
  describe "#placement" do
    def placement(include_path, subdir: 'drivers/uart')
      @locator.placement( mocks_root: 'mocks/t', subdir: subdir, include_path: include_path )
    end

    it "keeps a bare #include's mock in its mirrored directory, with no folder" do
      expect(placement( 'MockFoo.h' ).to_h).to eq( folder: nil, directory: 'mocks/t/drivers/uart', root: 'mocks/t/drivers/uart', reach: 'mocks/t/drivers/uart' )
    end

    it "roots CMock above a folder that ends the mirrored directory" do
      expect(placement( 'uart/MockFoo.h' ).to_h).to eq( folder: 'uart', directory: 'mocks/t/drivers/uart', root: 'mocks/t/drivers', reach: 'mocks/t/drivers' )
      expect(placement( 'drivers/uart/MockFoo.h' ).to_h).to eq( folder: 'drivers/uart', directory: 'mocks/t/drivers/uart', root: 'mocks/t', reach: 'mocks/t' )
    end

    # The mock root carries the test's name, which a folder must never be mistaken for ending
    it "compares the folder with the header's mirrored subdirectory alone, not the mock root" do
      spot = @locator.placement( mocks_root: 'mocks/test/test_c', subdir: '', include_path: 'test_c/MockFoo.h' )

      expect(spot.to_h).to eq( folder: 'test_c', directory: 'mocks/test/test_c/test_c', root: 'mocks/test/test_c', reach: 'mocks/test/test_c' )
    end

    it "places the mock at the written path below the mock root for a folder longer than the mirror" do
      expect(placement( 'more/sub/MockFoo.h', subdir: 'sub' ).to_h).to eq( folder: 'more/sub', directory: 'mocks/t/more/sub', root: 'mocks/t', reach: 'mocks/t' )
    end

    it "drops a leading ./ from the folder" do
      expect(placement( './uart/MockFoo.h' ).folder).to eq( 'uart' )
    end

    it "passes no folder when :mock_name_include_folder is disabled, keeping the place the #include reaches" do
      allow(@configurator).to receive(:cmock_mock_name_include_folder).and_return( false )

      expect(placement( 'uart/MockFoo.h' ).to_h).to eq( folder: nil, directory: 'mocks/t/drivers/uart', root: 'mocks/t/drivers/uart', reach: 'mocks/t/drivers' )
      expect(placement( 'more/sub/MockFoo.h', subdir: 'sub' ).to_h).to eq( folder: nil, directory: 'mocks/t/more/sub', root: 'mocks/t/more/sub', reach: 'mocks/t' )
    end

    it "keeps the mock of a folder that climbs below the mock root, reached from as deep as the climb" do
      expect(placement( '../x/MockFoo.h', subdir: 'y' ).to_h).to eq( folder: '../x', directory: 'mocks/t/_up_/x', root: 'mocks/t/_up_/_up_', reach: 'mocks/t/_up_/_up_' )
      expect(placement( '../../x/MockFoo.h', subdir: '' ).to_h)
        .to eq( folder: '../../x', directory: 'mocks/t/_up_/_up_/x', root: 'mocks/t/_up_/_up_/_up_/_up_', reach: 'mocks/t/_up_/_up_/_up_/_up_' )
    end

    it "always writes the mock where CMock's root and its folder lead, and where the #include reaches" do
      [true, false].each do |name_by_folder|
        allow(@configurator).to receive(:cmock_mock_name_include_folder).and_return( name_by_folder )

        ['MockFoo.h', 'uart/MockFoo.h', 'more/sub/MockFoo.h', '../x/MockFoo.h', '../../a/b/MockFoo.h', './uart/MockFoo.h'].each do |include_path|
          spot    = placement( include_path )
          written = File.dirname( include_path )

          expect(File.expand_path( File.join( *[spot.root, spot.folder].compact ), '/w' )).to eq( File.expand_path( spot.directory, '/w' ) ), include_path
          expect(File.expand_path( File.join( spot.reach, written ), '/w' )).to eq( File.expand_path( spot.directory, '/w' ) ), include_path
          [spot.directory, spot.root, spot.reach].each { |dir| expect(dir.split( '/' )).to_not include( '..' ), include_path }
        end
      end
    end
  end
end
