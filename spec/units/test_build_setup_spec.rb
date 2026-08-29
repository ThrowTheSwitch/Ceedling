# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/test_invoker/test_build_setup'
require 'ceedling/test_invoker/test_invoker_types'

describe TestBuildSetup do
  before(:each) do
    @configurator            = double( "Configurator" )
    @loginator               = double( "Loginator" )
    @reportinator            = double( "Reportinator" )
    @batchinator             = double( "Batchinator" )
    @test_context_extractor  = double( "TestContextExtractor" )
    @include_pathinator      = double( "IncludePathinator" )
    @preprocessinator        = double( "Preprocessinator" )
    @defineinator            = double( "Defineinator" )
    @flaginator              = double( "Flaginator" )
    @file_wrapper            = double( "FileWrapper" )
    @file_path_utils         = double( "FilePathUtils" )
    @file_finder             = double( "FileFinder" )
    @test_runner_manager     = double( "TestRunnerManager" )
    @dependinator            = double( "Dependinator" )

    allow(@batchinator).to receive(:exec) do |workload:, things:, &block|
      things.each { |k, v| block.call(k, v) }
    end

    allow(@reportinator).to receive(:generate_module_progress).and_return( '' )
    allow(@reportinator).to receive(:generate_progress).and_return( '' )
    allow(@reportinator).to receive(:generate_skip_summary).and_return( nil )
    allow(@loginator).to receive(:log)
    allow(@loginator).to receive(:log_list)

    allow(@configurator).to receive(:project_build_vendor_ceedling_path).and_return( 'build/vendor/ceedling' )
    allow(@configurator).to receive(:cmock_mock_prefix).and_return( 'Mock' )
    allow(@configurator).to receive(:paths_test).and_return( [] )
    allow(@configurator).to receive(:tools_test_bare_includes_preprocessor).and_return( { name: 'fake bare includes preprocessor' } )
    allow(@configurator).to receive(:tools_test_file_directives_only_preprocessor).and_return( { name: 'fake directives-only preprocessor' } )
    allow(@configurator).to receive(:test_build_preprocess_force_fallback).and_return( false )
    allow(@file_path_utils).to receive(:form_preprocessed_file_raw_directives_only_filepath).and_return( 'build/preprocess/raw/Foo.txt' )
    allow(@file_path_utils).to receive(:form_preprocessed_includes_list_filepath).and_return( 'build/preprocess/includes/Foo.c.yml' )
    allow(@file_path_utils).to receive(:form_test_build_directives_cache_filepath).and_return( 'build/preprocess/build_directives/a_test/Foo.c.yml' )

    # Default: dependency tracker reports every target fresh (not stale).
    # Tests below override this per test case via a blanket `stale?` stub,
    # affecting whichever pass(es) that test actually cares about -- targets
    # aren't discriminated by argument here, so a test focused on one pass
    # relies on the other pass's own calls being harmlessly stubbed too (see
    # the bare-includes and ingest defaults immediately below).
    allow(@dependinator).to receive(:register)
    allow(@dependinator).to receive(:stale?).and_return( false )
    allow(@dependinator).to receive(:mark_fresh)

    # Bare-includes pass (first pass) defaults, so tests focused on the
    # directives-only pass (second) or reconciliation (third) don't need to
    # know about the first pass's own calls.
    allow(@preprocessinator).to receive(:preprocess_bare_includes).and_return( [] )
    allow(@preprocessinator).to receive(:store_includes_list)
    allow(@preprocessinator).to receive(:load_includes_list).and_return( [] )

    # Reconciliation (third pass) defaults, so tests focused on the first or
    # second pass don't need to know about the third pass's own calls -- it
    # always runs, ungated (see its comment in test_build_setup.rb).
    allow(@preprocessinator).to receive(:preprocess_user_includes).and_return( [] )
    allow(@preprocessinator).to receive(:preprocess_system_includes).and_return( [] )
    allow(@test_context_extractor).to receive(:lookup_all_header_includes_list).and_return( [] )
    allow(@test_context_extractor).to receive(:ingest_includes)

    # Harmless default -- individual examples needing a specific ordered header
    # collection stub this again with a narrower `.with(...)` match.
    allow(@include_pathinator).to receive(:ordered_header_files).and_return( [] )

    @setup = described_class.new(
      {
        :configurator           => @configurator,
        :loginator              => @loginator,
        :reportinator           => @reportinator,
        :batchinator            => @batchinator,
        :test_context_extractor => @test_context_extractor,
        :include_pathinator     => @include_pathinator,
        :preprocessinator       => @preprocessinator,
        :defineinator           => @defineinator,
        :flaginator             => @flaginator,
        :file_wrapper           => @file_wrapper,
        :file_path_utils        => @file_path_utils,
        :file_finder            => @file_finder,
        :test_runner_manager    => @test_runner_manager,
        :dependinator           => @dependinator
      }
    )

    @testable = TestInvokerTypes::Testable.new(
      :name               => 'a_test',
      :filepath           => 'test/TestFoo.c',
      :paths              => {},
      :preprocess         => { :includes => [], :directives_only => { :filepath => nil } },
      :preprocess_flags   => [],
      :preprocess_defines => [],
      :search_paths       => []
    )
    @state = TestInvokerTypes::PipelineState.new( :testables => { :a_test => @testable }, :context => :test, :options => [], :lock => Mutex.new )
  end

  context "#stage_prepare_build_paths" do
    before(:each) do
      allow(@file_path_utils).to receive(:form_test_build_path).and_return( 'build/test/out/a_test' )
      allow(@file_path_utils).to receive(:form_test_results_path).and_return( 'build/test/results/a_test' )
      allow(@file_path_utils).to receive(:form_test_dependencies_path).and_return( 'build/test/dependencies/a_test' )
      allow(@file_path_utils).to receive(:form_test_runners_path).and_return( 'build/test/runners/a_test' )
      allow(@file_path_utils).to receive(:form_test_mocks_path).and_return( 'build/test/mocks/a_test' )
      allow(@file_path_utils).to receive(:form_test_partials_path).and_return( 'build/test/partials/a_test' )
      allow(@file_path_utils).to receive(:form_test_preprocess_includes_path).and_return( 'build/test/preprocess/includes/a_test' )
      allow(@file_path_utils).to receive(:form_test_preprocess_files_path).and_return( 'build/test/preprocess/files/a_test' )
      allow(@file_path_utils).to receive(:form_test_preprocess_files_full_expansion_path).and_return( 'build/test/preprocess/full/a_test' )
      allow(@file_path_utils).to receive(:form_test_preprocess_files_directives_only_path).and_return( 'build/test/preprocess/directives/a_test' )
      allow(@file_path_utils).to receive(:form_test_preprocess_files_raw_directives_only_path).and_return( 'build/test/preprocess/raw/a_test' )
      allow(@file_path_utils).to receive(:form_test_preprocess_build_directives_path).and_return( 'build/test/preprocess/build_directives/a_test' )
      allow(@file_wrapper).to receive(:mkdir)
      allow(@configurator).to receive(:project_use_mocks).and_return( false )
      allow(@configurator).to receive(:project_use_partials).and_return( false )
      allow(@configurator).to receive(:project_use_test_preprocessor).and_return( :none )
    end

    def prepare_state
      TestInvokerTypes::PipelineState.new(
        :tests => ['test/TestFoo.c'], :testables => {}, :context => :test, :options => [], :lock => Mutex.new
      )
    end

    it "populates the testables hash keyed by the test's own symbolized name" do
      state = prepare_state

      @setup.stage_prepare_build_paths( state )

      testable = state.testables[:TestFoo]
      expect(testable.filepath).to eq( 'test/TestFoo.c' )
      expect(testable.name).to eq( 'TestFoo' )
    end

    it "always assembles the build, results, dependencies, and runners paths" do
      state = prepare_state

      @setup.stage_prepare_build_paths( state )

      paths = state.testables[:TestFoo].paths
      expect(paths[:build]).to eq( 'build/test/out/a_test' )
      expect(paths[:results]).to eq( 'build/test/results/a_test' )
      expect(paths[:dependencies]).to eq( 'build/test/dependencies/a_test' )
      expect(paths[:runners]).to eq( 'build/test/runners/a_test' )
      expect(paths[:preprocess_build_directives]).to eq( 'build/test/preprocess/build_directives/a_test' )
    end

    it "omits the mocks path when the project has mocking disabled" do
      state = prepare_state

      @setup.stage_prepare_build_paths( state )

      expect(state.testables[:TestFoo].paths).to_not have_key( :mocks )
    end

    it "assembles the mocks path when the project has mocking enabled" do
      allow(@configurator).to receive(:project_use_mocks).and_return( true )
      state = prepare_state

      @setup.stage_prepare_build_paths( state )

      expect(state.testables[:TestFoo].paths[:mocks]).to eq( 'build/test/mocks/a_test' )
    end

    it "omits the partials path when the project has Partials disabled" do
      state = prepare_state

      @setup.stage_prepare_build_paths( state )

      expect(state.testables[:TestFoo].paths).to_not have_key( :partials )
    end

    it "assembles the partials path when the project has Partials enabled" do
      allow(@configurator).to receive(:project_use_partials).and_return( true )
      state = prepare_state

      @setup.stage_prepare_build_paths( state )

      expect(state.testables[:TestFoo].paths[:partials]).to eq( 'build/test/partials/a_test' )
    end

    it "omits the preprocessing paths and scratch state when preprocessing is off" do
      state = prepare_state

      @setup.stage_prepare_build_paths( state )

      testable = state.testables[:TestFoo]
      expect(testable.paths).to_not have_key( :preprocess_includes )
      expect(testable.preprocess).to_not have_key( :includes )
    end

    it "assembles the preprocessing paths and scratch state when preprocessing is on" do
      allow(@configurator).to receive(:project_use_test_preprocessor).and_return( :tests )
      state = prepare_state

      @setup.stage_prepare_build_paths( state )

      testable = state.testables[:TestFoo]
      expect(testable.paths[:preprocess_includes]).to eq( 'build/test/preprocess/includes/a_test' )
      expect(testable.paths[:preprocess_files]).to eq( 'build/test/preprocess/files/a_test' )
      expect(testable.paths[:preprocess_files_full_expansion]).to eq( 'build/test/preprocess/full/a_test' )
      expect(testable.paths[:preprocess_files_directives_only]).to eq( 'build/test/preprocess/directives/a_test' )
      expect(testable.paths[:preprocess_files_raw_directives_only]).to eq( 'build/test/preprocess/raw/a_test' )
      expect(testable.preprocess[:includes]).to eq( [] )
      expect(testable.preprocess[:directives_only]).to eq( { filepath: nil } )
    end

    it "creates every assembled build path on disk" do
      allow(@configurator).to receive(:project_use_mocks).and_return( true )
      allow(@configurator).to receive(:project_use_partials).and_return( true )
      allow(@configurator).to receive(:project_use_test_preprocessor).and_return( :tests )
      state = prepare_state

      expect(@file_wrapper).to receive(:mkdir).exactly(12).times

      @setup.stage_prepare_build_paths( state )
    end
  end

  context "#stage_collect_test_context" do
    before(:each) do
      allow(@test_context_extractor).to receive(:collect_simple_context_from_file)
      allow(@test_context_extractor).to receive(:lookup_mock_header_includes_list).and_return( [] )
      allow(@test_context_extractor).to receive(:lookup_partials_config).and_return( {} )
      allow(@test_context_extractor).to receive(:store_build_directives_cache)
      allow(@test_context_extractor).to receive(:load_build_directives_cache)
      allow(@include_pathinator).to receive(:validate_test_build_directive_paths)
      allow(@include_pathinator).to receive(:validate_header_files_collection).and_return( [] )
      allow(@include_pathinator).to receive(:augment_environment_header_files)
      allow(@configurator).to receive(:project_use_mocks).and_return( false )
      allow(@configurator).to receive(:project_use_partials).and_return( false )
    end

    context "when preprocessing is enabled" do
      before(:each) do
        allow(@configurator).to receive(:project_use_test_preprocessor_tests).and_return( true )
      end

      it "scans #includes, build directive include paths, and Partials configuration, then caches the build directives, when the cache is stale" do
        allow(@dependinator).to receive(:stale?).and_return( true )

        expect(@test_context_extractor).to receive(:collect_simple_context_from_file).with(
          'test/TestFoo.c', nil,
          TestContextExtractor::Context::INCLUDES,
          TestContextExtractor::Context::BUILD_DIRECTIVE_INCLUDE_PATHS,
          TestContextExtractor::Context::PARTIALS_CONFIGURATION
        )
        expect(@test_context_extractor).to receive(:store_build_directives_cache).with(
          filepath: 'test/TestFoo.c', cache_filepath: 'build/preprocess/build_directives/a_test/Foo.c.yml'
        )
        expect(@dependinator).to receive(:mark_fresh).with( 'build/preprocess/build_directives/a_test/Foo.c.yml' )
        expect(@test_context_extractor).to_not receive(:load_build_directives_cache)

        @setup.stage_collect_test_context( @state )
      end

      it "scans only #includes and Partials configuration, recalling build directives from cache, when the cache is fresh" do
        allow(@dependinator).to receive(:stale?).and_return( false )

        expect(@test_context_extractor).to receive(:collect_simple_context_from_file).with(
          'test/TestFoo.c', nil,
          TestContextExtractor::Context::INCLUDES,
          TestContextExtractor::Context::PARTIALS_CONFIGURATION
        )
        expect(@test_context_extractor).to receive(:load_build_directives_cache).with(
          filepath: 'test/TestFoo.c', cache_filepath: 'build/preprocess/build_directives/a_test/Foo.c.yml'
        )
        expect(@test_context_extractor).to_not receive(:store_build_directives_cache)
        expect(@dependinator).to_not receive(:mark_fresh)

        @setup.stage_collect_test_context( @state )
      end
    end

    context "when preprocessing is disabled" do
      before(:each) do
        allow(@configurator).to receive(:project_use_test_preprocessor_tests).and_return( false )
      end

      it "also scans build directive source files and test runner details, and caches build directives, when the cache is stale" do
        allow(@dependinator).to receive(:stale?).and_return( true )

        expect(@test_context_extractor).to receive(:collect_simple_context_from_file).with(
          'test/TestFoo.c', nil,
          TestContextExtractor::Context::INCLUDES,
          TestContextExtractor::Context::BUILD_DIRECTIVE_INCLUDE_PATHS,
          TestContextExtractor::Context::BUILD_DIRECTIVE_SOURCE_FILES,
          TestContextExtractor::Context::TEST_RUNNER_DETAILS
        )

        @setup.stage_collect_test_context( @state )
      end

      it "still scans test runner details when the build directives cache is fresh" do
        allow(@dependinator).to receive(:stale?).and_return( false )

        expect(@test_context_extractor).to receive(:collect_simple_context_from_file).with(
          'test/TestFoo.c', nil,
          TestContextExtractor::Context::INCLUDES,
          TestContextExtractor::Context::TEST_RUNNER_DETAILS
        )

        @setup.stage_collect_test_context( @state )
      end
    end

    it "logs one summary line stating how many test files' build directives were recalled from cache" do
      allow(@configurator).to receive(:project_use_test_preprocessor_tests).and_return( true )
      allow(@dependinator).to receive(:stale?).and_return( false )

      allow(@reportinator).to receive(:generate_skip_summary).and_return( "Skipping build directive macro scanning for 1 test file (nothing changed)..." )

      expect(@loginator).to receive(:log).with( "Skipping build directive macro scanning for 1 test file (nothing changed)..." )
      @setup.stage_collect_test_context( @state )
    end

    it "logs no summary line when every test file's build directives needed scanning" do
      allow(@configurator).to receive(:project_use_test_preprocessor_tests).and_return( true )
      allow(@dependinator).to receive(:stale?).and_return( true )

      expect(@loginator).to_not receive(:log).with( /Skipping build directive macro scanning/ )

      @setup.stage_collect_test_context( @state )
    end
  end

  context "#stage_collect_preprocessor_context (directives-only pass)" do
    before(:each) do
      allow(@configurator).to receive(:test_build_preprocess_directives_only_available).and_return( true )
    end

    it "generates and marks fresh directives-only output when the dependency tracker reports it stale" do
      allow(@dependinator).to receive(:stale?).and_return( true )
      expect(@preprocessinator).to receive(:generate_directives_only_output).and_return( 'build/preprocess/raw/Foo.txt' )
      expect(@dependinator).to receive(:mark_fresh).with('build/preprocess/raw/Foo.txt')

      @setup.stage_collect_preprocessor_context( @state )

      expect( @testable.preprocess[:directives_only][:filepath] ).to eq('build/preprocess/raw/Foo.txt')
    end

    it "skips regenerating and reuses the deterministic path when the dependency tracker reports it unchanged" do
      allow(@dependinator).to receive(:stale?).and_return( false )
      expect(@preprocessinator).to_not receive(:generate_directives_only_output)
      expect(@dependinator).to_not receive(:mark_fresh)

      @setup.stage_collect_preprocessor_context( @state )

      expect( @testable.preprocess[:directives_only][:filepath] ).to eq('build/preprocess/raw/Foo.txt')
    end

    it "does not mark fresh when the preprocessor fails (returns nil, nothing was actually written)" do
      allow(@dependinator).to receive(:stale?).and_return( true )
      allow(@preprocessinator).to receive(:generate_directives_only_output).and_return( nil )
      expect(@dependinator).to_not receive(:mark_fresh).with('build/preprocess/raw/Foo.txt')

      @setup.stage_collect_preprocessor_context( @state )

      expect( @testable.preprocess[:directives_only][:filepath] ).to be_nil
    end

    it "does nothing when directives-only preprocessing is unavailable for this toolchain" do
      allow(@configurator).to receive(:test_build_preprocess_directives_only_available).and_return( false )
      expect(@dependinator).to_not receive(:register).with('build/preprocess/raw/Foo.txt', anything)
      expect(@preprocessinator).to_not receive(:generate_directives_only_output)

      @setup.stage_collect_preprocessor_context( @state )
    end

    it "logs a summary line stating how many test files' directives-only output was recalled from cache" do
      allow(@dependinator).to receive(:stale?).and_return( false )

      allow(@reportinator).to receive(:generate_skip_summary).and_return( "Skipping directives-only preprocessing for 1 test file (nothing changed)..." )

      expect(@loginator).to receive(:log).with( "Skipping directives-only preprocessing for 1 test file (nothing changed)..." )
      @setup.stage_collect_preprocessor_context( @state )
    end

    it "logs no summary line when every test file's directives-only output needed regenerating" do
      allow(@dependinator).to receive(:stale?).and_return( true )
      allow(@preprocessinator).to receive(:generate_directives_only_output).and_return( 'build/preprocess/raw/Foo.txt' )

      expect(@loginator).to_not receive(:log).with( /Skipping directives-only preprocessing/ )

      @setup.stage_collect_preprocessor_context( @state )
    end

    it "registers the test file as the sole antecedent, with preprocess flags/defines/search paths and the directives-only preprocessor tool as meta" do
      testable = @testable
      testable.preprocess_flags   = ['-Wall']
      testable.preprocess_defines = ['TEST']
      testable.search_paths       = ['src']
      allow(@dependinator).to receive(:stale?).and_return( true )
      allow(@preprocessinator).to receive(:generate_directives_only_output).and_return( 'build/preprocess/raw/Foo.txt' )

      expect(@dependinator).to receive(:register).with(
        'build/preprocess/raw/Foo.txt',
        files: ['test/TestFoo.c'],
        meta:  {
          flags: ['-Wall'], defines: ['TEST'], search_paths: ['src'],
          tools: [{ name: 'fake directives-only preprocessor' }],
          preprocess_force_fallback: false
        }
      )

      @setup.stage_collect_preprocessor_context( @state )
    end
  end

  context "#stage_collect_preprocessor_context (bare-includes pass)" do
    before(:each) do
      # Keeps the second pass a no-op in these tests, which focus on the first.
      allow(@configurator).to receive(:test_build_preprocess_directives_only_available).and_return( false )
    end

    it "extracts, caches, and marks fresh the bare-includes list, and generates stand-ins, when the dependency tracker reports it stale" do
      allow(@dependinator).to receive(:stale?).and_return( true )
      includes = []
      expect(@preprocessinator).to receive(:preprocess_bare_includes).and_return( includes )
      expect(@preprocessinator).to receive(:store_includes_list).with( test: 'a_test', filepath: 'test/TestFoo.c', includes: includes )
      expect(@dependinator).to receive(:mark_fresh).with('build/preprocess/includes/Foo.c.yml')

      @setup.stage_collect_preprocessor_context( @state )

      expect( @testable.preprocess[:includes] ).to eq( includes )
    end

    it "recalls the cached bare-includes list and skips extraction, caching, and stand-in generation when the dependency tracker reports it unchanged" do
      allow(@dependinator).to receive(:stale?).and_return( false )
      cached_includes = []
      expect(@preprocessinator).to_not receive(:preprocess_bare_includes)
      expect(@preprocessinator).to_not receive(:store_includes_list)
      expect(@preprocessinator).to receive(:load_includes_list).with( test: 'a_test', filepath: 'test/TestFoo.c' ).and_return( cached_includes )
      expect(@dependinator).to_not receive(:mark_fresh).with('build/preprocess/includes/Foo.c.yml')

      @setup.stage_collect_preprocessor_context( @state )

      expect( @testable.preprocess[:includes] ).to eq( cached_includes )
    end

    it "logs a summary line stating how many test files' #includes were recalled from cache" do
      allow(@dependinator).to receive(:stale?).and_return( false )

      allow(@reportinator).to receive(:generate_skip_summary).and_return( "Skipping #include extraction for 1 test file (nothing changed)..." )

      expect(@loginator).to receive(:log).with( "Skipping #include extraction for 1 test file (nothing changed)..." )
      @setup.stage_collect_preprocessor_context( @state )
    end

    it "logs no summary line when every test file's #includes needed extracting" do
      allow(@dependinator).to receive(:stale?).and_return( true )

      expect(@loginator).to_not receive(:log).with( /Skipping #include extraction/ )

      @setup.stage_collect_preprocessor_context( @state )
    end

    it "registers the test file as the sole antecedent, with preprocess flags/defines/search paths and the bare-includes preprocessor tool as meta" do
      testable = @testable
      testable.preprocess_flags   = ['-Wall']
      testable.preprocess_defines = ['TEST']
      testable.search_paths       = ['src']

      expect(@dependinator).to receive(:register).with(
        'build/preprocess/includes/Foo.c.yml',
        files: ['test/TestFoo.c'],
        meta:  {
          flags: ['-Wall'], defines: ['TEST'], search_paths: ['src'],
          tools: [{ name: 'fake bare includes preprocessor' }],
          preprocess_force_fallback: false
        }
      )

      @setup.stage_collect_preprocessor_context( @state )
    end

    context "stand-in generation" do
      before(:each) do
        allow(@dependinator).to receive(:stale?).and_return( true )
        allow(@file_wrapper).to receive(:mkdir)
        allow(@file_wrapper).to receive(:write_blank_file)
        allow(@file_path_utils).to receive(:form_mock_header_filepath).and_return( 'build/test/mocks/a_test/MockFoo.h' )
        allow(@file_path_utils).to receive(:form_partial_header_filepath).and_return( 'build/test/partials/a_test/ceedling_partial_Foo_impl.h' )
        allow(@file_finder).to receive(:resolve_mock).and_return( ['src/Foo.h', ''] )
      end

      it "writes a blank stand-in for a mocked header that does not yet exist on disk" do
        allow(@file_wrapper).to receive(:exist?).and_return( false )
        allow(@preprocessinator).to receive(:preprocess_bare_includes).and_return( [ Include.new('MockFoo.h') ] )

        expect(@file_wrapper).to receive(:mkdir).with( File.dirname('build/test/mocks/a_test/MockFoo.h') )
        expect(@file_wrapper).to receive(:write_blank_file).with( 'build/test/mocks/a_test/MockFoo.h' )

        @setup.stage_collect_preprocessor_context( @state )
      end

      it "resolves a mocked header's real source against the ordering collect_mock_search_paths (stage 2) originally saw for it -- this test's own search_paths minus its own mock_search_paths" do
        @testable.search_paths      = ['build/test/mocks/a_test/drivers', 'src']
        @testable.mock_search_paths = ['build/test/mocks/a_test/drivers']
        allow(@file_wrapper).to receive(:exist?).and_return( false )
        allow(@preprocessinator).to receive(:preprocess_bare_includes).and_return( [ Include.new('MockFoo.h') ] )

        expect(@include_pathinator).to receive(:ordered_header_files).with( ['src'] ).and_return( ['src/Foo.h'] )
        expect(@file_finder).to receive(:resolve_mock).with( 'MockFoo.h', collection: ['src/Foo.h'] ).and_return( ['src/Foo.h', ''] )

        @setup.stage_collect_preprocessor_context( @state )
      end

      it "leaves an existing mocked header's stand-in path untouched, whether it holds real content or a prior stand-in" do
        allow(@file_wrapper).to receive(:exist?).and_return( true )
        allow(@preprocessinator).to receive(:preprocess_bare_includes).and_return( [ Include.new('MockFoo.h') ] )

        expect(@file_wrapper).to_not receive(:write_blank_file)
        expect(@file_wrapper).to_not receive(:mkdir)

        @setup.stage_collect_preprocessor_context( @state )
      end

      it "writes a blank stand-in for a partial header that does not yet exist on disk" do
        allow(@file_wrapper).to receive(:exist?).and_return( false )
        allow(@preprocessinator).to receive(:preprocess_bare_includes).and_return( [ Include.new('ceedling_partial_Foo_impl.h') ] )

        expect(@file_wrapper).to receive(:write_blank_file).with( 'build/test/partials/a_test/ceedling_partial_Foo_impl.h' )

        @setup.stage_collect_preprocessor_context( @state )
      end

      it "leaves an existing partial header's stand-in path untouched" do
        allow(@file_wrapper).to receive(:exist?).and_return( true )
        allow(@preprocessinator).to receive(:preprocess_bare_includes).and_return( [ Include.new('ceedling_partial_Foo_impl.h') ] )

        expect(@file_wrapper).to_not receive(:write_blank_file)

        @setup.stage_collect_preprocessor_context( @state )
      end
    end
  end

  context "#stage_collect_preprocessor_context (reconciliation pass)" do
    before(:each) do
      allow(@configurator).to receive(:test_build_preprocess_directives_only_available).and_return( true )

      # Isolates the reconciliation (third) pass from the first two: the bare-includes
      # pass (first) actually extracts, so its result is a real, non-empty `bare` for
      # reconcile to match against; the directives-only pass (second) is a cache hit,
      # reusing the deterministic path it always computes regardless.
      allow(@dependinator).to receive(:stale?).with('build/preprocess/includes/Foo.c.yml').and_return( true )
      allow(@dependinator).to receive(:stale?).with('build/preprocess/raw/Foo.txt').and_return( false )
      allow(@preprocessinator).to receive(:preprocess_bare_includes).and_return( [ Include.new('bar.h') ] )
    end

    it "logs an ℹ️ NOTICE naming the chosen file and every candidate passed over when reconciliation resolves an ambiguous #include" do
      allow(@preprocessinator).to receive(:preprocess_user_includes).and_return(
        [ UserInclude.new('foo/bar.h'), UserInclude.new('baz/bar.h') ]
      )

      expect(@loginator).to receive(:log).with(
        a_string_matching(/foo\/bar\.h/).and(a_string_matching(/baz\/bar\.h/)).and(a_string_matching(/test\/TestFoo\.c/)),
        Verbosity::COMPLAIN,
        LogLabels::NOTICE
      )

      @setup.stage_collect_preprocessor_context( @state )
    end

    it "logs no NOTICE when reconciliation resolves a bare #include uniquely" do
      allow(@preprocessinator).to receive(:preprocess_user_includes).and_return(
        [ UserInclude.new('foo/bar.h') ]
      )

      expect(@loginator).to_not receive(:log).with( anything, Verbosity::COMPLAIN, LogLabels::NOTICE )

      @setup.stage_collect_preprocessor_context( @state )
    end
  end

  describe "#collect_mock_search_paths" do
    before(:each) do
      @testable.paths[:mocks] = 'build/test/mocks/a_test'

      # collect_mock_search_paths rebuilds this test's own search_paths ordering directly
      # (testable.search_paths doesn't exist yet -- see the method's own comment), so it
      # needs the same collaborators #search_paths's own examples stub.
      allow(@include_pathinator).to receive(:lookup_test_directive_include_paths).and_return( [] )
      allow(@include_pathinator).to receive(:collect_test_include_paths).and_return( [] )
      allow(@configurator).to receive(:collection_paths_support).and_return( [] )
      allow(@configurator).to receive(:collection_paths_include).and_return( [] )
      allow(@configurator).to receive(:collection_paths_libraries).and_return( [] )
      allow(@configurator).to receive(:collection_paths_vendor).and_return( [] )
      allow(@configurator).to receive(:collection_paths_test_toolchain_include).and_return( [] )
    end

    it "collects each non-Partial mocked header's own mirrored directory, deduplicated" do
      foo_mock = MockInclude.new('MockFoo.h')
      bar_mock = MockInclude.new('MockBar.h')
      allow(@test_context_extractor).to receive(:lookup_mock_header_includes_list)
        .with('test/TestFoo.c').and_return( [foo_mock, bar_mock] )
      allow(@file_finder).to receive(:resolve_mock).with('MockFoo.h', collection: []).and_return( ['src/drivers/foo.h', 'drivers'] )
      allow(@file_finder).to receive(:resolve_mock).with('MockBar.h', collection: []).and_return( ['src/drivers/bar.h', 'drivers'] )

      result = @setup.collect_mock_search_paths( @testable )

      expect(result).to eq(['build/test/mocks/a_test/drivers'])
    end

    it "resolves each mock's real header against this test's own TEST_INCLUDE_PATH()-then-configured-root ordering, with no mock_search_paths yet (that's what this call is computing)" do
      allow(@include_pathinator).to receive(:lookup_test_directive_include_paths)
        .with('test/TestFoo.c').and_return( ['other_inc'] )
      allow(@configurator).to receive(:collection_paths_include).and_return( ['src'] )

      foo_mock = MockInclude.new('MockFoo.h')
      allow(@test_context_extractor).to receive(:lookup_mock_header_includes_list)
        .with('test/TestFoo.c').and_return( [foo_mock] )

      expect(@include_pathinator).to receive(:ordered_header_files)
        .with( ['build/test/mocks/a_test', 'other_inc', 'src'] ).and_return( ['other_inc/foo.h'] )
      expect(@file_finder).to receive(:resolve_mock)
        .with('MockFoo.h', collection: ['other_inc/foo.h']).and_return( ['other_inc/foo.h', ''] )

      @setup.collect_mock_search_paths( @testable )
    end

    it "uses the flat mock root itself for a header directly in a configured root" do
      foo_mock = MockInclude.new('MockFoo.h')
      allow(@test_context_extractor).to receive(:lookup_mock_header_includes_list)
        .with('test/TestFoo.c').and_return( [foo_mock] )
      allow(@file_finder).to receive(:resolve_mock).with('MockFoo.h', collection: []).and_return( ['src/foo.h', ''] )

      result = @setup.collect_mock_search_paths( @testable )

      expect(result).to eq(['build/test/mocks/a_test'])
    end

    it "skips a Partial mock -- it has no real header to resolve against" do
      partial_mock = MockInclude.new('Mockceedling_partial_foo_interface.h')
      allow(@test_context_extractor).to receive(:lookup_mock_header_includes_list)
        .with('test/TestFoo.c').and_return( [partial_mock] )
      expect(@file_finder).to_not receive(:resolve_mock)

      result = @setup.collect_mock_search_paths( @testable )

      expect(result).to eq([])
    end

    it "returns nothing when the project has no mocks path at all (mocking disabled)" do
      @testable.paths.delete(:mocks)

      result = @setup.collect_mock_search_paths( @testable )

      expect(result).to eq([])
    end
  end

  describe "#validate_mocks_in_use" do
    it "does not raise when the project has mocking enabled" do
      allow(@configurator).to receive(:project_use_mocks).and_return( true )

      expect {
        @setup.validate_mocks_in_use( filename: 'TestFoo.c', mocks: [MockInclude.new('MockFoo.h')] )
      }.to_not raise_error
    end

    it "does not raise when mocking is disabled but the test #includes no mocks" do
      allow(@configurator).to receive(:project_use_mocks).and_return( false )

      expect {
        @setup.validate_mocks_in_use( filename: 'TestFoo.c', mocks: [] )
      }.to_not raise_error
    end

    it "raises naming the #included mocks when mocking is disabled but the test #includes one anyway" do
      allow(@configurator).to receive(:project_use_mocks).and_return( false )

      expect {
        @setup.validate_mocks_in_use( filename: 'TestFoo.c', mocks: [MockInclude.new('MockFoo.h')] )
      }.to raise_error( CeedlingException, /TestFoo\.c #includes MockFoo\.h/ )
    end

    it "raises naming every #included mock, bracketed, when more than one is present" do
      allow(@configurator).to receive(:project_use_mocks).and_return( false )
      mocks = [MockInclude.new('MockFoo.h'), MockInclude.new('MockBar.h')]

      expect {
        @setup.validate_mocks_in_use( filename: 'TestFoo.c', mocks: mocks )
      }.to raise_error( CeedlingException, /\[MockFoo\.h, MockBar\.h\]/ )
    end
  end

  describe "#validate_partials_in_use" do
    it "does not raise when the test uses no Partial features" do
      allow(@configurator).to receive(:project_use_partials).and_return( false )

      expect {
        @setup.validate_partials_in_use( filename: 'TestFoo.c', partials_in_use: false, includes: [] )
      }.to_not raise_error
    end

    it "raises when the test uses Partial features but the project has Partials disabled" do
      allow(@configurator).to receive(:project_use_partials).and_return( false )
      includes = [UserInclude.new(CEEDLING_HEADER_FILENAME)]

      expect {
        @setup.validate_partials_in_use( filename: 'TestFoo.c', partials_in_use: true, includes: includes )
      }.to raise_error( CeedlingException, /not configured for Partials/ )
    end

    it "raises when the test uses Partial features but never #includes ceedling.h" do
      allow(@configurator).to receive(:project_use_partials).and_return( true )

      expect {
        @setup.validate_partials_in_use( filename: 'TestFoo.c', partials_in_use: true, includes: [] )
      }.to raise_error( CeedlingException, /without #including #{CEEDLING_HEADER_FILENAME}/ )
    end

    it "does not raise when the test uses Partial features and #includes ceedling.h with Partials enabled" do
      allow(@configurator).to receive(:project_use_partials).and_return( true )
      includes = [UserInclude.new(CEEDLING_HEADER_FILENAME)]

      expect {
        @setup.validate_partials_in_use( filename: 'TestFoo.c', partials_in_use: true, includes: includes )
      }.to_not raise_error
    end
  end

  describe "#search_paths" do
    before(:each) do
      allow(@include_pathinator).to receive(:lookup_test_directive_include_paths).and_return( [] )
      allow(@include_pathinator).to receive(:collect_test_include_paths).and_return( [] )
      allow(@configurator).to receive(:collection_paths_support).and_return( [] )
      allow(@configurator).to receive(:collection_paths_include).and_return( [] )
      allow(@configurator).to receive(:collection_paths_libraries).and_return( [] )
      allow(@configurator).to receive(:collection_paths_vendor).and_return( [] )
      allow(@configurator).to receive(:collection_paths_test_toolchain_include).and_return( [] )
    end

    it "includes a mocked header's own mirrored directory alongside the flat mock root" do
      paths = { mocks: 'build/test/mocks/a_test' }
      mock_search_paths = ['build/test/mocks/a_test/drivers']

      result = @setup.search_paths( 'test/TestFoo.c', paths, mock_search_paths )

      expect(result).to include('build/test/mocks/a_test')
      expect(result).to include('build/test/mocks/a_test/drivers')
    end

    it "carries only the flat mock root when no mock needs a mirrored directory of its own" do
      paths = { mocks: 'build/test/mocks/a_test' }

      result = @setup.search_paths( 'test/TestFoo.c', paths )

      expect(result).to eq(['build/test/mocks/a_test'])
    end
  end

  describe "#preprocess_defines" do
    it "passes test_defines through as both the absent-section default and the no-match fallback" do
      expect(@defineinator).to receive(:defines).with(
        subkey: PREPROCESS_SYM, filepath: 'test/TestFoo.c', default: ['TEST'], no_match_default: ['TEST']
      ).and_return( ['TEST'] )

      result = @setup.preprocess_defines( test_defines: ['TEST'], filepath: 'test/TestFoo.c' )

      expect( result ).to eq( ['TEST'] )
    end
  end

  describe "#preprocess_flags" do
    before(:each) do
      allow(@flaginator).to receive(:flags_defined?).and_return( true )
    end

    it "passes compile_flags through as both the absent-section default and the no-match fallback" do
      expect(@flaginator).to receive(:flag_down).with(
        context: :test, operation: OPERATION_PREPROCESS_SYM, filepath: 'test/TestFoo.c',
        default: ['-Wall'], no_match_default: ['-Wall']
      ).and_return( ['-Wall'] )

      result = @setup.preprocess_flags( context: :test, compile_flags: ['-Wall'], filepath: 'test/TestFoo.c' )

      expect( result ).to eq( ['-Wall'] )
    end
  end

  describe "#framework_defines" do
    before(:each) do
      allow(@defineinator).to receive(:defines).with( topkey: UNITY_SYM,      subkey: :defines ).and_return( ['UNITY_THING'] )
      allow(@defineinator).to receive(:defines).with( topkey: CMOCK_SYM,      subkey: :defines ).and_return( ['CMOCK_MOCK_PREFIX=Mock'] )
      allow(@defineinator).to receive(:defines).with( topkey: CEXCEPTION_SYM, subkey: :defines ).and_return( [] )
    end

    it "includes the Partials prefix symbol unconditionally, alongside the other framework defines, when Partials is enabled" do
      allow(@configurator).to receive(:project_use_partials).and_return( true )

      result = @setup.framework_defines()

      expect( result ).to include( "CEEDLING_PARTIALS_PREFIX=#{PARTIAL_FILENAME_PREFIX}" )
      expect( result ).to include( 'UNITY_THING', 'CMOCK_MOCK_PREFIX=Mock' )
    end

    it "omits the Partials prefix symbol when Partials is disabled" do
      allow(@configurator).to receive(:project_use_partials).and_return( false )

      result = @setup.framework_defines()

      expect( result ).to_not include( "CEEDLING_PARTIALS_PREFIX=#{PARTIAL_FILENAME_PREFIX}" )
    end
  end
end
