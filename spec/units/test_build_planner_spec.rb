# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'rake'
require 'ceedling/filename_extension'
require 'ceedling/test_invoker/test_build_planner'
require 'ceedling/test_invoker/test_invoker_types'
require 'ceedling/includes/includes'
require 'ceedling/partials/partializer_config'

PROJECT_BUILD_VENDOR_UNITY_PATH      = 'build/vendor/unity'      unless defined?(PROJECT_BUILD_VENDOR_UNITY_PATH)
PROJECT_BUILD_VENDOR_CMOCK_PATH      = 'build/vendor/cmock'      unless defined?(PROJECT_BUILD_VENDOR_CMOCK_PATH)
PROJECT_BUILD_VENDOR_CEXCEPTION_PATH = 'build/vendor/cexception' unless defined?(PROJECT_BUILD_VENDOR_CEXCEPTION_PATH)
CMOCK_MOCK_PREFIX      = 'Mock'                       unless defined?(CMOCK_MOCK_PREFIX)
COLLECTION_ALL_SUPPORT = []                           unless defined?(COLLECTION_ALL_SUPPORT)
EXTENSION_SOURCE       = FilenameExtension.new('.c')  unless defined?(EXTENSION_SOURCE)
EXTENSION_HEADER       = FilenameExtension.new('.h')  unless defined?(EXTENSION_HEADER)

describe TestBuildPlanner do
  before(:each) do
    @configurator           = double( "Configurator" )
    @loginator               = double( "Loginator" )
    @reportinator             = double( "Reportinator" )
    @batchinator               = double( "Batchinator" )
    @test_context_extractor     = double( "TestContextExtractor" )
    @include_pathinator          = double( "IncludePathinator" )
    @partializer                 = double( "Partializer" )
    @file_finder                   = double( "FileFinder" )
    @file_path_utils                 = double( "FilePathUtils" )
    @file_wrapper                     = double( "FileWrapper" )
    @plugin_manager                     = double( "PluginManager" )
    @test_source_file_directive_resolver   = double( "TestSourceFileDirectiveResolver" )

    allow(@batchinator).to receive(:exec) do |workload:, things:, &block|
      things.each { |k, v| block.call(k, v) }
    end

    # Harmless default -- individual examples needing a specific ordered header
    # collection stub this again with a narrower `.with(...)` match.
    allow(@include_pathinator).to receive(:ordered_header_files).and_return( [] )
    allow(@loginator).to receive(:log)

    # Harmless default for #extract_sources examples that don't care about
    # TEST_SOURCE_FILE() directives at all -- no additive or subtractive
    # entries, and the final list passes through remove_subtracted untouched.
    allow(@test_source_file_directive_resolver).to receive(:resolve).and_return( [[], {}] )
    allow(@test_source_file_directive_resolver).to receive(:remove_subtracted) do |sources, subtractive:, test_filepath:|
      sources - subtractive.keys
    end

    @planner = described_class.new(
      {
        :configurator           => @configurator,
        :loginator              => @loginator,
        :reportinator           => @reportinator,
        :batchinator            => @batchinator,
        :test_context_extractor => @test_context_extractor,
        :include_pathinator     => @include_pathinator,
        :partializer            => @partializer,
        :file_finder            => @file_finder,
        :file_path_utils        => @file_path_utils,
        :file_wrapper           => @file_wrapper,
        :plugin_manager         => @plugin_manager,
        :test_source_file_directive_resolver => @test_source_file_directive_resolver
      }
    )

    @testable = TestInvokerTypes::Testable.new(
      :name         => 'a_test',
      :filepath     => 'test/TestFoo.c',
      :paths        => { :build => 'build/test/out/a_test', :results => 'build/test/results/a_test' },
      :mocks        => {},
      :search_paths => []
    )
    @state = TestInvokerTypes::PipelineState.new(
      :testables => { :a_test => @testable }, :context => :test, :options => [], :lock => Mutex.new
    )
  end

  describe "#stage_determine_files" do
    before(:each) do
      allow(@file_path_utils).to receive(:form_runner_filepath_from_test)
        .with( 'test/TestFoo.c', name: 'a_test' ).and_return( 'build/test/runners/a_test/TestFoo_runner.c' )
      allow(@test_context_extractor).to receive(:lookup_mock_header_includes_list)
        .with( 'test/TestFoo.c' ).and_return( [] )
      allow(@test_context_extractor).to receive(:lookup_nonmock_header_includes_list)
        .with( 'test/TestFoo.c' ).and_return( [] )
      allow(@configurator).to receive(:project_use_partials).and_return( false )
      allow(@plugin_manager).to receive(:pre_test)
    end

    it "builds this test's runner info and an empty mocks hash when it has no mocks" do
      @planner.stage_determine_files( @state )

      expect(@testable.runner).to eq(
        TestInvokerTypes::RunnerInfo.new(
          output_filepath: 'build/test/runners/a_test/TestFoo_runner.c',
          input_filepath:  'test/TestFoo.c'
        )
      )
      expect(@testable.mocks).to eq({})
    end

    it "notifies the plugin manager that this test file has been planned" do
      expect(@plugin_manager).to receive(:pre_test).with( 'test/TestFoo.c' )

      @planner.stage_determine_files( @state )
    end

    it "skips Partials config assembly when the project has Partials disabled" do
      expect(@test_context_extractor).to_not receive(:lookup_partials_config)

      @planner.stage_determine_files( @state )

      expect(@testable.partials.configs).to eq({})
    end

    context "when the project has Partials enabled" do
      before(:each) do
        allow(@configurator).to receive(:project_use_partials).and_return( true )
      end

      it "assembles and stores this test file's Partials configuration" do
        configs = { 'Foo' => double( "Config" ) }
        allow(@test_context_extractor).to receive(:lookup_partials_config)
          .with( 'test/TestFoo.c' ).and_return( configs )
        allow(@partializer).to receive(:populate_filepaths).with( configs ).and_return( configs )

        @planner.stage_determine_files( @state )

        expect(@testable.partials.configs).to eq( configs )
      end
    end

    context "with a non-Partial mocked header" do
      before(:each) do
        mock = MockInclude.new( 'MockFoo.h' )
        allow(@test_context_extractor).to receive(:lookup_mock_header_includes_list)
          .with( 'test/TestFoo.c' ).and_return( [mock] )
        allow(@configurator).to receive(:cmock_mock_prefix).and_return( 'Mock' )
        allow(@file_finder).to receive(:resolve_mock)
          .with( 'MockFoo.h', collection: [] ).and_return( ['src/drivers/foo.h', 'drivers'] )
        allow(@file_path_utils).to receive(:form_preprocessed_file_filepath)
          .with( 'src/drivers/foo.h', 'a_test' ).and_return( 'build/test/preprocess/files/a_test/full_expansion/foo.h' )
      end

      it "resolves the mock's real header and mirrored subdirectory, using the raw source as input when mock preprocessing is disabled" do
        allow(@configurator).to receive(:project_use_test_preprocessor_mocks).and_return( false )

        @planner.stage_determine_files( @state )

        expect(@testable.mocks[:MockFoo]).to eq(
          TestInvokerTypes::MockDetails.new(
            name:     'MockFoo',
            filepath: 'src/drivers/foo.h',
            path:     'drivers',
            source:   'src/drivers/foo.h',
            input:    'src/drivers/foo.h'
          )
        )
      end

      it "uses the preprocessed file as input when mock preprocessing is enabled" do
        allow(@configurator).to receive(:project_use_test_preprocessor_mocks).and_return( true )

        @planner.stage_determine_files( @state )

        expect(@testable.mocks[:MockFoo].input).to eq( 'build/test/preprocess/files/a_test/full_expansion/foo.h' )
      end
    end

    context "with a Partial mocked header" do
      before(:each) do
        mock = MockInclude.new( 'Mockceedling_partial_foo_interface.h' )
        allow(@test_context_extractor).to receive(:lookup_mock_header_includes_list)
          .with( 'test/TestFoo.c' ).and_return( [mock] )
        allow(@configurator).to receive(:cmock_mock_prefix).and_return( 'Mock' )
        allow(@file_path_utils).to receive(:form_partial_header_filepath)
          .with( 'a_test', 'ceedling_partial_foo_interface.h' )
          .and_return( 'build/test/partials/a_test/ceedling_partial_foo_interface.h' )
      end

      it "has no real header to resolve against -- it stays flat, with no mirrored subdirectory" do
        expect(@file_finder).to_not receive(:resolve_mock)

        @planner.stage_determine_files( @state )

        expect(@testable.mocks[:Mockceedling_partial_foo_interface]).to eq(
          TestInvokerTypes::MockDetails.new(
            name:     'Mockceedling_partial_foo_interface',
            filepath: 'build/test/partials/a_test/ceedling_partial_foo_interface.h',
            path:     '',
            source:   'build/test/partials/a_test/ceedling_partial_foo_interface.h',
            input:    'build/test/partials/a_test/ceedling_partial_foo_interface.h'
          )
        )
      end
    end
  end

  describe "#stage_flatten_partials_lists" do
    before(:each) do
      @state.partials_headers = []
      @state.partials_sources = []
    end

    it "adds a partials_headers entry only when the config's header has a resolved filepath" do
      header = Partials::ConfigFileInfo.new( filepath: 'src/Foo.h' )
      config = PartializerConfig::Config.new( module: 'Foo', header: header )
      @testable.partials.configs = { 'Foo' => config }

      @planner.stage_flatten_partials_lists( @state )

      expect(@state.partials_headers).to eq(
        [TestInvokerTypes::PartialWork.new( config: header, testable: @testable, directives_only_filepath: nil )]
      )
      expect(@state.partials_sources).to eq( [] )
    end

    it "adds a partials_sources entry only when the config's source has a resolved filepath" do
      source = Partials::ConfigFileInfo.new( filepath: 'src/Foo.c' )
      config = PartializerConfig::Config.new( module: 'Foo', source: source )
      @testable.partials.configs = { 'Foo' => config }

      @planner.stage_flatten_partials_lists( @state )

      expect(@state.partials_sources).to eq(
        [TestInvokerTypes::PartialWork.new( config: source, testable: @testable, directives_only_filepath: nil )]
      )
      expect(@state.partials_headers).to eq( [] )
    end

    it "adds neither when a config has no resolved header or source filepath yet" do
      config = PartializerConfig::Config.new( module: 'Foo' )
      @testable.partials.configs = { 'Foo' => config }

      @planner.stage_flatten_partials_lists( @state )

      expect(@state.partials_headers).to eq( [] )
      expect(@state.partials_sources).to eq( [] )
    end
  end

  describe "#stage_flatten_mocks_list" do
    before(:each) do
      @state.mocks_list = []
    end

    it "flattens this testable's mocks into one parallel-processing-friendly list" do
      @testable.mocks = {
        MockFoo: TestInvokerTypes::MockDetails.new(
          name: 'MockFoo', filepath: 'src/foo.h', path: '', source: 'src/foo.h', input: 'src/foo.h'
        )
      }

      @planner.stage_flatten_mocks_list( @state )

      expect(@state.mocks_list).to eq(
        [TestInvokerTypes::MockWork.new(
          name: :MockFoo, details: @testable.mocks[:MockFoo], testable: @testable, directives_only_filepath: nil
        )]
      )
    end

    it "flattens mocks across every testable into a single list" do
      other = TestInvokerTypes::Testable.new(
        name: 'b_test', filepath: 'test/TestBar.c',
        mocks: { MockBar: TestInvokerTypes::MockDetails.new( name: 'MockBar' ) }
      )
      @testable.mocks = { MockFoo: TestInvokerTypes::MockDetails.new( name: 'MockFoo' ) }
      @state.testables[:b_test] = other

      @planner.stage_flatten_mocks_list( @state )

      expect(@state.mocks_list.map { |m| m.name }).to contain_exactly( :MockFoo, :MockBar )
    end
  end

  describe "#stage_determine_artifacts" do
    before(:each) do
      allow(@test_context_extractor).to receive(:lookup_mock_header_includes_list)
        .with( 'test/TestFoo.c' ).and_return( [] )
      allow(@test_context_extractor).to receive(:lookup_build_directive_sources_list)
        .with( 'test/TestFoo.c' ).and_return( [] )
      allow(@test_context_extractor).to receive(:lookup_all_header_includes_list)
        .with( 'test/TestFoo.c' ).and_return( [] )
      allow(@test_context_extractor).to receive(:lookup_source_includes_list)
        .with( 'test/TestFoo.c' ).and_return( [] )
      allow(@configurator).to receive(:project_use_mocks).and_return( false )
      allow(@configurator).to receive(:project_use_exceptions).and_return( false )
      allow(@configurator).to receive(:collection_all_support).and_return( [] )
      allow(@configurator).to receive(:cmock_unity_helper_path).and_return( [] )
      allow(@configurator).to receive(:cmock_mock_prefix).and_return( 'Mock' )

      @testable.runner = TestInvokerTypes::RunnerInfo.new(
        output_filepath: 'build/test/runners/a_test/TestFoo_runner.c', input_filepath: 'test/TestFoo.c'
      )

      allow(@file_path_utils).to receive(:form_test_build_objects_filelist) do |_build_path, files|
        files.map { |f| f.ext( '.o' ) }
      end
      allow(@file_path_utils).to receive(:form_test_executable_filepath).and_return( 'build/test/out/a_test/TestFoo.exe' )
      allow(@file_path_utils).to receive(:form_pass_results_filepath).and_return( 'build/test/results/a_test/TestFoo.pass' )
    end

    it "resolves this test's sources, framework files, executable, and results paths" do
      @planner.stage_determine_artifacts( @state )

      expect(@testable.sources).to eq( [] )
      expect(@testable.frameworks).to eq( [File.join( PROJECT_BUILD_VENDOR_UNITY_PATH, UNITY_C_FILE )] )
      expect(@testable.executable).to eq( 'build/test/out/a_test/TestFoo.exe' )
      expect(@testable.results_pass).to eq( 'build/test/results/a_test/TestFoo.pass' )
    end

    it "includes the runner's own generated source among the compiled objects" do
      @planner.stage_determine_artifacts( @state )

      expect(@testable.objects).to include( 'build/test/runners/a_test/TestFoo_runner.o' )
    end

    context "with a mocked header whose real source would otherwise also be compiled" do
      before(:each) do
        mock = MockInclude.new( 'MockFoo.h' )
        allow(@test_context_extractor).to receive(:lookup_mock_header_includes_list)
          .with( 'test/TestFoo.c' ).and_return( [mock] )
        allow(@configurator).to receive(:project_use_mocks).and_return( true )
        allow(@test_context_extractor).to receive(:lookup_build_directive_sources_list)
          .with( 'test/TestFoo.c' ).and_return( ['Foo'] )
        allow(@file_finder).to receive(:find_build_input_file)
          .with( filepath: 'Foo', complain: :ignore, context: :test ).and_return( 'src/Foo.c' )
        @testable.mocks = { MockFoo: TestInvokerTypes::MockDetails.new( name: 'MockFoo' ) }
      end

      it "compiles the mock's generated core source instead of the real header's own source file" do
        @planner.stage_determine_artifacts( @state )

        expect(@testable.core).to include( 'MockFoo.c' )
        expect(@testable.core).to_not include( 'src/Foo.c' )
      end
    end

    context "when a build-directive source is also a shallow-included source" do
      before(:each) do
        allow(@test_source_file_directive_resolver).to receive(:resolve)
          .with( 'test/TestFoo.c', :test ).and_return( [['src/Foo.c'], {}] )
        allow(@test_context_extractor).to receive(:lookup_source_includes_list)
          .with( 'test/TestFoo.c' ).and_return( ['src/Foo.c'] )
      end

      it "resolves it as a source to compile but excludes its object from what gets linked" do
        @planner.stage_determine_artifacts( @state )

        expect(@testable.sources).to include( 'src/Foo.c' )
        expect(@testable.objects).to_not include( 'src/Foo.o' )
      end
    end
  end

  describe "#stage_flatten_objects_list" do
    it "flattens every testable's objects into one parallel-processing-friendly list" do
      @testable.objects = ['build/test/out/a_test/TestFoo.o', 'build/test/out/a_test/Foo.o']
      other = TestInvokerTypes::Testable.new(
        name: 'b_test', filepath: 'test/TestBar.c', objects: ['build/test/out/b_test/TestBar.o']
      )
      @state.testables[:b_test] = other

      @planner.stage_flatten_objects_list( @state )

      expect(@state.objects_list).to contain_exactly(
        { test: 'a_test', obj: 'build/test/out/a_test/TestFoo.o' },
        { test: 'a_test', obj: 'build/test/out/a_test/Foo.o' },
        { test: 'b_test', obj: 'build/test/out/b_test/TestBar.o' }
      )
    end
  end

  describe "#is_mock_partial?" do
    before(:each) do
      allow(@configurator).to receive(:cmock_mock_prefix).and_return( 'Mock' )
    end

    it "is true for a mock whose filename carries the Partial prefix after the mock prefix" do
      mock = MockInclude.new( 'Mockceedling_partial_foo_interface.h' )
      expect(@planner.is_mock_partial?( mock )).to be true
    end

    it "is false for an ordinary mock" do
      mock = MockInclude.new( 'MockFoo.h' )
      expect(@planner.is_mock_partial?( mock )).to be false
    end
  end

  describe "#validate_header_includes" do
    it "skips system headers" do
      allow(@test_context_extractor).to receive(:lookup_nonmock_header_includes_list)
        .with( 'test/TestFoo.c' ).and_return( [SystemInclude.new('stdio.h')] )
      expect(@file_finder).to_not receive(:find_header_file)

      @planner.validate_header_includes( 'test/TestFoo.c', @testable )
    end

    it "skips Unity's own header" do
      allow(@test_context_extractor).to receive(:lookup_nonmock_header_includes_list)
        .with( 'test/TestFoo.c' ).and_return( [UserInclude.new('unity.h')] )
      expect(@file_finder).to_not receive(:find_header_file)

      @planner.validate_header_includes( 'test/TestFoo.c', @testable )
    end

    it "skips Ceedling's own Partials support header" do
      allow(@test_context_extractor).to receive(:lookup_nonmock_header_includes_list)
        .with( 'test/TestFoo.c' ).and_return( [UserInclude.new('ceedling.h')] )
      expect(@file_finder).to_not receive(:find_header_file)

      @planner.validate_header_includes( 'test/TestFoo.c', @testable )
    end

    it "skips a Partial's own generated header" do
      allow(@test_context_extractor).to receive(:lookup_nonmock_header_includes_list)
        .with( 'test/TestFoo.c' ).and_return( [UserInclude.new('ceedling_partial_foo_interface.h')] )
      expect(@file_finder).to_not receive(:find_header_file)

      @planner.validate_header_includes( 'test/TestFoo.c', @testable )
    end

    it "resolves an ordinary header against this test's own ordered search-path header collection, hard-erroring only on no match" do
      allow(@test_context_extractor).to receive(:lookup_nonmock_header_includes_list)
        .with( 'test/TestFoo.c' ).and_return( [UserInclude.new('drivers/foo.h')] )
      @testable.search_paths = ['inc', 'src']
      allow(@include_pathinator).to receive(:ordered_header_files)
        .with( ['inc', 'src'] ).and_return( ['inc/drivers/foo.h'] )

      expect(@file_finder).to receive(:find_header_file).with( 'drivers/foo.h', :error, collection: ['inc/drivers/foo.h'] )

      @planner.validate_header_includes( 'test/TestFoo.c', @testable )
    end
  end

  describe "#remove_mock_original_headers" do
    before(:each) do
      allow(@configurator).to receive(:cmock_mock_prefix).and_return( 'Mock' )
    end

    it "removes a source file whose corresponding header is mocked" do
      filelist = ['src/Foo.c', 'src/Bar.c']

      @planner.remove_mock_original_headers( filelist, ['MockFoo.h'] )

      expect(filelist).to eq( ['src/Bar.c'] )
    end

    it "leaves the list untouched when none of its files correspond to a mocked header" do
      filelist = ['src/Bar.c']

      @planner.remove_mock_original_headers( filelist, ['MockFoo.h'] )

      expect(filelist).to eq( ['src/Bar.c'] )
    end
  end

  describe "#remove_partials_source_objects" do
    it "removes an object whose basename matches a Partial module name" do
      objects = ['build/test/out/a_test/Foo.o', 'build/test/out/a_test/Bar.o']

      @planner.remove_partials_source_objects( objects, { 'Foo' => double( "Config" ) } )

      expect(objects).to eq( ['build/test/out/a_test/Bar.o'] )
    end

    it "leaves the list untouched when no object matches a Partial module name" do
      objects = ['build/test/out/a_test/Bar.o']

      @planner.remove_partials_source_objects( objects, { 'Foo' => double( "Config" ) } )

      expect(objects).to eq( ['build/test/out/a_test/Bar.o'] )
    end
  end

  describe "#collect_test_framework_sources" do
    before(:each) do
      allow(@configurator).to receive(:project_use_exceptions).and_return( false )
      allow(@configurator).to receive(:cmock_unity_helper_path).and_return( [] )
      allow(@configurator).to receive(:project_use_mocks).and_return( false )
    end

    it "always includes Unity's own source" do
      result = @planner.collect_test_framework_sources( false )

      expect(result).to eq( [File.join( PROJECT_BUILD_VENDOR_UNITY_PATH, UNITY_C_FILE )] )
    end

    it "includes CMock's own source only when the project uses mocks and this test has any" do
      allow(@configurator).to receive(:project_use_mocks).and_return( true )

      result = @planner.collect_test_framework_sources( true )

      expect(result).to include( File.join( PROJECT_BUILD_VENDOR_CMOCK_PATH, CMOCK_C_FILE ) )
    end

    it "omits CMock's source when this test has no mocks even though the project supports them" do
      allow(@configurator).to receive(:project_use_mocks).and_return( true )

      result = @planner.collect_test_framework_sources( false )

      expect(result).to_not include( File.join( PROJECT_BUILD_VENDOR_CMOCK_PATH, CMOCK_C_FILE ) )
    end

    it "includes CException's source when the project uses exceptions" do
      allow(@configurator).to receive(:project_use_exceptions).and_return( true )

      result = @planner.collect_test_framework_sources( false )

      expect(result).to include( File.join( PROJECT_BUILD_VENDOR_CEXCEPTION_PATH, CEXCEPTION_C_FILE ) )
    end

    it "includes an existing Unity helper source file" do
      allow(@configurator).to receive(:project_use_mocks).and_return( true )
      allow(@configurator).to receive(:cmock_unity_helper_path).and_return( ['test/support/unity_helper'] )
      allow(@file_wrapper).to receive(:exist?).with( 'test/support/unity_helper.c' ).and_return( true )

      result = @planner.collect_test_framework_sources( true )

      expect(result).to include( 'test/support/unity_helper' )
    end

    it "omits a Unity helper source file that doesn't exist on disk" do
      allow(@configurator).to receive(:project_use_mocks).and_return( true )
      allow(@configurator).to receive(:cmock_unity_helper_path).and_return( ['test/support/unity_helper'] )
      allow(@file_wrapper).to receive(:exist?).with( 'test/support/unity_helper.c' ).and_return( false )

      result = @planner.collect_test_framework_sources( true )

      expect(result).to_not include( 'test/support/unity_helper' )
    end
  end

  describe "#extract_sources" do
    before(:each) do
      allow(@configurator).to receive(:collection_all_support).and_return( [] )
    end

    it "includes the additive build-directive sources the resolver returns" do
      allow(@test_source_file_directive_resolver).to receive(:resolve)
        .with( 'test/TestFoo.c', :test ).and_return( [['src/Foo.c'], {}] )
      allow(@test_context_extractor).to receive(:lookup_all_header_includes_list)
        .with( 'test/TestFoo.c' ).and_return( [] )

      result = @planner.extract_sources( :test, 'test/TestFoo.c', @testable.partials )

      expect(result).to eq( ['src/Foo.c'] )
    end

    it "resolves each header #include's own source file, skipping Unity, mocks, and support headers" do
      allow(@test_context_extractor).to receive(:lookup_all_header_includes_list)
        .with( 'test/TestFoo.c' ).and_return(
          [UserInclude.new('unity.h'), MockInclude.new('MockFoo.h'), UserInclude.new('drivers/bar.h')]
        )
      allow(@file_finder).to receive(:find_build_input_file)
        .with( filepath: 'drivers/bar.h', complain: :ignore, context: :test ).and_return( 'src/drivers/bar.c' )

      result = @planner.extract_sources( :test, 'test/TestFoo.c', @testable.partials )

      expect(result).to eq( ['src/drivers/bar.c'] )
    end

    it "includes testable Partials' own generated sources, but not mock Partials" do
      allow(@test_context_extractor).to receive(:lookup_all_header_includes_list)
        .with( 'test/TestFoo.c' ).and_return( [] )
      @testable.partials.tests = ['Baz']
      allow(@file_finder).to receive(:find_build_input_file)
        .with( filepath: 'Baz', complain: :ignore, context: :test ).and_return( 'build/test/partials/a_test/Baz.c' )

      result = @planner.extract_sources( :test, 'test/TestFoo.c', @testable.partials )

      expect(result).to include( 'build/test/partials/a_test/Baz.c' )
    end

    it "skips the implicit header-driven resolution entirely when a TEST_SOURCE_FILE() entry already shares the header's own basename -- unconditionally, not only when the implicit resolution would otherwise be ambiguous -- and logs a NOTICE naming the override" do
      allow(@test_source_file_directive_resolver).to receive(:resolve)
        .with( 'test/TestFoo.c', :test ).and_return( [['src/beta/foo.c'], {}] )
      allow(@test_context_extractor).to receive(:lookup_all_header_includes_list)
        .with( 'test/TestFoo.c' ).and_return( [UserInclude.new('foo.h')] )
      expect(@file_finder).to_not receive(:find_build_input_file)
        .with( filepath: 'foo.h', complain: :ignore, context: :test )
      expect(@loginator).to receive(:log).with(
        a_string_matching(/src\/beta\/foo\.c/).and(a_string_matching(/foo\.h/)).and(a_string_matching(/test\/TestFoo\.c/)),
        Verbosity::COMPLAIN,
        LogLabels::NOTICE
      )

      result = @planner.extract_sources( :test, 'test/TestFoo.c', @testable.partials )

      expect(result).to eq( ['src/beta/foo.c'] )
    end

    it "matches a TEST_SOURCE_FILE() entry to a header by basename stem alone, regardless of the directive's own real extension, and logs a NOTICE naming the override" do
      allow(@test_source_file_directive_resolver).to receive(:resolve)
        .with( 'test/TestFoo.c', :test ).and_return( [['src/beta/foo.cpp'], {}] )
      allow(@test_context_extractor).to receive(:lookup_all_header_includes_list)
        .with( 'test/TestFoo.c' ).and_return( [UserInclude.new('foo.h')] )
      expect(@file_finder).to_not receive(:find_build_input_file)
        .with( filepath: 'foo.h', complain: :ignore, context: :test )
      expect(@loginator).to receive(:log).with(
        a_string_matching(/src\/beta\/foo\.cpp/).and(a_string_matching(/foo\.h/)),
        Verbosity::COMPLAIN,
        LogLabels::NOTICE
      )

      result = @planner.extract_sources( :test, 'test/TestFoo.c', @testable.partials )

      expect(result).to eq( ['src/beta/foo.cpp'] )
    end

    it "leaves the implicit header-driven resolution untouched, logging nothing, when a TEST_SOURCE_FILE() entry names an unrelated basename (the documented header-less use case)" do
      allow(@test_source_file_directive_resolver).to receive(:resolve)
        .with( 'test/TestFoo.c', :test ).and_return( [['src/calc.c'], {}] )
      allow(@test_context_extractor).to receive(:lookup_all_header_includes_list)
        .with( 'test/TestFoo.c' ).and_return( [UserInclude.new('foo.h')] )
      allow(@file_finder).to receive(:find_build_input_file)
        .with( filepath: 'foo.h', complain: :ignore, context: :test ).and_return( 'src/foo.c' )
      expect(@loginator).to_not receive(:log)

      result = @planner.extract_sources( :test, 'test/TestFoo.c', @testable.partials )

      expect(result).to match_array( ['src/calc.c', 'src/foo.c'] )
    end

    it "removes a file added via the implicit header/source convention when the resolver names it subtractive" do
      allow(@test_source_file_directive_resolver).to receive(:resolve)
        .with( 'test/TestFoo.c', :test ).and_return( [[], { 'src/foo.c' => '-:foo.c' }] )
      allow(@test_context_extractor).to receive(:lookup_all_header_includes_list)
        .with( 'test/TestFoo.c' ).and_return( [UserInclude.new('foo.h')] )
      allow(@file_finder).to receive(:find_build_input_file)
        .with( filepath: 'foo.h', complain: :ignore, context: :test ).and_return( 'src/foo.c' )

      result = @planner.extract_sources( :test, 'test/TestFoo.c', @testable.partials )

      expect(result).to eq( [] )
    end

    it "removes a file added by a separate positive TEST_SOURCE_FILE() entry, proving removal isn't scoped to the header-convention case" do
      allow(@test_source_file_directive_resolver).to receive(:resolve)
        .with( 'test/TestFoo.c', :test ).and_return( [['src/extra.c'], { 'src/extra.c' => '-:extra.c' }] )
      allow(@test_context_extractor).to receive(:lookup_all_header_includes_list)
        .with( 'test/TestFoo.c' ).and_return( [] )

      result = @planner.extract_sources( :test, 'test/TestFoo.c', @testable.partials )

      expect(result).to eq( [] )
    end

    it "changes nothing when a subtractive entry names a file never in the assembled source list" do
      allow(@test_source_file_directive_resolver).to receive(:resolve)
        .with( 'test/TestFoo.c', :test ).and_return( [['src/keep.c'], { 'src/gone.c' => '-:gone.c' }] )
      allow(@test_context_extractor).to receive(:lookup_all_header_includes_list)
        .with( 'test/TestFoo.c' ).and_return( [] )

      result = @planner.extract_sources( :test, 'test/TestFoo.c', @testable.partials )

      expect(result).to eq( ['src/keep.c'] )
    end
  end
end
