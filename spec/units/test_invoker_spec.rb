# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/test_invoker/test_invoker'
require 'ceedling/exceptions'
require 'ceedling/system_wrapper'

describe TestInvoker do
  before(:each) do
    @application            = double( "Application" )
    @plugin_manager         = double( "PluginManager" )
    @dependinator           = double( "Dependinator" )
    @loginator              = double( "Loginator" )
    @verbosinator           = double( "Verbosinator" )
    @test_pipeline_manager  = double( "TestPipelineManager" )

    allow(@plugin_manager).to receive(:pre_test_build)
    allow(@plugin_manager).to receive(:post_test_build)
    allow(@dependinator).to receive(:open)
    allow(@dependinator).to receive(:flush)
    allow(@test_pipeline_manager).to receive(:run)

    @invoker = described_class.new(
      {
        :application            => @application,
        :plugin_manager         => @plugin_manager,
        :dependinator           => @dependinator,
        :loginator              => @loginator,
        :verbosinator           => @verbosinator,
        :test_pipeline_manager  => @test_pipeline_manager
      }
    )
  end

  describe "#setup_and_invoke" do
    it "builds pipeline state carrying the given tests, context, and options, and runs it through the pipeline manager" do
      expect(@test_pipeline_manager).to receive(:run) do |state|
        expect( state.tests ).to eq( ['test/TestFoo.c'] )
        expect( state.context ).to eq( :test )
        expect( state.options ).to eq( [:build_only] )
      end

      @invoker.setup_and_invoke( tests: ['test/TestFoo.c'], context: :test, options: [:build_only] )
    end

    it "defaults context to TEST_SYM and options to an empty list" do
      expect(@test_pipeline_manager).to receive(:run) do |state|
        expect( state.context ).to eq( TEST_SYM )
        expect( state.options ).to eq( [] )
      end

      @invoker.setup_and_invoke( tests: ['test/TestFoo.c'] )
    end

    it "opens and flushes the dependency cache, and fires the pre/post test-build plugin hooks, around the run" do
      expect(@plugin_manager).to receive(:pre_test_build).ordered
      expect(@dependinator).to receive(:open).ordered
      expect(@test_pipeline_manager).to receive(:run).ordered
      expect(@dependinator).to receive(:flush).ordered
      expect(@plugin_manager).to receive(:post_test_build).ordered

      @invoker.setup_and_invoke( tests: [] )
    end

    it "flushes with refresh_dependencies true only when that option is present" do
      expect(@dependinator).to receive(:flush).with( refresh_dependencies: true )
      @invoker.setup_and_invoke( tests: [], options: [:refresh_dependencies] )
    end

    it "flushes with refresh_dependencies false when that option is absent" do
      expect(@dependinator).to receive(:flush).with( refresh_dependencies: false )
      @invoker.setup_and_invoke( tests: [], options: [:build_only] )
    end

    it "catches an exception raised while running the pipeline, logs it, and registers a build failure rather than propagating it" do
      allow(@test_pipeline_manager).to receive(:run).and_raise( CeedlingException.new("mutually exclusive options") )
      allow(@loginator).to receive(:log)
      allow(@loginator).to receive(:log_debug_backtrace)

      expect(@application).to receive(:register_build_failure)
      expect(@loginator).to receive(:log).with( "mutually exclusive options", Verbosity::ERRORS, LogLabels::EXCEPTION )

      expect { @invoker.setup_and_invoke( tests: [] ) }.to_not raise_error
    end

    it "still flushes the dependency cache and fires the post-build hook after a caught exception" do
      allow(@test_pipeline_manager).to receive(:run).and_raise( CeedlingException.new("boom") )
      allow(@application).to receive(:register_build_failure)
      allow(@loginator).to receive(:log)
      allow(@loginator).to receive(:log_debug_backtrace)

      expect(@dependinator).to receive(:flush)
      expect(@plugin_manager).to receive(:post_test_build)

      @invoker.setup_and_invoke( tests: [] )
    end
  end

  describe "#each_test_with_sources" do
    it "yields each test's name and sources after a run" do
      testable = TestInvokerTypes::Testable.new( :name => 'a_test', :sources => ['src/Foo.c'] )
      allow(@test_pipeline_manager).to receive(:run) do |state|
        state.testables[:a_test] = testable
      end

      @invoker.setup_and_invoke( tests: [] )

      yielded = []
      @invoker.each_test_with_sources { |test, sources| yielded << [test, sources] }

      expect( yielded ).to eq( [['a_test', ['src/Foo.c']]] )
    end
  end
end