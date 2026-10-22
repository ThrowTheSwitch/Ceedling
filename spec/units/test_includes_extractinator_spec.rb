# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/test_invoker/test_includes_extractinator'
require 'ceedling/test_invoker/test_bare_includes_extractinator'
require 'ceedling/test_invoker/test_includes_preprocessinator'
require 'ceedling/test_invoker/test_includes_reconcilinator'
require 'ceedling/test_invoker/test_invoker_types'
require 'ceedling/test_invoker/test_search_paths'
require 'ceedling/test_invoker/mock_locator'
require 'ceedling/test_invoker/standin_headerinator'

describe TestIncludesExtractinator do
  before(:each) do
    @configurator            = double( "Configurator" )
    @loginator               = double( "Loginator" )
    @reportinator            = double( "Reportinator" )
    @batchinator             = double( "Batchinator" )
    @test_context_extractor  = double( "TestContextExtractor" )
    @include_pathinator      = double( "IncludePathinator" )
    @preprocessinator        = double( "Preprocessinator" )
    @file_wrapper            = double( "FileWrapper" )
    @file_path_utils         = double( "FilePathUtils" )
    @file_finder             = double( "FileFinder" )
    @dependinator            = double( "Dependinator" )

    allow(@batchinator).to receive(:exec) do |things:, **_options, &block|
      things.each { |k, v| block.call(k, v) }
    end

    allow(@reportinator).to receive(:generate_module_progress).and_return( '' )
    allow(@reportinator).to receive(:generate_skip_summary).and_return( nil )
    allow(@loginator).to receive(:log)
    allow(@loginator).to receive(:log_list)

    allow(@configurator).to receive(:project_build_vendor_ceedling_path).and_return( 'build/vendor/ceedling' )
    allow(@configurator).to receive(:cmock_mock_prefix).and_return( 'Mock' )
    allow(@configurator).to receive(:get_cmock_config).and_return( {} )
    allow(@configurator).to receive(:paths_test).and_return( [] )
    allow(@configurator).to receive(:tools_test_bare_includes_preprocessor).and_return( { name: 'fake bare includes preprocessor' } )
    allow(@configurator).to receive(:tools_test_file_directives_only_preprocessor).and_return( { name: 'fake directives-only preprocessor' } )
    allow(@configurator).to receive(:tools_test_file_full_preprocessor).and_return( { name: 'fake full preprocessor' } )
    allow(@configurator).to receive(:test_build_preprocess_force_fallback).and_return( false )
    allow(@file_path_utils).to receive(:form_preprocessed_file_raw_directives_only_filepath).and_return( 'build/preprocess/raw/Foo.txt' )
    allow(@file_path_utils).to receive(:form_preprocessed_file_compacted_directives_only_filepath).and_return( 'build/preprocess/compacted/Foo.txt' )
    allow(@file_path_utils).to receive(:form_preprocessed_file_fallback_expansion_filepath).and_return( 'build/preprocess/fallback/Foo.txt' )
    allow(@file_path_utils).to receive(:form_preprocessed_includes_list_filepath).and_return( 'build/preprocess/includes/Foo.c.yml' )

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
    # always runs, ungated (see its comment in test_includes_extractinator.rb).
    allow(@preprocessinator).to receive(:preprocess_user_includes).and_return( [] )
    allow(@preprocessinator).to receive(:preprocess_system_includes).and_return( [] )
    allow(@preprocessinator).to receive(:reconcile_includes).and_return( [] )
    allow(@preprocessinator).to receive(:supplement_with_text_includes) { |bare:, **| bare }
    allow(@preprocessinator).to receive(:supplement_with_computed_includes) { |bare:, **| bare }
    allow(@preprocessinator).to receive(:preprocessed_dependencies).and_return( [] )
    allow(@preprocessinator).to receive(:generate_fallback_expansion_output).and_return( nil )
    allow(@configurator).to receive(:project_build_root).and_return( 'build' )
    allow(@file_wrapper).to receive(:exist?).and_return( false )
    allow(@test_context_extractor).to receive(:lookup_mock_header_includes_list).and_return( [] )
    allow(@test_context_extractor).to receive(:lookup_all_header_includes_list).and_return( [] )
    allow(@test_context_extractor).to receive(:lookup_source_includes_list).and_return( [] )
    allow(@test_context_extractor).to receive(:ingest_includes)

    # Harmless default -- individual examples needing a specific ordered header
    # collection stub this again with a narrower `.with(...)` match.
    allow(@include_pathinator).to receive(:ordered_header_files).and_return( [] )

    # Search path defaults, so tests of a reconciling first pass, which rebuilds a test's
    # search paths, need not know every source those paths draw on
    allow(@include_pathinator).to receive(:lookup_test_directive_include_paths).and_return( [] )
    allow(@include_pathinator).to receive(:collect_test_include_paths).and_return( [] )
    allow(@configurator).to receive(:collection_paths_support).and_return( [] )
    allow(@configurator).to receive(:collection_paths_include).and_return( [] )
    allow(@configurator).to receive(:collection_paths_libraries).and_return( [] )
    allow(@configurator).to receive(:collection_paths_vendor).and_return( [] )
    allow(@configurator).to receive(:collection_paths_test_toolchain_include).and_return( [] )

    @mock_locator = MockLocator.new(
      configurator: @configurator, include_pathinator: @include_pathinator, file_finder: @file_finder, file_path_utils: @file_path_utils
    )

    # The stage's passes and collaborators are real, over the same doubles, so these
    # examples cover the whole stage and read as paths and files
    search_paths = TestSearchPaths.new(
      configurator: @configurator, include_pathinator: @include_pathinator, test_context_extractor: @test_context_extractor
    )
    standins = StandinHeaderinator.new(
      configurator: @configurator, loginator: @loginator, reportinator: @reportinator,
      file_wrapper: @file_wrapper, file_path_utils: @file_path_utils, mock_locator: @mock_locator
    )
    common = { configurator: @configurator, loginator: @loginator, reportinator: @reportinator, batchinator: @batchinator, preprocessinator: @preprocessinator }

    @extractinator = described_class.new(
      test_bare_includes_extractinator: TestBareIncludesExtractinator.new(
        **common, file_path_utils: @file_path_utils, dependinator: @dependinator, test_search_paths: search_paths, standin_headerinator: standins
      ),
      test_includes_preprocessinator: TestIncludesPreprocessinator.new(
        **common, file_path_utils: @file_path_utils, file_wrapper: @file_wrapper, dependinator: @dependinator
      ),
      test_includes_reconcilinator: TestIncludesReconcilinator.new(
        **common, test_context_extractor: @test_context_extractor, test_search_paths: search_paths, mock_locator: @mock_locator
      )
    )

    @testable = TestInvokerTypes::Testable.new(
      :name               => 'a_test',
      :filepath           => 'test/TestFoo.c',
      :paths              => {},
      :preprocess         => { :includes => [], :directives_only => { :filepath => nil }, :fallback_expansion => { :filepath => nil } },
      :preprocess_flags   => [],
      :preprocess_defines => [],
      :search_paths       => []
    )
    @state = TestInvokerTypes::PipelineState.new( :testables => { :a_test => @testable }, :context => :test, :options => [], :lock => Mutex.new )
  end

  context "#stage_collect_preprocessor_context (directives-only pass)" do
    before(:each) do
      allow(@configurator).to receive(:test_build_preprocess_directives_only_available).and_return( true )
    end

    it "generates and marks fresh directives-only output when the dependency tracker reports it stale" do
      allow(@dependinator).to receive(:stale?).and_return( true )
      expect(@preprocessinator).to receive(:generate_directives_only_output).and_return( 'build/preprocess/raw/Foo.txt' )
      expect(@dependinator).to receive(:mark_fresh).with('build/preprocess/raw/Foo.txt')

      @extractinator.stage_collect_preprocessor_context( @state )

      expect( @testable.preprocess[:directives_only][:filepath] ).to eq('build/preprocess/raw/Foo.txt')
    end

    # The same run writes a compacted file that later stages read, so the raw target vouches for it
    it "registers the compacted output before marking the raw output fresh" do
      allow(@dependinator).to receive(:stale?).and_return( true )
      allow(@preprocessinator).to receive(:generate_directives_only_output).and_return( 'build/preprocess/raw/Foo.txt' )

      expect(@dependinator).to receive(:register).with( 'build/preprocess/raw/Foo.txt', outputs: ['build/preprocess/compacted/Foo.txt'] ).ordered
      expect(@dependinator).to receive(:mark_fresh).with('build/preprocess/raw/Foo.txt').ordered

      @extractinator.stage_collect_preprocessor_context( @state )
    end

    it "skips regenerating and reuses the deterministic path when the dependency tracker reports it unchanged" do
      allow(@dependinator).to receive(:stale?).and_return( false )
      expect(@preprocessinator).to_not receive(:generate_directives_only_output)
      expect(@dependinator).to_not receive(:mark_fresh)

      @extractinator.stage_collect_preprocessor_context( @state )

      expect( @testable.preprocess[:directives_only][:filepath] ).to eq('build/preprocess/raw/Foo.txt')
    end

    it "does not mark fresh when the preprocessor fails (returns nil, nothing was actually written)" do
      allow(@dependinator).to receive(:stale?).and_return( true )
      allow(@preprocessinator).to receive(:generate_directives_only_output).and_return( nil )
      expect(@dependinator).to_not receive(:mark_fresh).with('build/preprocess/raw/Foo.txt')

      @extractinator.stage_collect_preprocessor_context( @state )

      expect( @testable.preprocess[:directives_only][:filepath] ).to be_nil
    end

    it "logs a summary line stating how many test files' directives-only output was recalled from cache" do
      allow(@dependinator).to receive(:stale?).and_return( false )

      allow(@reportinator).to receive(:generate_skip_summary).and_return( "Skipping directives-only preprocessing for 1 test file (nothing changed)..." )

      expect(@loginator).to receive(:log).with( "Skipping directives-only preprocessing for 1 test file (nothing changed)..." )
      @extractinator.stage_collect_preprocessor_context( @state )
    end

    it "logs no summary line when every test file's directives-only output needed regenerating" do
      allow(@dependinator).to receive(:stale?).and_return( true )
      allow(@preprocessinator).to receive(:generate_directives_only_output).and_return( 'build/preprocess/raw/Foo.txt' )

      expect(@loginator).to_not receive(:log).with( /Skipping directives-only preprocessing/ )

      @extractinator.stage_collect_preprocessor_context( @state )
    end

    it "registers the test file as the sole antecedent, with preprocess flags/defines/search paths and the directives-only preprocessor tool as meta" do
      testable = @testable
      testable.preprocess_flags   = ['-Wall']
      testable.preprocess_defines = ['TEST']
      testable.search_paths       = ['src']
      # The first pass rebuilds the search paths this pass records, from the same sources
      allow(@configurator).to receive(:collection_paths_include).and_return( ['src'] )
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

      @extractinator.stage_collect_preprocessor_context( @state )
    end
  end

  # Without -fdirectives-only, a plain expansion stands in for the second pass's output.
  # Its line markers carry the same record of the files the test file entered.
  context "#stage_collect_preprocessor_context (second pass, fallback)" do
    before(:each) do
      allow(@configurator).to receive(:test_build_preprocess_directives_only_available).and_return( false )
      allow(@configurator).to receive(:test_build_preprocess_force_fallback).and_return( true )
    end

    it "runs the full preprocessor into the fallback expansion when the dependency tracker reports it stale" do
      allow(@dependinator).to receive(:stale?).and_return( true )
      expect(@preprocessinator).to_not receive(:generate_directives_only_output)
      expect(@preprocessinator).to receive(:generate_fallback_expansion_output).and_return( 'build/preprocess/fallback/Foo.txt' )
      expect(@dependinator).to receive(:mark_fresh).with( 'build/preprocess/fallback/Foo.txt' )

      @extractinator.stage_collect_preprocessor_context( @state )

      expect( @testable.preprocess[:fallback_expansion][:filepath] ).to eq( 'build/preprocess/fallback/Foo.txt' )
      expect( @testable.preprocess[:directives_only][:filepath] ).to be_nil
    end

    it "registers the test file as the sole antecedent, with the full preprocessor tool as meta" do
      allow(@dependinator).to receive(:stale?).and_return( true )

      expect(@dependinator).to receive(:register).with(
        'build/preprocess/fallback/Foo.txt',
        files: ['test/TestFoo.c'],
        meta:  { flags: [], defines: [], search_paths: [], tools: [{ name: 'fake full preprocessor' }], preprocess_force_fallback: true }
      )

      @extractinator.stage_collect_preprocessor_context( @state )
    end

    # Nothing reads a compacted copy in fallback, so the expansion vouches for no other file
    it "registers no further output before marking the expansion fresh" do
      allow(@dependinator).to receive(:stale?).and_return( true )
      allow(@preprocessinator).to receive(:generate_fallback_expansion_output).and_return( 'build/preprocess/fallback/Foo.txt' )

      expect(@dependinator).to_not receive(:register).with( 'build/preprocess/fallback/Foo.txt', hash_including( :outputs ) )

      @extractinator.stage_collect_preprocessor_context( @state )
    end

    it "registers the project files its last expansion entered, before asking whether it is stale" do
      allow(@file_wrapper).to receive(:exist?).with( 'build/preprocess/fallback/Foo.txt' ).and_return( true )
      allow(@preprocessinator).to receive(:preprocessed_dependencies).with( preprocessed_filepath: 'build/preprocess/fallback/Foo.txt' )
        .and_return( ['test/TestFoo.c', 'build/test/mocks/a_test/mock_config.h', 'src/config.h'] )

      expect(@dependinator).to receive(:register).with( 'build/preprocess/fallback/Foo.txt', files: ['test/TestFoo.c', 'src/config.h'] ).ordered
      expect(@dependinator).to receive(:stale?).with( 'build/preprocess/fallback/Foo.txt' ).ordered.and_return( false )

      @extractinator.stage_collect_preprocessor_context( @state )
    end

    it "does not mark fresh when the full preprocessor fails" do
      allow(@dependinator).to receive(:stale?).and_return( true )
      allow(@preprocessinator).to receive(:generate_fallback_expansion_output).and_return( nil )

      expect(@dependinator).to_not receive(:mark_fresh).with( 'build/preprocess/fallback/Foo.txt' )

      @extractinator.stage_collect_preprocessor_context( @state )

      expect( @testable.preprocess[:fallback_expansion][:filepath] ).to be_nil
    end

    it "reuses the expansion's path, and summarizes the skip as fallback preprocessing, when unchanged" do
      allow(@dependinator).to receive(:stale?).and_return( false )
      allow(@reportinator).to receive(:generate_skip_summary).with( hash_including( task: 'fallback preprocessing' ) ).and_return( 'fallback skip summary' )

      expect(@preprocessinator).to_not receive(:generate_fallback_expansion_output)
      expect(@loginator).to receive(:log).with( 'fallback skip summary' )

      @extractinator.stage_collect_preprocessor_context( @state )

      expect( @testable.preprocess[:fallback_expansion][:filepath] ).to eq( 'build/preprocess/fallback/Foo.txt' )
    end
  end

  context "#stage_collect_preprocessor_context (bare-includes pass)" do
    before(:each) do
      # In fallback, the second pass's default stubs make no expansion, so these
      # examples see the first pass alone
      allow(@configurator).to receive(:test_build_preprocess_directives_only_available).and_return( false )
    end

    it "extracts, caches, and marks fresh the bare-includes list, and generates stand-ins, when the dependency tracker reports it stale" do
      allow(@dependinator).to receive(:stale?).and_return( true )
      includes = []
      expect(@preprocessinator).to receive(:preprocess_bare_includes).and_return( includes )
      expect(@preprocessinator).to receive(:store_includes_list).with( test: 'a_test', filepath: 'test/TestFoo.c', includes: includes )
      expect(@dependinator).to receive(:mark_fresh).with('build/preprocess/includes/Foo.c.yml')

      @extractinator.stage_collect_preprocessor_context( @state )

      expect( @testable.preprocess[:includes] ).to eq( includes )
    end

    # A failed run says nothing about the file, so nothing is cached and the next run
    # tries again. The text scan alone makes the candidates meanwhile.
    it "neither caches nor marks fresh a failed bare-includes pass, and gives it an empty list" do
      allow(@dependinator).to receive(:stale?).and_return( true )
      allow(@preprocessinator).to receive(:preprocess_bare_includes).and_return( nil )

      expect(@preprocessinator).to_not receive(:store_includes_list)
      expect(@dependinator).to_not receive(:mark_fresh).with( 'build/preprocess/includes/Foo.c.yml' )
      expect(@preprocessinator).to receive(:supplement_with_text_includes).with( filepath: 'test/TestFoo.c', bare: [] ).and_return( [] )

      @extractinator.stage_collect_preprocessor_context( @state )

      expect( @testable.preprocess[:includes] ).to eq( [] )
    end

    it "recalls the cached bare-includes list and skips extraction and caching when the dependency tracker reports it unchanged" do
      allow(@dependinator).to receive(:stale?).and_return( false )
      cached_includes = []
      expect(@preprocessinator).to_not receive(:preprocess_bare_includes)
      expect(@preprocessinator).to_not receive(:store_includes_list)
      expect(@preprocessinator).to receive(:load_includes_list).with( test: 'a_test', filepath: 'test/TestFoo.c' ).and_return( cached_includes )
      expect(@dependinator).to_not receive(:mark_fresh).with('build/preprocess/includes/Foo.c.yml')

      @extractinator.stage_collect_preprocessor_context( @state )

      expect( @testable.preprocess[:includes] ).to eq( cached_includes )
    end

    it "logs a summary line stating how many test files' #includes were recalled from cache" do
      allow(@dependinator).to receive(:stale?).and_return( false )

      allow(@reportinator).to receive(:generate_skip_summary).and_return( "Skipping #include extraction for 1 test file (nothing changed)..." )

      expect(@loginator).to receive(:log).with( "Skipping #include extraction for 1 test file (nothing changed)..." )
      @extractinator.stage_collect_preprocessor_context( @state )
    end

    it "logs no summary line when every test file's #includes needed extracting" do
      allow(@dependinator).to receive(:stale?).and_return( true )

      expect(@loginator).to_not receive(:log).with( /Skipping #include extraction/ )

      @extractinator.stage_collect_preprocessor_context( @state )
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

      @extractinator.stage_collect_preprocessor_context( @state )
    end

    # StandinHeaderinator's own spec covers where each stand-in goes; these cover when
    # stage 4 places them
    context "stand-ins" do
      before(:each) do
        allow(@file_wrapper).to receive(:exist?).and_return( false )
        allow(@file_wrapper).to receive(:mkdir)
        allow(@file_wrapper).to receive(:write)
        allow(@file_path_utils).to receive(:form_mock_header_filepath).and_return( 'build/test/mocks/a_test/MockFoo.h' )
        allow(@file_finder).to receive(:resolve_mock).and_return( ['src/Foo.h', ''] )
      end

      it "places a stand-in for each mock on a freshly extracted bare-includes list" do
        allow(@dependinator).to receive(:stale?).and_return( true )
        allow(@preprocessinator).to receive(:preprocess_bare_includes).and_return( [ Include.new('MockFoo.h') ] )

        expect(@file_wrapper).to receive(:write).with( 'build/test/mocks/a_test/MockFoo.h', anything )

        @extractinator.stage_collect_preprocessor_context( @state )
      end

      # A cached list says nothing about whether its stand-ins survived, and the
      # directives-only pass needs them
      it "places a missing stand-in for a mock on a bare-includes list recalled from cache" do
        allow(@dependinator).to receive(:stale?).and_return( false )
        allow(@preprocessinator).to receive(:load_includes_list).and_return( [ Include.new('MockFoo.h') ] )

        expect(@file_wrapper).to receive(:write).with( 'build/test/mocks/a_test/MockFoo.h', anything )

        @extractinator.stage_collect_preprocessor_context( @state )
      end
    end
  end

  # With directives-only output available, the reconciled list drives the build, and it
  # draws only from the bare list, so the bare list's mocks set the mock search paths
  context "#stage_collect_preprocessor_context (mock search paths)" do
    before(:each) do
      @testable.paths[:mocks]     = 'build/test/mocks/a_test'
      @testable.mock_search_paths = ['build/test/mocks/a_test/hw']
      @testable.search_paths      = ['build/test/mocks/a_test', 'build/test/mocks/a_test/hw', 'src']

      allow(@configurator).to receive(:test_build_preprocess_directives_only_available).and_return( true )
      allow(@dependinator).to receive(:stale?).with('build/preprocess/includes/Foo.c.yml').and_return( true )
      allow(@dependinator).to receive(:stale?).with('build/preprocess/raw/Foo.txt').and_return( false )

      allow(@include_pathinator).to receive(:lookup_test_directive_include_paths).and_return( [] )
      allow(@include_pathinator).to receive(:collect_test_include_paths).and_return( [] )
      allow(@configurator).to receive(:collection_paths_support).and_return( [] )
      allow(@configurator).to receive(:collection_paths_include).and_return( ['src'] )
      allow(@configurator).to receive(:collection_paths_libraries).and_return( [] )
      allow(@configurator).to receive(:collection_paths_vendor).and_return( [] )
      allow(@configurator).to receive(:collection_paths_test_toolchain_include).and_return( [] )
      allow(@file_path_utils).to receive(:form_mock_output_path) do |root, subdir|
        subdir.nil? || subdir.empty? ? root : File.join( root, subdir )
      end
      allow(@file_path_utils).to receive(:form_mock_header_filepath) { |dir, name| File.join( 'build/test/mocks', dir, name ) }
      allow(@file_wrapper).to receive(:exist?).and_return( true )
      allow(@file_wrapper).to receive(:read).and_return( "/* AUTOGENERATED FILE. DO NOT EDIT. */\n" )
      allow(@file_finder).to receive(:resolve_mock).with( 'MockFoo.h', collection: anything, complain: anything ).and_return( ['src/drivers/foo.h', 'drivers'] )
      # Reconciliation keeps the mock, so its directory survives the narrowing after it
      allow(@test_context_extractor).to receive(:lookup_mock_header_includes_list).and_return( [ MockInclude.new('MockFoo.h') ] )
    end

    it "replaces stage 2's mock search paths with the mirrored directories of the bare list's mocks" do
      allow(@preprocessinator).to receive(:preprocess_bare_includes).and_return( [ Include.new('MockFoo.h') ] )

      @extractinator.stage_collect_preprocessor_context( @state )

      expect(@testable.mock_search_paths).to eq( ['build/test/mocks/a_test/drivers'] )
      expect(@testable.search_paths).to eq( ['build/test/mocks/a_test', 'build/test/mocks/a_test/drivers', 'src'] )
    end

    it "sets the mock search paths from a bare list recalled from cache, too" do
      allow(@dependinator).to receive(:stale?).with('build/preprocess/includes/Foo.c.yml').and_return( false )
      allow(@preprocessinator).to receive(:load_includes_list).and_return( [ Include.new('MockFoo.h') ] )

      @extractinator.stage_collect_preprocessor_context( @state )

      expect(@testable.mock_search_paths).to eq( ['build/test/mocks/a_test/drivers'] )
    end

    it "never resolves a mock the bare list leaves out, such as one in a conditional branch that is off" do
      allow(@preprocessinator).to receive(:preprocess_bare_includes).and_return( [] )
      allow(@test_context_extractor).to receive(:lookup_mock_header_includes_list).and_return( [] )
      expect(@file_finder).to_not receive(:resolve_mock)

      @extractinator.stage_collect_preprocessor_context( @state )

      expect(@testable.mock_search_paths).to eq( [] )
      expect(@testable.search_paths).to eq( ['build/test/mocks/a_test', 'src'] )
    end

    it "hands the directives-only pass the rebuilt search paths" do
      allow(@dependinator).to receive(:stale?).with('build/preprocess/raw/Foo.txt').and_return( true )
      allow(@preprocessinator).to receive(:preprocess_bare_includes).and_return( [ Include.new('MockFoo.h') ] )

      expect(@preprocessinator).to receive(:generate_directives_only_output)
        .with( hash_including( include_paths: ['build/test/mocks/a_test', 'build/test/mocks/a_test/drivers', 'src'] ) )
        .and_return( nil )

      @extractinator.stage_collect_preprocessor_context( @state )
    end

    # Fallback reconciles too, so its expansion needs the stand-ins on its search path
    it "replaces stage 2's mock search paths in fallback too" do
      allow(@configurator).to receive(:test_build_preprocess_directives_only_available).and_return( false )
      allow(@preprocessinator).to receive(:preprocess_bare_includes).and_return( [ Include.new('MockFoo.h') ] )

      @extractinator.stage_collect_preprocessor_context( @state )

      expect(@testable.mock_search_paths).to eq( ['build/test/mocks/a_test/drivers'] )
      expect(@testable.search_paths).to eq( ['build/test/mocks/a_test', 'build/test/mocks/a_test/drivers', 'src'] )
    end

    it "hands the fallback expansion the rebuilt search paths" do
      allow(@configurator).to receive(:test_build_preprocess_directives_only_available).and_return( false )
      allow(@dependinator).to receive(:stale?).with('build/preprocess/fallback/Foo.txt').and_return( true )
      allow(@preprocessinator).to receive(:preprocess_bare_includes).and_return( [ Include.new('MockFoo.h') ] )

      expect(@preprocessinator).to receive(:generate_fallback_expansion_output)
        .with( hash_including( include_paths: ['build/test/mocks/a_test', 'build/test/mocks/a_test/drivers', 'src'] ) )
        .and_return( nil )

      @extractinator.stage_collect_preprocessor_context( @state )
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
      allow(@preprocessinator).to receive(:preprocess_user_includes).and_return( [] )
      allow(@preprocessinator).to receive(:preprocess_system_includes).and_return( [] )
    end

    # The reconcile core -- intersection, the ambiguous-#include NOTICE, and the
    # mock-filter -- now lives in Preprocessinator#reconcile_includes (its own specs).
    # Here we only assert the third pass hands it the test file's own bare list, keeps
    # the mock-filter off, and ingests what it returns.
    it "delegates to Preprocessinator#reconcile_includes with the test file's bare list and drop_mocked: false" do
      reconciled = [ UserInclude.new('bar.h') ]
      expect(@preprocessinator).to receive(:reconcile_includes).with(
        hash_including(
          bare:          [ Include.new('bar.h') ],
          user:          [],
          system:        [],
          test_filepath: 'test/TestFoo.c',
          drop_mocked:   false
        )
      ).and_return( reconciled )

      expect(@test_context_extractor).to receive(:ingest_includes).with( 'test/TestFoo.c', reconciled )

      @extractinator.stage_collect_preprocessor_context( @state )
    end

    # Reconciling to nothing while the text names #includes means preprocessing found none
    # it should have, so stage 2's list stands and the user is told
    it "keeps the text-scan #includes, and warns, when reconciliation empties them" do
      allow(@preprocessinator).to receive(:reconcile_includes).and_return( [] )
      allow(@test_context_extractor).to receive(:lookup_all_header_includes_list).with( 'test/TestFoo.c' ).and_return( [ UserInclude.new('bar.h') ] )

      expect(@test_context_extractor).to_not receive(:ingest_includes)
      expect(@loginator).to receive(:log).with(
        "No #includes of test/TestFoo.c survived reconciliation, though its text names some. Using the text-scanned " \
        "#includes as a best effort. Rerun with --verbosity=obnoxious to see why preprocessing found none.",
        Verbosity::COMPLAIN
      )

      @extractinator.stage_collect_preprocessor_context( @state )
    end

    # Ingesting replaces a test's source #includes along with its headers
    it "keeps the text-scan #includes when only a source #include was scanned" do
      allow(@preprocessinator).to receive(:reconcile_includes).and_return( [] )
      allow(@test_context_extractor).to receive(:lookup_source_includes_list).with( 'test/TestFoo.c' ).and_return( [ UserInclude.new('foo.c') ] )

      expect(@test_context_extractor).to_not receive(:ingest_includes)

      @extractinator.stage_collect_preprocessor_context( @state )
    end

    # A file with no #includes at all reconciles to nothing, and that is its true list
    it "ingests an empty reconciled list when the text scan found no #includes either" do
      allow(@preprocessinator).to receive(:reconcile_includes).and_return( [] )

      expect(@test_context_extractor).to receive(:ingest_includes).with( 'test/TestFoo.c', [] )

      @extractinator.stage_collect_preprocessor_context( @state )
    end
  end

  # A test's bare list is supplemented as a mockable header's is: with its literal
  # #includes, which catch one guarded by a macro another header defines, and with its
  # computed #includes. Each addition survives only if the directives-only pass confirms it.
  context "#stage_collect_preprocessor_context (candidates)" do
    before(:each) do
      @testable.paths[:mocks] = 'build/test/mocks/a_test'
      allow(@configurator).to receive(:test_build_preprocess_directives_only_available).and_return( true )
      allow(@dependinator).to receive(:stale?).with('build/preprocess/includes/Foo.c.yml').and_return( true )
      allow(@dependinator).to receive(:stale?).with('build/preprocess/raw/Foo.txt').and_return( false )
      allow(@file_path_utils).to receive(:form_mock_output_path) do |root, subdir|
        subdir.nil? || subdir.empty? ? root : File.join( root, subdir )
      end
      allow(@file_path_utils).to receive(:form_mock_header_filepath) { |dir, name| File.join( 'build/test/mocks', dir, name ) }
      allow(@file_wrapper).to receive(:exist?).and_return( true )
      allow(@file_wrapper).to receive(:read).and_return( "/* AUTOGENERATED FILE. DO NOT EDIT. */\n" )
      allow(@preprocessinator).to receive(:preprocess_bare_includes).and_return( [ Include.new('MockConfig.h') ] )
      allow(@preprocessinator).to receive(:supplement_with_text_includes)
        .with( filepath: 'test/TestFoo.c', bare: [ Include.new('MockConfig.h') ] )
        .and_return( [ Include.new('MockConfig.h'), Include.new('MockPart1.h') ] )
    end

    it "keeps GCC's bare list and adds the test file's literal #includes as candidates" do
      allow(@file_finder).to receive(:resolve_mock).and_return( ['src/x.h', ''] )

      @extractinator.stage_collect_preprocessor_context( @state )

      expect(@testable.preprocess[:includes]).to eq( [ Include.new('MockConfig.h') ] )
      expect(@testable.preprocess[:candidates]).to eq( [ Include.new('MockConfig.h'), Include.new('MockPart1.h') ] )
    end

    # A literal #include may sit in a branch that is off, naming a mock whose header
    # doesn't exist
    it "places stand-ins strictly for the bare list's mocks and tolerantly for the literal additions" do
      expect(@file_finder).to receive(:resolve_mock).with( 'MockConfig.h', collection: anything, complain: :error ).and_return( ['src/Config.h', ''] )
      expect(@file_finder).to receive(:resolve_mock).with( 'MockPart1.h', collection: anything, complain: :silent ).and_return( [nil, nil] )

      @extractinator.stage_collect_preprocessor_context( @state )
    end

    it "reconciles against the candidates and the computed #includes when the directives-only pass succeeded" do
      allow(@file_finder).to receive(:resolve_mock).and_return( ['src/x.h', ''] )
      allow(@preprocessinator).to receive(:supplement_with_computed_includes)
        .with( filepath: 'test/TestFoo.c', bare: [ Include.new('MockConfig.h'), Include.new('MockPart1.h') ], directives_only_filepath: 'build/preprocess/raw/Foo.txt' )
        .and_return( [ Include.new('MockConfig.h'), Include.new('MockPart1.h'), Include.new('board.h') ] )

      expect(@preprocessinator).to receive(:reconcile_includes)
        .with( hash_including( bare: [ Include.new('MockConfig.h'), Include.new('MockPart1.h'), Include.new('board.h') ] ) )
        .and_return( [] )

      @extractinator.stage_collect_preprocessor_context( @state )
    end

    # The text-scanned #includes stand in for the failed pass, so checking them against
    # the candidates, which hold those same #includes, would keep every one
    it "reconciles against GCC's bare list alone when the directives-only pass failed" do
      allow(@file_finder).to receive(:resolve_mock).and_return( ['src/x.h', ''] )
      allow(@dependinator).to receive(:stale?).with('build/preprocess/raw/Foo.txt').and_return( true )
      allow(@preprocessinator).to receive(:generate_directives_only_output).and_return( nil )

      expect(@preprocessinator).to receive(:reconcile_includes)
        .with( hash_including( bare: [ Include.new('MockConfig.h') ] ) )
        .and_return( [] )

      @extractinator.stage_collect_preprocessor_context( @state )
    end

    # Nothing then checks the text scan, so stage 2's list stays as it is, the Partial
    # headers its configuration added included
    it "keeps the text-scan #includes when GCC's list is empty and the directives-only pass failed" do
      allow(@file_finder).to receive(:resolve_mock).and_return( ['src/x.h', ''] )
      allow(@preprocessinator).to receive(:preprocess_bare_includes).and_return( nil )
      allow(@dependinator).to receive(:stale?).with('build/preprocess/raw/Foo.txt').and_return( true )
      allow(@preprocessinator).to receive(:generate_directives_only_output).and_return( nil )

      expect(@preprocessinator).to_not receive(:reconcile_includes)
      expect(@test_context_extractor).to_not receive(:ingest_includes)

      @extractinator.stage_collect_preprocessor_context( @state )
    end

    it "narrows the mock search paths to the reconciled list's mocks" do
      allow(@file_finder).to receive(:resolve_mock).with( 'MockConfig.h', collection: anything, complain: anything ).and_return( ['src/Config.h', ''] )
      allow(@file_finder).to receive(:resolve_mock).with( 'MockPart1.h', collection: anything, complain: anything ).and_return( ['src/hw/Part1.h', 'hw'] )
      allow(@test_context_extractor).to receive(:lookup_mock_header_includes_list).with( 'test/TestFoo.c' ).and_return( [ MockInclude.new('MockConfig.h') ] )

      # A slip in a reconciled mock's name is reported by stage 5, which resolves strictly
      expect(@file_finder).to receive(:resolve_mock).with( 'MockConfig.h', collection: anything, complain: :silent ).and_return( ['src/Config.h', ''] )

      @extractinator.stage_collect_preprocessor_context( @state )

      expect(@testable.mock_search_paths).to eq( ['build/test/mocks/a_test'] )
      expect(@testable.search_paths).to eq( ['build/test/mocks/a_test'] )
    end

    context "in fallback" do
      before(:each) do
        allow(@configurator).to receive(:test_build_preprocess_directives_only_available).and_return( false )
        allow(@file_finder).to receive(:resolve_mock).and_return( ['src/x.h', ''] )
      end

      it "reconciles against the candidates and computed #includes from the fallback expansion" do
        allow(@preprocessinator).to receive(:supplement_with_computed_includes)
          .with( filepath: 'test/TestFoo.c', bare: [ Include.new('MockConfig.h'), Include.new('MockPart1.h') ], directives_only_filepath: 'build/preprocess/fallback/Foo.txt' )
          .and_return( [ Include.new('MockConfig.h'), Include.new('MockPart1.h'), Include.new('board.h') ] )

        expect(@preprocessinator).to receive(:preprocess_user_includes)
          .with( name: 'a_test', filepath: 'test/TestFoo.c', directives_only_filepath: 'build/preprocess/fallback/Foo.txt' ).and_return( [] )
        expect(@preprocessinator).to receive(:reconcile_includes)
          .with( hash_including( bare: [ Include.new('MockConfig.h'), Include.new('MockPart1.h'), Include.new('board.h') ] ) )
          .and_return( [] )

        @extractinator.stage_collect_preprocessor_context( @state )
      end

      it "warns that its reconciliation is best effort" do
        expect(@reportinator).to receive(:generate_module_progress)
          .with( hash_including( operation: 'Reconciling #includes from best-effort fallback preprocessing for' ) ).and_return( 'best effort' )
        expect(@loginator).to receive(:log).with( 'best effort', Verbosity::OBNOXIOUS, LogLabels::WARNING )

        @extractinator.stage_collect_preprocessor_context( @state )
      end

      it "keeps the text-scan #includes when GCC's list is empty and the fallback expansion failed" do
        allow(@preprocessinator).to receive(:preprocess_bare_includes).and_return( [] )
        allow(@dependinator).to receive(:stale?).with('build/preprocess/fallback/Foo.txt').and_return( true )
        allow(@preprocessinator).to receive(:generate_fallback_expansion_output).and_return( nil )

        expect(@preprocessinator).to_not receive(:reconcile_includes)
        expect(@test_context_extractor).to_not receive(:ingest_includes)

        @extractinator.stage_collect_preprocessor_context( @state )
      end

      it "reconciles against GCC's bare list alone when the fallback expansion failed" do
        allow(@dependinator).to receive(:stale?).with('build/preprocess/fallback/Foo.txt').and_return( true )
        allow(@preprocessinator).to receive(:generate_fallback_expansion_output).and_return( nil )

        expect(@preprocessinator).to receive(:reconcile_includes)
          .with( hash_including( bare: [ Include.new('MockConfig.h') ] ) )
          .and_return( [] )

        @extractinator.stage_collect_preprocessor_context( @state )
      end
    end
  end

  # The directives-only pass reads whatever the test file reaches, a mocked header through
  # its stand-in among them, so a change to any of those files reruns it
  context "#stage_collect_preprocessor_context (directives-only dependencies)" do
    before(:each) do
      allow(@configurator).to receive(:test_build_preprocess_directives_only_available).and_return( true )
      allow(@dependinator).to receive(:stale?).with('build/preprocess/includes/Foo.c.yml').and_return( false )
      allow(@preprocessinator).to receive(:preprocessed_dependencies).with( preprocessed_filepath: 'build/preprocess/raw/Foo.txt' )
        .and_return( ['test/TestFoo.c', 'build/test/mocks/a_test/mock_config.h', 'src/config.h'] )
    end

    it "registers the project files its last output entered, before asking whether it is stale" do
      allow(@file_wrapper).to receive(:exist?).with( 'build/preprocess/raw/Foo.txt' ).and_return( true )
      allow(@dependinator).to receive(:stale?).with('build/preprocess/raw/Foo.txt').and_return( false )

      expect(@dependinator).to receive(:register).with( 'build/preprocess/raw/Foo.txt', files: ['test/TestFoo.c', 'src/config.h'] ).ordered
      expect(@dependinator).to receive(:stale?).with( 'build/preprocess/raw/Foo.txt' ).ordered.and_return( false )

      @extractinator.stage_collect_preprocessor_context( @state )
    end

    it "registers the project files its new output entered before marking it fresh" do
      allow(@dependinator).to receive(:stale?).with('build/preprocess/raw/Foo.txt').and_return( true )
      allow(@preprocessinator).to receive(:generate_directives_only_output).and_return( 'build/preprocess/raw/Foo.txt' )

      expect(@dependinator).to receive(:register).with( 'build/preprocess/raw/Foo.txt', files: ['test/TestFoo.c', 'src/config.h'] ).ordered
      expect(@dependinator).to receive(:mark_fresh).with( 'build/preprocess/raw/Foo.txt' ).ordered

      @extractinator.stage_collect_preprocessor_context( @state )
    end
  end
end
