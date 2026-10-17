# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/test_invoker/test_runner_generatinator'
require 'ceedling/test_invoker/test_invoker_types'

describe TestRunnerGeneratinator do
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
    @generator = double( "Generator" )

    @runners = described_class.new(
      configurator: @configurator, loginator: @loginator, reportinator: @reportinator, batchinator: @batchinator,
      generator: @generator, test_context_extractor: @test_context_extractor, dependinator: @dependinator
    )
  end

  context "#collect_details" do
    before(:each) do
      allow(@configurator).to receive(:project_config_hash).and_return( {} )
      allow(@configurator).to receive(:get_runner_config).and_return( {} )
      allow(@configurator).to receive(:get_unity_config).and_return( {} )
      allow(@configurator).to receive(:project_use_test_preprocessor_tests).and_return( true )
      allow(@test_context_extractor).to receive(:collect_test_runner_details)

      @testable = TestInvokerTypes::Testable.new(
        :name     => 'a_test',
        :filepath => 'test/TestFoo.c',
        :runner   => TestInvokerTypes::RunnerInfo.new( :output_filepath => 'build/test/runners/TestFoo_runner.c', :input_filepath => 'build/preprocess/files/TestFoo.c' )
      )
      @state = TestInvokerTypes::PipelineState.new( :testables => { :a_test => @testable }, :lock => Mutex.new, :context => :test, :options => [] )
    end

    it "parses test case names when the runner target the dependency tracker reports is stale" do
      allow(@dependinator).to receive(:stale?).and_return( true )

      expect(@test_context_extractor).to receive(:collect_test_runner_details).with( 'test/TestFoo.c', 'build/preprocess/files/TestFoo.c' )

      @runners.collect_details( @state )
    end

    it "does nothing when the runner target the dependency tracker reports is unchanged" do
      allow(@dependinator).to receive(:stale?).and_return( false )

      expect(@test_context_extractor).to_not receive(:collect_test_runner_details)

      @runners.collect_details( @state )
    end

    it "registers the real test runner and Unity configuration as meta, not project_config_hash's flattened (and therefore always-empty) :test_runner/:unity entries" do
      # project_config_hash is flattened -- these sections live there as individual
      # top-level keys like :unity_use_param_tests, never as :test_runner/:unity
      # sections -- so a config change in either can only be detected here via
      # get_runner_config/get_unity_config.
      allow(@configurator).to receive(:get_runner_config).and_return( { mock_prefix: 'Custom' } )
      allow(@configurator).to receive(:get_unity_config).and_return( { use_param_tests: true } )
      allow(@dependinator).to receive(:stale?).and_return( true )

      expect(@dependinator).to receive(:register).with(
        'build/test/runners/TestFoo_runner.c',
        files: anything,
        meta:  { test_runner: { mock_prefix: 'Custom' }, unity: { use_param_tests: true }, test_preprocessor_tests: true }
      )

      @runners.collect_details( @state )
    end

    it "registers the same target and meta stage 13 uses for the runner itself" do
      allow(@dependinator).to receive(:stale?).and_return( true )

      expect(@dependinator).to receive(:register).with(
        'build/test/runners/TestFoo_runner.c',
        files: ['test/TestFoo.c'],
        meta:  { test_runner: {}, unity: {}, test_preprocessor_tests: true }
      )

      @runners.collect_details( @state )
    end

    it "logs a summary line stating how many test files' test case name parsing was recalled from cache" do
      allow(@dependinator).to receive(:stale?).and_return( false )

      allow(@reportinator).to receive(:generate_skip_summary).and_return( "Skipping test case name parsing for 1 test file (nothing changed)..." )

      expect(@loginator).to receive(:log).with( "Skipping test case name parsing for 1 test file (nothing changed)..." )
      @runners.collect_details( @state )
    end
  end

  context "#generate" do
    before(:each) do
      allow(@configurator).to receive(:project_config_hash).and_return( {} )
      allow(@configurator).to receive(:get_runner_config).and_return( {} )
      allow(@configurator).to receive(:get_unity_config).and_return( {} )
      allow(@configurator).to receive(:project_use_test_preprocessor_tests).and_return( true )
      allow(@test_context_extractor).to receive(:lookup_mock_header_includes_list).and_return( [] )
      allow(@test_context_extractor).to receive(:lookup_nonmock_header_includes_list).and_return( [] )

      @testable = TestInvokerTypes::Testable.new(
        :name     => 'a_test',
        :filepath => 'test/TestFoo.c',
        :runner   => TestInvokerTypes::RunnerInfo.new( :output_filepath => 'build/test/runners/TestFoo_runner.c', :input_filepath => 'test/TestFoo.c' )
      )
      @state = TestInvokerTypes::PipelineState.new( :testables => { :a_test => @testable }, :lock => Mutex.new, :context => :test, :options => [] )
    end

    it "generates and marks fresh the runner when the dependency tracker reports it stale" do
      allow(@dependinator).to receive(:stale?).and_return( true )
      expect(@generator).to receive(:generate_test_runner)
      expect(@dependinator).to receive(:mark_fresh).with('build/test/runners/TestFoo_runner.c')

      @runners.generate( @state )
    end

    it "skips generating the runner when the dependency tracker reports it unchanged" do
      allow(@dependinator).to receive(:stale?).and_return( false )
      expect(@generator).to_not receive(:generate_test_runner)
      expect(@dependinator).to_not receive(:mark_fresh)

      @runners.generate( @state )
    end

    it "logs a summary line stating how many test runners were recalled from cache" do
      allow(@dependinator).to receive(:stale?).and_return( false )

      allow(@reportinator).to receive(:generate_skip_summary).and_return( "Skipping test runner generation for 1 test runner (nothing changed)..." )

      expect(@loginator).to receive(:log).with( "Skipping test runner generation for 1 test runner (nothing changed)..." )
      @runners.generate( @state )
    end

    it "includes whether test files are preprocessed in the registered meta, so toggling it invalidates the runner" do
      allow(@generator).to receive(:generate_test_runner)

      expect(@dependinator).to receive(:register).with(
        'build/test/runners/TestFoo_runner.c',
        files: ['test/TestFoo.c'],
        meta:  hash_including( test_preprocessor_tests: true )
      )

      @runners.generate( @state )
    end
  end
end
