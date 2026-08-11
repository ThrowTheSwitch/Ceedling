# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/test_invoker/test_pipeline_manager'
require 'ceedling/test_invoker/test_invoker_types'
require 'ceedling/exceptions'

describe TestPipelineManager do
  before(:each) do
    @test_build_setup     = double( "TestBuildSetup" )
    @test_build_planner   = double( "TestBuildPlanner" )
    @test_build_executor  = double( "TestBuildExecutor" )
    @configurator         = double( "Configurator" )
    @batchinator          = double( "Batchinator" )
    @loginator            = double( "Loginator" )

    allow(@batchinator).to receive(:build_step) { |*_args, &block| block.call }
    allow(@loginator).to receive(:log)

    allow(@configurator).to receive(:project_use_test_preprocessor_tests).and_return( false )
    allow(@configurator).to receive(:project_use_partials).and_return( false )
    allow(@configurator).to receive(:project_use_mocks).and_return( false )
    allow(@configurator).to receive(:project_use_test_preprocessor_mocks).and_return( false )

    allow(@test_build_setup).to receive(:stage_prepare_build_paths)
    allow(@test_build_setup).to receive(:stage_collect_test_context)
    allow(@test_build_setup).to receive(:stage_ingest_configurations)
    allow(@test_build_setup).to receive(:stage_collect_preprocessor_context)

    allow(@test_build_planner).to receive(:stage_determine_files)
    allow(@test_build_planner).to receive(:stage_flatten_partials_lists)
    allow(@test_build_planner).to receive(:stage_flatten_mocks_list)
    allow(@test_build_planner).to receive(:stage_determine_artifacts)
    allow(@test_build_planner).to receive(:stage_flatten_objects_list)

    allow(@test_build_executor).to receive(:stage_preprocess_partial_headers)
    allow(@test_build_executor).to receive(:stage_preprocess_partial_sources)
    allow(@test_build_executor).to receive(:stage_generate_partials)
    allow(@test_build_executor).to receive(:stage_preprocess_mocks)
    allow(@test_build_executor).to receive(:stage_generate_mocks)
    allow(@test_build_executor).to receive(:stage_preprocess_test_files)
    allow(@test_build_executor).to receive(:stage_collect_runner_details)
    allow(@test_build_executor).to receive(:stage_generate_runners)
    allow(@test_build_executor).to receive(:stage_build_objects)
    allow(@test_build_executor).to receive(:stage_build_executables)
    allow(@test_build_executor).to receive(:stage_execute)

    @manager = described_class.new(
      {
        :test_build_setup    => @test_build_setup,
        :test_build_planner  => @test_build_planner,
        :test_build_executor => @test_build_executor,
        :configurator        => @configurator,
        :batchinator         => @batchinator,
        :loginator           => @loginator
      }
    )
  end

  # Defaults every flattened list to non-empty, real-shaped-enough content, so every
  # existing test below exercises the "has work to do" path without having to know or
  # care about T1/T2's output -- exactly as it would if a project had at least one
  # Partial and one mock. Tests specifically about the "enabled but nothing to do this
  # run" case (below) override one or more of these to `[]`.
  def state(options: [], partials_headers: [double("PartialWork")], partials_sources: [double("PartialWork")], mocks_list: [double("MockWork")])
    TestInvokerTypes::PipelineState.new(
      :testables        => {}, :context => :test, :options => options,
      :partials_headers => partials_headers, :partials_sources => partials_sources, :mocks_list => mocks_list,
      :objects_list     => []
    )
  end

  describe "#run" do
    context "stop-point validation" do
      it "raises naming every stop-point option present when more than one is given" do
        expect { @manager.run( state(options: [:mocking, :build_only]) ) }
          .to raise_error( CeedlingException, /:mocking, :build_only/ )
      end

      it "does not raise with a single stop-point option" do
        expect { @manager.run( state(options: [:mocking]) ) }.to_not raise_error
      end

      it "does not raise with no options" do
        expect { @manager.run( state(options: []) ) }.to_not raise_error
      end
    end

    context "with :mocking" do
      before(:each) do
        allow(@configurator).to receive(:project_use_test_preprocessor_tests).and_return( true )
        allow(@configurator).to receive(:project_use_partials).and_return( true )
        allow(@configurator).to receive(:project_use_mocks).and_return( true )
        allow(@configurator).to receive(:project_use_test_preprocessor_mocks).and_return( true )
      end

      it "runs every stage through Mocking and stops before test-file preprocessing onward" do
        expect(@test_build_setup).to receive(:stage_prepare_build_paths)
        expect(@test_build_setup).to receive(:stage_collect_test_context)
        expect(@test_build_setup).to receive(:stage_ingest_configurations)
        expect(@test_build_setup).to receive(:stage_collect_preprocessor_context)
        expect(@test_build_planner).to receive(:stage_determine_files)
        expect(@test_build_planner).to receive(:stage_flatten_partials_lists)
        expect(@test_build_executor).to receive(:stage_preprocess_partial_headers)
        expect(@test_build_executor).to receive(:stage_preprocess_partial_sources)
        expect(@test_build_executor).to receive(:stage_generate_partials)
        expect(@test_build_planner).to receive(:stage_flatten_mocks_list)
        expect(@test_build_executor).to receive(:stage_preprocess_mocks)
        expect(@test_build_executor).to receive(:stage_generate_mocks)

        expect(@test_build_executor).to_not receive(:stage_preprocess_test_files)
        expect(@test_build_executor).to_not receive(:stage_collect_runner_details)
        expect(@test_build_executor).to_not receive(:stage_generate_runners)
        expect(@test_build_planner).to_not receive(:stage_determine_artifacts)
        expect(@test_build_planner).to_not receive(:stage_flatten_objects_list)
        expect(@test_build_executor).to_not receive(:stage_build_objects)
        expect(@test_build_executor).to_not receive(:stage_build_executables)
        expect(@test_build_executor).to_not receive(:stage_execute)

        @manager.run( state(options: [:mocking]) )
      end
    end

    context "with :test_runners" do
      before(:each) do
        allow(@configurator).to receive(:project_use_test_preprocessor_tests).and_return( true )
        allow(@configurator).to receive(:project_use_partials).and_return( true )
        allow(@configurator).to receive(:project_use_mocks).and_return( true )
        allow(@configurator).to receive(:project_use_test_preprocessor_mocks).and_return( true )
      end

      it "runs every stage through Test Runners, including Mocking along the way, and stops before artifact determination onward" do
        expect(@test_build_executor).to receive(:stage_generate_mocks)
        expect(@test_build_executor).to receive(:stage_preprocess_test_files)
        expect(@test_build_executor).to receive(:stage_collect_runner_details)
        expect(@test_build_executor).to receive(:stage_generate_runners)

        expect(@test_build_planner).to_not receive(:stage_determine_artifacts)
        expect(@test_build_planner).to_not receive(:stage_flatten_objects_list)
        expect(@test_build_executor).to_not receive(:stage_build_objects)
        expect(@test_build_executor).to_not receive(:stage_build_executables)
        expect(@test_build_executor).to_not receive(:stage_execute)

        @manager.run( state(options: [:test_runners]) )
      end
    end

    context "with :build_only" do
      it "runs through linking and stops before execution" do
        expect(@test_build_executor).to receive(:stage_build_objects)
        expect(@test_build_executor).to receive(:stage_build_executables)
        expect(@test_build_executor).to_not receive(:stage_execute)

        @manager.run( state(options: [:build_only]) )
      end
    end

    context "with :sources_only" do
      it "stops before object compilation, leaving linking and execution unrun" do
        expect(@test_build_planner).to receive(:stage_determine_artifacts)
        expect(@test_build_executor).to_not receive(:stage_build_objects)
        expect(@test_build_executor).to_not receive(:stage_build_executables)
        expect(@test_build_executor).to_not receive(:stage_execute)

        @manager.run( state(options: [:sources_only]) )
      end
    end

    context "with no stop-point options and every optional feature enabled" do
      before(:each) do
        allow(@configurator).to receive(:project_use_test_preprocessor_tests).and_return( true )
        allow(@configurator).to receive(:project_use_partials).and_return( true )
        allow(@configurator).to receive(:project_use_mocks).and_return( true )
        allow(@configurator).to receive(:project_use_test_preprocessor_mocks).and_return( true )
      end

      it "runs every stage and transform, start to finish" do
        expect(@test_build_setup).to receive(:stage_prepare_build_paths)
        expect(@test_build_setup).to receive(:stage_collect_test_context)
        expect(@test_build_setup).to receive(:stage_ingest_configurations)
        expect(@test_build_setup).to receive(:stage_collect_preprocessor_context)
        expect(@test_build_planner).to receive(:stage_determine_files)
        expect(@test_build_planner).to receive(:stage_flatten_partials_lists)
        expect(@test_build_executor).to receive(:stage_preprocess_partial_headers)
        expect(@test_build_executor).to receive(:stage_preprocess_partial_sources)
        expect(@test_build_executor).to receive(:stage_generate_partials)
        expect(@test_build_planner).to receive(:stage_flatten_mocks_list)
        expect(@test_build_executor).to receive(:stage_preprocess_mocks)
        expect(@test_build_executor).to receive(:stage_generate_mocks)
        expect(@test_build_executor).to receive(:stage_preprocess_test_files)
        expect(@test_build_executor).to receive(:stage_collect_runner_details)
        expect(@test_build_executor).to receive(:stage_generate_runners)
        expect(@test_build_planner).to receive(:stage_determine_artifacts)
        expect(@test_build_planner).to receive(:stage_flatten_objects_list)
        expect(@test_build_executor).to receive(:stage_build_objects)
        expect(@test_build_executor).to receive(:stage_build_executables)
        expect(@test_build_executor).to receive(:stage_execute)

        @manager.run( state(options: []) )
      end
    end

    context "when test preprocessing is disabled" do
      it "skips test-file preprocessing and its two dependent stages, independent of any stop-point option" do
        allow(@configurator).to receive(:project_use_test_preprocessor_tests).and_return( false )

        expect(@test_build_setup).to_not receive(:stage_collect_preprocessor_context)
        expect(@test_build_executor).to_not receive(:stage_preprocess_test_files)
        expect(@test_build_executor).to_not receive(:stage_collect_runner_details)
        expect(@test_build_executor).to receive(:stage_generate_runners)

        @manager.run( state(options: []) )
      end
    end

    context "when Partials is disabled" do
      it "skips the Partials transform and its three stages, independent of any stop-point option, in total silence" do
        allow(@configurator).to receive(:project_use_partials).and_return( false )

        expect(@test_build_planner).to_not receive(:stage_flatten_partials_lists)
        expect(@test_build_executor).to_not receive(:stage_preprocess_partial_headers)
        expect(@test_build_executor).to_not receive(:stage_preprocess_partial_sources)
        expect(@test_build_executor).to_not receive(:stage_generate_partials)
        expect(@test_build_planner).to receive(:stage_determine_files)
        expect(@loginator).to_not receive(:log)

        @manager.run( state(options: []) )
      end
    end

    context "when mocking is disabled" do
      it "skips the mocks transform and both mocking stages, independent of any stop-point option, in total silence" do
        allow(@configurator).to receive(:project_use_mocks).and_return( false )

        expect(@test_build_planner).to_not receive(:stage_flatten_mocks_list)
        expect(@test_build_executor).to_not receive(:stage_preprocess_mocks)
        expect(@test_build_executor).to_not receive(:stage_generate_mocks)
        expect(@test_build_executor).to receive(:stage_generate_runners)
        expect(@loginator).to_not receive(:log)

        @manager.run( state(options: []) )
      end
    end

    context "when Partials is enabled but this run has no Partials" do
      it "skips the three Partials stages and logs an OBNOXIOUS notice for each, instead of running them" do
        allow(@configurator).to receive(:project_use_partials).and_return( true )

        expect(@test_build_planner).to receive(:stage_flatten_partials_lists)
        expect(@test_build_executor).to_not receive(:stage_preprocess_partial_headers)
        expect(@test_build_executor).to_not receive(:stage_preprocess_partial_sources)
        expect(@test_build_executor).to_not receive(:stage_generate_partials)

        expect(@loginator).to receive(:log)
          .with( "Preprocessing for Testing & Mocking Partials: no Partials to process", Verbosity::OBNOXIOUS )
        expect(@loginator).to receive(:log)
          .with( "Preprocessing for Testing Partials: no Partials to process", Verbosity::OBNOXIOUS )
        expect(@loginator).to receive(:log)
          .with( "Partials: no Partials to generate", Verbosity::OBNOXIOUS )

        @manager.run( state(options: [], partials_headers: [], partials_sources: []) )
      end
    end

    context "when mocking is enabled but this run has no mocks" do
      it "skips both mocking stages and logs an OBNOXIOUS notice for each, instead of running them" do
        allow(@configurator).to receive(:project_use_mocks).and_return( true )
        allow(@configurator).to receive(:project_use_test_preprocessor_mocks).and_return( true )

        expect(@test_build_planner).to receive(:stage_flatten_mocks_list)
        expect(@test_build_executor).to_not receive(:stage_preprocess_mocks)
        expect(@test_build_executor).to_not receive(:stage_generate_mocks)

        expect(@loginator).to receive(:log)
          .with( "Preprocessing for Mocks: no mocks to process", Verbosity::OBNOXIOUS )
        expect(@loginator).to receive(:log)
          .with( "Mocking: no mocks to generate", Verbosity::OBNOXIOUS )

        @manager.run( state(options: [], mocks_list: []) )
      end
    end

    context "when mocking is enabled but mock preprocessing is disabled" do
      it "still generates mocks but skips preprocessing headers to be mocked" do
        allow(@configurator).to receive(:project_use_mocks).and_return( true )
        allow(@configurator).to receive(:project_use_test_preprocessor_mocks).and_return( false )

        expect(@test_build_executor).to_not receive(:stage_preprocess_mocks)
        expect(@test_build_executor).to receive(:stage_generate_mocks)

        @manager.run( state(options: []) )
      end
    end
  end
end