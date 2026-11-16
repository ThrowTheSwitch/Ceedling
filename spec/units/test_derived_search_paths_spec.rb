# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/constants'
require 'ceedling/filename_extension'
require 'ceedling/includes/includes'
require 'ceedling/includes/include_pathinator'
require 'ceedling/filesystem/file_finder'
require 'ceedling/test_invoker/test_invoker_types'
require 'ceedling/test_invoker/test_derived_search_paths'

describe TestDerivedSearchPaths do
  before(:each) do
    @configurator = double( "Configurator", cmock_mock_prefix: 'mock_', cmock_mock_name_include_folder: true, project_build_root: 'build' )
    allow(@configurator).to receive(:extension_header).and_return( FilenameExtension.new( '.h' ) )
    @extractor    = double( "TestContextExtractor" )
    @file_wrapper = double( "FileWrapper" )
    @loginator    = double( "Loginator" )
    @search_paths = double( "TestSearchPaths" )
    allow(@loginator).to receive(:log)

    # The project's headers on disk, listed a directory at a time
    @tree = []
    allow(@file_wrapper).to receive(:directory_listing) do |patterns|
      dir = File.dirname( patterns.first ).delete_prefix( './' )
      @tree.select { |header| File.dirname( header ) == dir }.sort
    end
    allow(@file_wrapper).to receive(:exist?) { |path| @tree.include?( path ) }

    @collection = []
    allow(@configurator).to receive(:collection_all_headers) { @collection }

    pathinator = IncludePathinator.new( configurator: @configurator, test_context_extractor: @extractor, loginator: @loginator, file_wrapper: @file_wrapper )
    pathinator.setup
    finder = FileFinder.new( configurator: @configurator, file_finder_helper: nil, file_path_utils: nil, file_wrapper: @file_wrapper, yaml_wrapper: nil )

    @derived = described_class.new(
      configurator: @configurator, include_pathinator: pathinator, test_search_paths: @search_paths,
      test_context_extractor: @extractor, file_finder: finder, file_wrapper: @file_wrapper, loginator: @loginator
    )
    @derived.setup

    @testable = TestInvokerTypes::Testable.new( name: 'test_it', filepath: 'test/test_it.c' )
  end

  # `paths` are the test's search paths, `headers` the headers on disk, `files` the
  # project's header collection, and `includes` the test's #includes
  def derive(paths:, includes:, headers: ['src/path/to/sensor.h'], files: headers)
    @tree       = headers
    @collection = files
    allow(@search_paths).to receive(:header_paths).with( @testable ).and_return( paths )
    allow(@extractor).to receive(:lookup_all_header_includes_list).with( 'test/test_it.c' ).and_return( includes )

    return @derived.collect( @testable )
  end

  def mock(path)
    return MockInclude.new( path )
  end

  describe "#collect" do
    it "adds a bare mock's header's own directory" do
      expect(derive( paths: ['.'], includes: [mock( 'mock_sensor.h' )] )).to eq( ['src/path/to'] )
    end

    it "says which search path it added, for which test, and why" do
      expect(@loginator).to receive(:log).with(
        "Added search path 'src/path/to' for test/test_it.c after every configured search path, so \"sensor.h\" reaches src/path/to/sensor.h.",
        Verbosity::COMPLAIN, LogLabels::NOTICE
      )

      derive( paths: ['.'], includes: [mock( 'mock_sensor.h' )] )
    end

    it "adds nothing for a mock whose #include a search path already joins to its header" do
      expect(@loginator).to_not receive(:log)

      expect(derive( paths: ['.'], includes: [mock( 'src/path/to/mock_sensor.h' )] )).to eq( [] )
    end

    it "adds the directory a mock's folder is measured from" do
      expect(derive( paths: ['inc'], includes: [mock( 'path/to/mock_sensor.h' )] )).to eq( ['src'] )
    end

    it "adds the project root for a mock's folder that spells the header's whole path" do
      expect(derive( paths: ['inc'], includes: [mock( 'src/path/to/mock_sensor.h' )] )).to eq( ['.'] )
    end

    # The compiler can't join `src` with "src/path/to/sensor.h", though the header lies below it
    it "adds the directory a mock's folder is measured from when that folder starts at a search path" do
      expect(derive( paths: ['src'], includes: [mock( 'src/path/to/mock_sensor.h' )] )).to eq( ['.'] )
    end

    it "adds the header's own directory for a mock named without its folder" do
      allow(@configurator).to receive(:cmock_mock_name_include_folder).and_return( false )

      expect(derive( paths: ['inc'], includes: [mock( 'path/to/mock_sensor.h' )] )).to eq( ['src/path/to'] )
    end

    it "adds the directory a plain #include implies" do
      expect(derive( paths: ['.'], includes: [UserInclude.new( 'sensor.h' )] )).to eq( ['src/path/to'] )
    end

    # A quoted #include looks in its own file's directory first
    it "adds nothing for a plain #include the test file's own directory reaches" do
      expect(derive( paths: ['.'], includes: [UserInclude.new( 'local.h' )], headers: ['test/local.h'], files: [] )).to eq( [] )
    end

    it "adds nothing for a header no collection holds" do
      expect(derive( paths: ['.'], includes: [mock( 'mock_sensor.h' )], files: [] )).to eq( [] )
    end

    # The compiler rejects such an #include, and so does Ceedling
    it "adds nothing for a header whose own directory is a search path" do
      expect(derive( paths: ['src'], includes: [UserInclude.new( 'src/x.h' )], headers: ['src/x.h'] )).to eq( [] )
    end

    it "adds a directory once, which later #includes reach headers through" do
      headers = ['src/path/to/sensor.h', 'src/path/to/sensor_types.h']

      expect(derive( paths: ['.'], includes: [mock( 'mock_sensor.h' ), UserInclude.new( 'sensor_types.h' )], headers: headers )).to eq( ['src/path/to'] )
    end

    it "finds a header through a TEST_INCLUDE_PATH() directory before the collection" do
      headers = ['tip/sensor.h', 'src/path/to/sensor.h']

      expect(derive( paths: ['tip', '.'], includes: [mock( 'mock_sensor.h' )], headers: headers )).to eq( [] )
    end

    it "adds nothing for a header below the build root" do
      expect(derive( paths: ['.'], includes: [UserInclude.new( 'gen.h' )], headers: ['build/gen/gen.h'] )).to eq( [] )
    end

    it "skips system, Unity, Ceedling and Partial #includes, Partial mocks, and paths that climb or are absolute" do
      includes = [
        SystemInclude.new( 'sensor.h' ), UserInclude.new( 'unity.h' ), UserInclude.new( 'ceedling.h' ),
        UserInclude.new( 'ceedling_partial_sensor.h' ), mock( 'mock_ceedling_partial_sensor.h' ),
        UserInclude.new( '../src/path/to/sensor.h' ).anchored( 'test' ), UserInclude.new( '/abs/sensor.h' )
      ]
      headers = ['src/path/to/sensor.h', 'src/path/to/unity.h', 'src/path/to/ceedling.h', 'src/path/to/ceedling_partial_sensor.h', '/abs/sensor.h']

      expect(derive( paths: ['inc'], includes: includes, headers: headers )).to eq( [] )
    end

    context "for a header outside the project" do
      let(:socket) { '/usr/include/x86_64-linux-gnu/sys/socket.h' }

      it "adds the directory a mock's folder is measured from" do
        expect(derive( paths: ['inc'], includes: [mock( 'sys/mock_socket.h' )], headers: [socket] )).to eq( ['/usr/include/x86_64-linux-gnu'] )
      end

      it "names the option a mock without its folder needs, rather than a folder alone" do
        allow(@configurator).to receive(:cmock_mock_name_include_folder).and_return( false )
        expect(@loginator).to receive(:log).once.with(
          "#include \"sys/mock_socket.h\" in test/test_it.c names #{socket}, outside the project. " \
          "With :cmock ↳ :mock_name_include_folder disabled, its mock includes it by bare name, and Ceedling adds no search path " \
          "for a bare name there. Enable that option to include it by its folder, as in \"sys/mock_socket.h\".",
          Verbosity::COMPLAIN, LogLabels::NOTICE
        )

        expect(derive( paths: ['inc'], includes: [mock( 'sys/mock_socket.h' )], headers: [socket] )).to eq( [] )
      end

      it "adds nothing for a bare name, naming the #include that would reach it once" do
        expect(@loginator).to receive(:log).once.with(
          "#include \"mock_socket.h\" in test/test_it.c names #{socket}, outside the project. " \
          "Ceedling adds no search path for a bare name there. Include it by its path below an include directory, as in \"sys/mock_socket.h\".",
          Verbosity::COMPLAIN, LogLabels::NOTICE
        )

        2.times { expect(derive( paths: ['inc'], includes: [mock( 'mock_socket.h' )], headers: [socket] )).to eq( [] ) }
      end
    end
  end
end
