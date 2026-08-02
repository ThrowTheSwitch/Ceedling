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
    @loginator                = double( "Loginator" )
    @reportinator               = double( "Reportinator" )
    @batchinator                  = double( "Batchinator" )
    @test_context_extractor          = double( "TestContextExtractor" )
    @include_pathinator                 = double( "IncludePathinator" )
    @preprocessinator                      = double( "Preprocessinator" )
    @defineinator                             = double( "Defineinator" )
    @flaginator                                  = double( "Flaginator" )
    @file_wrapper                                   = double( "FileWrapper" )
    @file_path_utils                                   = double( "FilePathUtils" )
    @test_runner_manager                                  = double( "TestRunnerManager" )
    @dependinator                                            = double( "Dependinator" )

    allow(@batchinator).to receive(:exec) do |workload:, things:, &block|
      things.each { |k, v| block.call(k, v) }
    end

    allow(@reportinator).to receive(:generate_module_progress).and_return( '' )
    allow(@loginator).to receive(:log)

    # First pass (bare includes extraction, its own pre-existing mtime-based
    # cache) is out of scope for this coverage -- short-circuited via its own
    # cache hit so these specs stay focused on the second pass.
    allow(@preprocessinator).to receive(:cached_includes_list?).and_return( true )

    # Third pass similarly short-circuited via its own cache hit.
    allow(@preprocessinator).to receive(:load_includes_list).and_return( [true, []] )
    allow(@test_context_extractor).to receive(:ingest_includes)

    allow(@configurator).to receive(:project_build_vendor_ceedling_path).and_return( 'build/vendor/ceedling' )
    allow(@file_path_utils).to receive(:form_preprocessed_file_raw_directives_only_filepath).and_return( 'build/preprocess/raw/Foo.txt' )

    allow(@dependinator).to receive(:register)
    allow(@dependinator).to receive(:mark_fresh)

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
        :test_runner_manager    => @test_runner_manager,
        :dependinator           => @dependinator
      }
    )

    @testable = TestInvokerTypes::Testable.new(
      :name               => 'a_test',
      :filepath           => 'test/TestFoo.c',
      :preprocess         => { :includes => [], :directives_only => { :filepath => nil } },
      :preprocess_flags   => [],
      :preprocess_defines => [],
      :search_paths       => []
    )
    @state = TestInvokerTypes::PipelineState.new( :testables => { :a_test => @testable }, :context => :test, :options => {} )
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
      expect(@dependinator).to_not receive(:mark_fresh)

      @setup.stage_collect_preprocessor_context( @state )

      expect( @testable.preprocess[:directives_only][:filepath] ).to be_nil
    end

    it "does nothing when directives-only preprocessing is unavailable for this toolchain" do
      allow(@configurator).to receive(:test_build_preprocess_directives_only_available).and_return( false )
      expect(@dependinator).to_not receive(:register)
      expect(@preprocessinator).to_not receive(:generate_directives_only_output)

      @setup.stage_collect_preprocessor_context( @state )
    end
  end
end
