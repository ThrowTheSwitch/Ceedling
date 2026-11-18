# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/constants'
require 'ceedling/includes/includes'
require 'ceedling/includes/header_search'
require 'ceedling/test_invoker/mock_locator'
require 'ceedling/test_invoker/test_invoker_types'

describe MockLocator do
  before(:each) do
    @configurator       = double( "Configurator", cmock_mock_prefix: 'Mock', cmock_mock_name_include_folder: true )
    @include_pathinator = double( "IncludePathinator" )
    @file_finder        = double( "FileFinder" )
    @file_path_utils    = double( "FilePathUtils" )
    @test_search_paths  = double( "TestSearchPaths" )

    allow(@file_path_utils).to receive(:form_mock_output_path) do |root, subdir|
      subdir.nil? || subdir.empty? ? root : File.join( root, subdir )
    end

    @locator = described_class.new(
      configurator: @configurator, include_pathinator: @include_pathinator, test_search_paths: @test_search_paths,
      file_finder: @file_finder, file_path_utils: @file_path_utils
    )
  end

  describe "#header_search" do
    it "searches a test's header paths, which leave out its generated directories" do
      testable = TestInvokerTypes::Testable.new( filepath: 'test/TestFoo.c', search_paths: ['mocks', 'mocks/drivers', 'src'] )
      allow(@test_search_paths).to receive(:header_paths).with( testable ).and_return( ['src'] )
      expect(@include_pathinator).to receive(:header_search).with( ['src'], refusals: {} ).and_return( :search )

      expect(@locator.header_search( testable )).to eq( :search )
    end

    it "explains a failed lookup by the test's search path refusals" do
      testable = TestInvokerTypes::Testable.new( filepath: 'test/TestFoo.c', search_path_refusals: { 'socket.h' => 'why' } )
      allow(@test_search_paths).to receive(:header_paths).with( testable ).and_return( ['src'] )
      expect(@include_pathinator).to receive(:header_search).with( ['src'], refusals: { 'socket.h' => 'why' } ).and_return( :search )

      expect(@locator.header_search( testable )).to eq( :search )
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
  # A test can name one header's mock two ways, as `MockTask.h` and `drivers/MockTask.h` both
  # do for src/drivers/task.h. CMock and the runner would make two mocks of it, which can't
  # both link.
  describe "#one_per_header" do
    def resolving(map)
      allow(@file_finder).to receive(:resolve_mock) { |query, **| map.fetch( query, [nil, nil] ) }
    end

    def kept(includes, from: nil)
      return @locator.one_per_header( includes, collection: [], from: from ).map(&:filepath)
    end

    it "keeps the mocks of two headers that share a name" do
      resolving( 'MockTask.h' => ['rtos/include/task.h', 'include'], 'other/MockTask.h' => ['rtos/other/task.h', 'other'] )

      expect(kept( [MockInclude.new('MockTask.h'), MockInclude.new('other/MockTask.h')] )).to eq( ['MockTask.h', 'other/MockTask.h'] )
    end

    # A pathless #include reaches the mock the one with more path names, but not the reverse
    it "keeps the #include with the most path of two that mock one header" do
      resolving( 'MockTask.h' => ['src/drivers/task.h', 'drivers'], 'drivers/MockTask.h' => ['src/drivers/task.h', 'drivers'] )

      expect(kept( [UserInclude.new('unity.h'), MockInclude.new('MockTask.h'), MockInclude.new('drivers/MockTask.h')] ))
        .to eq( ['unity.h', 'drivers/MockTask.h'] )
    end

    it "keeps the first of two #includes with as much path that mock one header" do
      resolving( 'drivers/MockTask.h' => ['src/drivers/task.h', 'drivers'], './drivers/MockTask.h' => ['src/drivers/task.h', 'drivers'] )

      expect(kept( [Include.new('drivers/MockTask.h'), Include.new('./drivers/MockTask.h')] )).to eq( ['drivers/MockTask.h'] )
    end

    it "keeps every mock whose header isn't found" do
      resolving( {} )

      expect(kept( [MockInclude.new('MockGone.h'), MockInclude.new('lost/MockGone.h')] )).to eq( ['MockGone.h', 'lost/MockGone.h'] )
    end

    it "looks a climbing #include up anchored to `from`, and keeps it as written" do
      resolving( 'x/MockFoo.h' => ['inc/x/foo.h', 'x'] )

      expect(kept( [Include.new('../x/MockFoo.h'), Include.new('x/MockFoo.h')], from: 'test' )).to eq( ['../x/MockFoo.h'] )
    end

    it "leaves Partial mocks and other headers alone" do
      expect(@file_finder).to_not receive(:resolve_mock)

      includes = [MockInclude.new("Mock#{PARTIAL_FILENAME_PREFIX}foo_interface.h"), UserInclude.new('task.h'), SystemInclude.new('MockSys.h')]
      expect(kept( includes )).to eq( includes.map(&:filepath) )
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

  # CMock includes a mock's real header by the folder it is given and the header's filename.
  # A search path listing the header's own directory joins no such folder.
  describe "#header_include and #header_respelling" do
    before(:each) do
      allow(@configurator).to receive(:get_cmock_config).and_return( {} )
    end

    def search_over(paths, headers)
      return HeaderSearch.new( paths, ->(dir) { headers.select { |header| File.expand_path( File.dirname( header ) ) == File.expand_path( dir ) } } )
    end

    it "keeps CMock's text where a search path joins the folder to the header" do
      search = search_over( ['src'], ['src/drivers/foo.h'] )

      expect(@locator.header_include( MockInclude.new( 'drivers/MockFoo.h' ), 'src/drivers/foo.h', search )).to eq( 'drivers/foo.h' )
      expect(@locator.header_respelling( MockInclude.new( 'drivers/MockFoo.h' ), 'src/drivers/foo.h', search )).to be_nil
    end

    it "takes the text the search paths reach the header by where none joins CMock's" do
      search = search_over( ['src/drivers'], ['src/drivers/foo.h'] )

      expect(@locator.header_include( MockInclude.new( 'drivers/MockFoo.h' ), 'src/drivers/foo.h', search )).to eq( 'foo.h' )
      expect(@locator.header_respelling( MockInclude.new( 'drivers/MockFoo.h' ), 'src/drivers/foo.h', search )).to eq( 'foo.h' )
    end

    # The compiler includes the same-named header CMock's text reaches, whichever header the
    # mock was located by
    it "keeps CMock's text where it reaches another same-named header" do
      search = search_over( ['lib', 'src/hw/drivers'], ['lib/drivers/foo.h', 'src/hw/drivers/foo.h'] )

      expect(@locator.header_respelling( MockInclude.new( 'drivers/MockFoo.h' ), 'src/hw/drivers/foo.h', search )).to be_nil
      expect(@locator.header_include( MockInclude.new( 'drivers/MockFoo.h' ), 'src/hw/drivers/foo.h', search )).to eq( 'drivers/foo.h' )
    end

    # A respelling is judged as the whole operand of the #include. CMock and a stand-in write
    # the format around their text. An FFF fake writes no format.
    it "keeps CMock's text where :orig_header_include_fmt writes more around it than quotes, respelling it for a fake" do
      allow(@configurator).to receive(:get_cmock_config).and_return( { orig_header_include_fmt: '#include "../%s"' } )
      search = search_over( ['src/drivers'], ['src/drivers/foo.h'] )

      expect(@locator.header_include( MockInclude.new( 'drivers/MockFoo.h' ), 'src/drivers/foo.h', search )).to eq( 'drivers/foo.h' )
      expect(@locator.header_respelling( MockInclude.new( 'drivers/MockFoo.h' ), 'src/drivers/foo.h', search )).to eq( 'foo.h' )
    end

    it "respells within a bracketed :orig_header_include_fmt" do
      allow(@configurator).to receive(:get_cmock_config).and_return( { orig_header_include_fmt: '#include <%s>' } )
      search = search_over( ['src/drivers'], ['src/drivers/foo.h'] )

      expect(@locator.header_respelling( MockInclude.new( 'drivers/MockFoo.h' ), 'src/drivers/foo.h', search )).to eq( 'foo.h' )
    end

    it "keeps CMock's text where nothing reaches the header" do
      search = search_over( ['inc'], ['src/drivers/foo.h'] )

      expect(@locator.header_include( MockInclude.new( 'drivers/MockFoo.h' ), 'src/drivers/foo.h', search )).to eq( 'drivers/foo.h' )
      expect(@locator.header_respelling( MockInclude.new( 'drivers/MockFoo.h' ), 'src/drivers/foo.h', search )).to be_nil
    end

    it "includes the header by its filename for a bare #include" do
      search = search_over( ['src/drivers'], ['src/drivers/foo.h'] )

      expect(@locator.header_include( MockInclude.new( 'MockFoo.h' ), 'src/drivers/foo.h', search )).to eq( 'foo.h' )
      expect(@locator.header_respelling( MockInclude.new( 'MockFoo.h' ), 'src/drivers/foo.h', search )).to be_nil
    end

    it "drops a leading ./ from the folder, as CMock is given it" do
      search = search_over( ['src'], ['src/drivers/foo.h'] )

      expect(@locator.header_include( MockInclude.new( './drivers/MockFoo.h' ), 'src/drivers/foo.h', search )).to eq( 'drivers/foo.h' )
    end

    it "includes by the filename CMock writes, and respells nothing, when :mock_name_include_folder is disabled" do
      allow(@configurator).to receive(:cmock_mock_name_include_folder).and_return( false )
      search = search_over( ['src/drivers'], ['src/drivers/foo.h'] )

      expect(@locator.header_include( MockInclude.new( 'drivers/MockFoo.h' ), 'src/drivers/foo.h', search )).to eq( 'foo.h' )
      expect(@locator.header_respelling( MockInclude.new( 'drivers/MockFoo.h' ), 'src/drivers/foo.h', search )).to be_nil
    end

    # A Partial mock's header is Ceedling's own, generated where no search path for real headers looks
    it "respells nothing for a Partial mock" do
      header = 'build/test/partials/t/ceedling_partial_foo_interface.h'
      search = search_over( ['.'], [header] )

      expect(@locator.header_respelling( MockInclude.new( "Mock#{PARTIAL_FILENAME_PREFIX}foo_interface.h" ), header, search )).to be_nil
    end

    # The compiler joins a climbing folder as written, which a search can't judge
    it "keeps CMock's text for a folder that climbs" do
      search = search_over( ['inc/x'], ['inc/x/foo.h'] )

      expect(@locator.header_respelling( MockInclude.new( '../x/MockFoo.h' ), 'inc/x/foo.h', search )).to be_nil
      expect(@locator.header_include( MockInclude.new( '../x/MockFoo.h' ), 'inc/x/foo.h', search )).to eq( '../x/foo.h' )
    end
  end

  describe "#respellable_format?" do
    it "takes a respelling into a format whose text is the whole operand" do
      [nil, '#include "%s"', '#include <%s>', '  #  include "%s"  '].each do |format|
        allow(@configurator).to receive(:get_cmock_config).and_return( { orig_header_include_fmt: format }.compact )

        expect(@locator.respellable_format?).to be( true ), format.inspect
      end
    end

    it "takes no respelling into a format that writes more around the text" do
      ['#include "../%s"', '#include "inc/%s"', '#include "%s" /* mock */'].each do |format|
        allow(@configurator).to receive(:get_cmock_config).and_return( { orig_header_include_fmt: format } )

        expect(@locator.respellable_format?).to be( false ), format
      end
    end
  end

  describe "#header_include_line" do
    it "puts the text in CMock's default #include" do
      allow(@configurator).to receive(:get_cmock_config).and_return( {} )

      expect(@locator.header_include_line( 'drivers/foo.h' )).to eq( '#include "drivers/foo.h"' )
    end

    it "puts the text in the project's CMock :orig_header_include_fmt" do
      allow(@configurator).to receive(:get_cmock_config).and_return( { orig_header_include_fmt: '#include <%s>' } )

      expect(@locator.header_include_line( 'foo.h' )).to eq( '#include <foo.h>' )
    end
  end
end
