# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/release_invoker/release_invoker'
require 'ceedling/exceptions'
require 'ceedling/system_wrapper'

describe ReleaseInvoker do
  before(:each) do
    @application            = double( "Application" )
    @plugin_manager         = double( "PluginManager" )
    @dependinator           = double( "Dependinator" )
    @loginator              = double( "Loginator" )
    @batchinator             = double( "Batchinator" )
    @release_build_planner  = double( "ReleaseBuildPlanner" )
    @release_build_executor = double( "ReleaseBuildExecutor" )

    allow(@plugin_manager).to receive(:pre_release_build)
    allow(@plugin_manager).to receive(:post_release_build)
    allow(@dependinator).to receive(:open)
    allow(@dependinator).to receive(:flush)
    allow(@release_build_planner).to receive(:plan)
    allow(@release_build_executor).to receive(:compile_objects)
    allow(@release_build_executor).to receive(:link)
    allow(@release_build_executor).to receive(:artifactinate)
    allow(@batchinator).to receive(:build_step) { |*_args, &block| block.call }

    @invoker = described_class.new(
      {
        :application             => @application,
        :plugin_manager          => @plugin_manager,
        :dependinator            => @dependinator,
        :loginator               => @loginator,
        :batchinator             => @batchinator,
        :release_build_planner   => @release_build_planner,
        :release_build_executor  => @release_build_executor
      }
    )
  end

  describe "#setup_and_invoke" do
    it "builds a fresh release state and plans against it, passing files through" do
      expect(@release_build_planner).to receive(:plan) do |state, files:|
        expect( state ).to be_a( ReleaseInvokerTypes::ReleaseState )
        expect( files ).to eq( ['src/Foo.c'] )
      end

      @invoker.setup_and_invoke( files: ['src/Foo.c'] )
    end

    it "defaults files to nil for a full build" do
      expect(@release_build_planner).to receive(:plan) do |_state, files:|
        expect( files ).to be_nil
      end

      @invoker.setup_and_invoke()
    end

    it "compiles objects, links, and collects artifacts, in that order, for a full build" do
      expect(@release_build_planner).to receive(:plan).ordered
      expect(@release_build_executor).to receive(:compile_objects).ordered
      expect(@release_build_executor).to receive(:link).ordered
      expect(@release_build_executor).to receive(:artifactinate).ordered

      @invoker.setup_and_invoke()
    end

    it "stops after compiling objects and never links or collects artifacts when files is given" do
      expect(@release_build_executor).to receive(:compile_objects)
      expect(@release_build_executor).to_not receive(:link)
      expect(@release_build_executor).to_not receive(:artifactinate)

      @invoker.setup_and_invoke( files: ['src/Foo.c'] )
    end

    it "opens the dependency cache under the :release identifier, and fires the pre/post release-build plugin hooks, around the run" do
      expect(@plugin_manager).to receive(:pre_release_build).ordered
      expect(@dependinator).to receive(:open).with( identifier: :release ).ordered
      expect(@release_build_planner).to receive(:plan).ordered
      expect(@release_build_executor).to receive(:compile_objects).ordered
      expect(@release_build_executor).to receive(:link).ordered
      expect(@release_build_executor).to receive(:artifactinate).ordered
      expect(@dependinator).to receive(:flush).ordered
      expect(@plugin_manager).to receive(:post_release_build).ordered

      @invoker.setup_and_invoke()
    end

    it "flushes with refresh_dependencies true for a full build" do
      expect(@dependinator).to receive(:flush).with( refresh_dependencies: true )
      @invoker.setup_and_invoke()
    end

    it "flushes with refresh_dependencies false for a files-scoped build, so untouched release targets survive" do
      expect(@dependinator).to receive(:flush).with( refresh_dependencies: false )
      @invoker.setup_and_invoke( files: ['src/Foo.c'] )
    end

    it "catches an exception raised while building, logs it, and registers a build failure rather than propagating it" do
      allow(@release_build_executor).to receive(:compile_objects).and_raise( CeedlingException.new("compile failed") )
      allow(@loginator).to receive(:log)
      allow(@loginator).to receive(:log_debug_backtrace)

      expect(@application).to receive(:register_build_failure)
      expect(@loginator).to receive(:log).with( "compile failed", Verbosity::ERRORS, LogLabels::EXCEPTION )

      expect { @invoker.setup_and_invoke() }.to_not raise_error
    end

    it "still flushes the dependency cache and fires the post-build hook after a caught exception" do
      allow(@release_build_executor).to receive(:compile_objects).and_raise( CeedlingException.new("boom") )
      allow(@application).to receive(:register_build_failure)
      allow(@loginator).to receive(:log)
      allow(@loginator).to receive(:log_debug_backtrace)

      expect(@dependinator).to receive(:flush)
      expect(@plugin_manager).to receive(:post_release_build)

      @invoker.setup_and_invoke()
    end
  end
end
