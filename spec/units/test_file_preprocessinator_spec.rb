# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/filename_extension'
require 'ceedling/exceptions'
require 'ceedling/test_invoker/test_file_preprocessinator'
require 'ceedling/test_invoker/test_invoker_types'

describe TestFilePreprocessinator do
  before(:each) do
    @configurator           = double( "Configurator" )
    @loginator              = double( "Loginator" )
    @reportinator           = double( "Reportinator" )
    @batchinator            = double( "Batchinator" )
    @test_context_extractor = double( "TestContextExtractor" )
    @dependinator           = double( "Dependinator" )

    allow(@batchinator).to receive(:exec) do |things:, **_options, &block|
      things.each { |k, v| block.call(k, v) }
    end
    allow(@configurator).to receive(:test_build_preprocess_force_fallback).and_return( false )
    allow(@configurator).to receive(:project_build_vendor_ceedling_path).and_return( 'build/vendor/ceedling' )
    allow(@reportinator).to receive(:generate_module_progress).and_return( '' )
    allow(@reportinator).to receive(:generate_progress).and_return( '' )
    allow(@reportinator).to receive(:generate_skip_summary).and_return( nil )
    allow(@loginator).to receive(:log)
    allow(@dependinator).to receive(:register)
    allow(@dependinator).to receive(:stale?).and_return( true )
    allow(@dependinator).to receive(:mark_fresh)
    @preprocessinator                    = double( "Preprocessinator" )
    @file_path_utils                     = double( "FilePathUtils" )
    @test_source_file_directive_resolver = double( "TestSourceFileDirectiveResolver" )
    @file_wrapper                        = double( "FileWrapper" )

    allow(@configurator).to receive(:project_build_root).and_return( 'build' )
    allow(@file_path_utils).to receive(:form_preprocessed_file_full_expansion_filepath).and_return( 'build/preprocess/full/TestFoo.c' )
    allow(@file_wrapper).to receive(:exist?).and_return( false )
    allow(@preprocessinator).to receive(:preprocessed_dependencies).and_return( [] )

    allow(@file_path_utils).to receive(:form_preprocessed_source_files_cache_filepath).and_return( 'build/preprocess/build_directives/a_test/TestFoo.c_source_files.yml' )
    allow(@test_context_extractor).to receive(:store_build_directives_cache)
    allow(@test_context_extractor).to receive(:load_build_directives_cache)
    allow(@test_source_file_directive_resolver).to receive(:validate!)

    @preprocessinator_stage = described_class.new(
      configurator: @configurator, loginator: @loginator, reportinator: @reportinator, batchinator: @batchinator,
      preprocessinator: @preprocessinator, test_context_extractor: @test_context_extractor, file_path_utils: @file_path_utils, file_wrapper: @file_wrapper,
      dependinator: @dependinator, test_source_file_directive_resolver: @test_source_file_directive_resolver
    )
  end

  context "#preprocess" do
    before(:each) do
      allow(@configurator).to receive(:test_build_preprocess_directives_only_available).and_return( false )
      allow(@configurator).to receive(:project_build_vendor_ceedling_path).and_return( 'build/vendor/ceedling' )
      allow(@file_path_utils).to receive(:form_preprocessed_file_filepath).and_return( 'build/preprocess/files/TestFoo.c' )
      allow(@test_context_extractor).to receive(:lookup_all_header_includes_list).and_return( [] )
      allow(@test_context_extractor).to receive(:lookup_build_directive_sources_list).and_return( [] )
      allow(@configurator).to receive(:extension_source).and_return( FilenameExtension.new('.c') )
      allow(@configurator).to receive(:test_build_use_assembly).and_return( false )
      allow(@test_context_extractor).to receive(:collect_simple_context_from_file)
      allow(@reportinator).to receive(:generate_progress).and_return( '' )
      allow(@loginator).to receive(:log)

      @testable = TestInvokerTypes::Testable.new(
        :name               => 'a_test',
        :filepath           => 'test/TestFoo.c',
        :preprocess         => { :directives_only => { :filepath => nil } },
        :preprocess_flags   => [], :preprocess_defines => [], :search_paths => [],
        :runner             => TestInvokerTypes::RunnerInfo.new( :output_filepath => 'build/test/runners/TestFoo_runner.c', :input_filepath => nil )
      )
      @state = TestInvokerTypes::PipelineState.new( :testables => { :a_test => @testable }, :lock => Mutex.new, :context => :test, :options => [] )
    end

    it "preprocesses and marks fresh the test file, storing its output as the runner input, when the dependency tracker reports it stale" do
      allow(@dependinator).to receive(:stale?).and_return( true )
      expect(@preprocessinator).to receive(:preprocess_test_file).and_return( 'build/preprocess/files/TestFoo.c' )
      expect(@dependinator).to receive(:mark_fresh).with('build/preprocess/files/TestFoo.c')

      @preprocessinator_stage.preprocess( @state )

      expect( @testable.runner.input_filepath ).to eq('build/preprocess/files/TestFoo.c')
    end

    it "skips preprocessing and reuses the deterministic path as the runner input when the dependency tracker reports it unchanged" do
      allow(@dependinator).to receive(:stale?).and_return( false )
      expect(@preprocessinator).to_not receive(:preprocess_test_file)
      expect(@dependinator).to_not receive(:mark_fresh)

      @preprocessinator_stage.preprocess( @state )

      expect( @testable.runner.input_filepath ).to eq('build/preprocess/files/TestFoo.c')
    end

    it "scans and caches source directive macros when the dependency tracker reports it stale" do
      allow(@dependinator).to receive(:stale?).and_return( true )
      allow(@preprocessinator).to receive(:preprocess_test_file).and_return( 'build/preprocess/files/TestFoo.c' )

      expect(@test_context_extractor).to receive(:collect_simple_context_from_file)
      expect(@test_context_extractor).to receive(:store_build_directives_cache).with(
        filepath: 'test/TestFoo.c', cache_filepath: 'build/preprocess/build_directives/a_test/TestFoo.c_source_files.yml'
      )
      expect(@test_context_extractor).to_not receive(:load_build_directives_cache)

      @preprocessinator_stage.preprocess( @state )
    end

    # The cache is recalled whenever the preprocessed file is fresh, so that file vouches
    # for it. Recording it as an output before marking fresh is what makes damage visible.
    it "stores the directive cache, then registers it as an output, before marking the test file fresh" do
      cache = 'build/preprocess/build_directives/a_test/TestFoo.c_source_files.yml'
      allow(@dependinator).to receive(:stale?).and_return( true )
      allow(@preprocessinator).to receive(:preprocess_test_file).and_return( 'build/preprocess/files/TestFoo.c' )

      expect(@test_context_extractor).to receive(:store_build_directives_cache).ordered
      expect(@dependinator).to receive(:register).with( 'build/preprocess/files/TestFoo.c', outputs: [cache] ).ordered
      expect(@dependinator).to receive(:mark_fresh).with( 'build/preprocess/files/TestFoo.c' ).ordered

      @preprocessinator_stage.preprocess( @state )
    end

    it "leaves the test file unmarked when scanning its directive macros fails" do
      allow(@dependinator).to receive(:stale?).and_return( true )
      allow(@preprocessinator).to receive(:preprocess_test_file).and_return( 'build/preprocess/files/TestFoo.c' )
      allow(@test_context_extractor).to receive(:collect_simple_context_from_file).and_raise( CeedlingException.new( 'scan failed' ) )

      expect(@dependinator).to_not receive(:mark_fresh)
      expect { @preprocessinator_stage.preprocess( @state ) }.to raise_error( CeedlingException )
    end

    it "recalls cached source directive macros instead of scanning when the dependency tracker reports it unchanged" do
      allow(@dependinator).to receive(:stale?).and_return( false )

      expect(@test_context_extractor).to_not receive(:collect_simple_context_from_file)
      expect(@test_context_extractor).to receive(:load_build_directives_cache).with(
        filepath: 'test/TestFoo.c', cache_filepath: 'build/preprocess/build_directives/a_test/TestFoo.c_source_files.yml'
      )

      @preprocessinator_stage.preprocess( @state )
    end

    it "logs a summary line stating how many test files' preprocessing (and source directive macros) were recalled from cache" do
      allow(@dependinator).to receive(:stale?).and_return( false )

      allow(@reportinator).to receive(:generate_skip_summary).and_return( "Skipping test file preprocessing for 1 test file (nothing changed)..." )

      expect(@loginator).to receive(:log).with( "Skipping test file preprocessing for 1 test file (nothing changed)..." )
      @preprocessinator_stage.preprocess( @state )
    end

    it "validates a test's TEST_SOURCE_FILE() entries through the resolver, regardless of staleness" do
      allow(@dependinator).to receive(:stale?).and_return( false )

      expect(@test_source_file_directive_resolver).to receive(:validate!).with( test: 'a_test', filepath: 'test/TestFoo.c' )

      @preprocessinator_stage.preprocess( @state )
    end
  end

  # The full expansion reads every header the test reaches, so a change to one of them
  # reruns the step, as a compile's .d file makes a compile rerun
  context "#preprocess (dependencies)" do
    before(:each) do
      allow(@batchinator).to receive(:exec) do |things:, **_options, &block|
        things.each { |k, v| block.call(k, v) }
      end
      allow(@configurator).to receive(:test_build_preprocess_directives_only_available).and_return( false )
      allow(@file_path_utils).to receive(:form_preprocessed_file_filepath).and_return( 'build/preprocess/files/TestFoo.c' )
      allow(@test_context_extractor).to receive(:lookup_all_header_includes_list).and_return( [] )
      allow(@test_context_extractor).to receive(:collect_simple_context_from_file)
      allow(@preprocessinator).to receive(:preprocessed_dependencies).with( preprocessed_filepath: 'build/preprocess/full/TestFoo.c' )
        .and_return( ['test/TestFoo.c', 'build/test/mocks/a_test/mock_config.h', 'src/features.h'] )

      @testable = TestInvokerTypes::Testable.new(
        :name => 'a_test', :filepath => 'test/TestFoo.c', :preprocess => { :directives_only => { :filepath => nil } },
        :preprocess_flags => [], :preprocess_defines => [], :search_paths => [],
        :runner => TestInvokerTypes::RunnerInfo.new( :output_filepath => 'build/test/runners/TestFoo_runner.c', :input_filepath => nil )
      )
      @state = TestInvokerTypes::PipelineState.new( :testables => { :a_test => @testable }, :lock => Mutex.new, :context => :test, :options => [] )
    end

    it "registers the project files its last expansion entered, before asking whether it is stale" do
      allow(@file_wrapper).to receive(:exist?).with( 'build/preprocess/full/TestFoo.c' ).and_return( true )

      expect(@dependinator).to receive(:register).with( 'build/preprocess/files/TestFoo.c', files: ['test/TestFoo.c', 'src/features.h'] ).ordered
      expect(@dependinator).to receive(:stale?).with( 'build/preprocess/files/TestFoo.c' ).ordered.and_return( false )

      @preprocessinator_stage.preprocess( @state )
    end

    it "registers the project files its new expansion entered before marking it fresh" do
      allow(@dependinator).to receive(:stale?).and_return( true )
      allow(@preprocessinator).to receive(:preprocess_test_file).and_return( 'build/preprocess/files/TestFoo.c' )

      expect(@dependinator).to receive(:register).with( 'build/preprocess/files/TestFoo.c', files: ['test/TestFoo.c', 'src/features.h'] ).ordered
      expect(@dependinator).to receive(:mark_fresh).with( 'build/preprocess/files/TestFoo.c' ).ordered

      @preprocessinator_stage.preprocess( @state )
    end
  end
end
