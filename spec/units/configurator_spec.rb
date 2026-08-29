# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/config/configurator'
require 'ceedling/ruby_expandinator'
require 'ceedling/exceptions'
require 'ceedling/constants'

describe Configurator do

  before(:each) do
    @ruby_expandinator = RubyExpandinator.new
    @loginator = double('loginator').as_null_object

    @configurator = described_class.new({
      configurator_setup:   double('configurator_setup').as_null_object,
      configurator_builder: double('configurator_builder').as_null_object,
      configurator_plugins: double('configurator_plugins').as_null_object,
      config_walkinator:    double('config_walkinator').as_null_object,
      yaml_wrapper:         double('yaml_wrapper').as_null_object,
      system_wrapper:       double('system_wrapper').as_null_object,
      loginator:            @loginator,
      reportinator:         double('reportinator').as_null_object,
      ruby_expandinator:    @ruby_expandinator,
    })
  end

  # Minimal config skeleton with all keys required by standardize_paths.
  # Individual tests override only the section under test with dirty paths.
  def base_config
    {
      project:      { build_root: 'build/out' },
      release_build: { artifacts: 'build/release' },
      paths:        {},
      files:        {},
      tools:        {},
    }
  end

  describe "#standardize_paths" do

    it "should standardize [:project][:build_root]" do
      config = base_config
      config[:project][:build_root] = 'build\\root\\'

      @configurator.standardize_paths( config )

      expect( config[:project][:build_root] ).to eq( 'build/root' )
    end

    it "should standardize [:paths]" do
      config = base_config
      config[:paths] = { test: ['test\\src\\'] }

      @configurator.standardize_paths( config )

      expect( config[:paths][:test] ).to eq( ['test/src'] )
    end

    it "should standardize [:files]" do
      config = base_config
      config[:files] = { test: ['test\\file.c'] }

      @configurator.standardize_paths( config )

      expect( config[:files][:test].first ).to eq( 'test/file.c' )
    end

    it "should standardize [:tools] executables" do
      config = base_config
      config[:tools] = { compiler: { executable: 'path\\to\\gcc\\' } }

      @configurator.standardize_paths( config )

      expect( config[:tools][:compiler][:executable] ).to eq( 'path/to/gcc' )
    end

    it "should standardize paths at _path/_paths convention keys in any top-level section" do
      config = base_config
      config[:cmock] = { mock_path: 'build\\mocks\\' }

      @configurator.standardize_paths( config )

      expect( config[:cmock][:mock_path] ).to eq( 'build/mocks' )
    end

  end

  # Scoped narrowly to the inline Ruby string expansion (--ruby-replacement) gating
  # threaded through each call site via RubyExpandinator#expand. Uses a real
  # RubyExpandinator instance (not a double) so the enable/disable gate is exercised
  # end-to-end, mirroring ruby_expandinator_spec.rb's own coverage of the gate itself.
  describe "Ruby string expansion gating" do

    it "raises CeedlingException from #eval_paths when disabled and a path contains the pattern" do
      config = base_config
      config[:project][:build_root] = '#{1+1}'

      expect { @configurator.eval_paths( config ) }.to raise_error(CeedlingException, /:project/)
    end

    it "expands via #eval_paths when enabled" do
      @ruby_expandinator.enable!
      config = base_config
      config[:project][:build_root] = '#{1+1}'

      @configurator.eval_paths( config )

      expect( config[:project][:build_root] ).to eq( '2' )
    end

    it "raises CeedlingException from #eval_flags when disabled and a flag contains the pattern" do
      config = base_config
      config[:flags] = { test: { compile: ['#{1+1}'] } }

      expect { @configurator.eval_flags( config ) }.to raise_error(CeedlingException)
    end

    it "expands via #eval_flags when enabled" do
      @ruby_expandinator.enable!
      config = base_config
      config[:flags] = { test: { compile: ['#{1+1}'] } }

      @configurator.eval_flags( config )

      expect( config[:flags][:test][:compile] ).to eq( ['2'] )
    end

    it "raises CeedlingException from #eval_defines when disabled and a define contains the pattern" do
      config = base_config
      config[:defines] = { test: ['#{1+1}'] }

      expect { @configurator.eval_defines( config ) }.to raise_error(CeedlingException)
    end

    it "expands via #eval_defines when enabled" do
      @ruby_expandinator.enable!
      config = base_config
      config[:defines] = { test: ['#{1+1}'] }

      @configurator.eval_defines( config )

      expect( config[:defines][:test] ).to eq( ['2'] )
    end

    it "raises CeedlingException from #eval_environment_variables when disabled and a value contains the pattern" do
      config = base_config
      config[:environment] = [ { some_var: '#{1+1}' } ]

      expect { @configurator.eval_environment_variables( config ) }.to raise_error(CeedlingException, /:environment/)
    end

    it "expands via #eval_environment_variables when enabled" do
      @ruby_expandinator.enable!
      config = base_config
      config[:environment] = [ { some_var: '#{1+1}' } ]

      @configurator.eval_environment_variables( config )

      expect( config[:environment].first[:some_var] ).to eq( '2' )
    end

    it "raises CeedlingException from #prepare_plugins_load_paths when disabled and a load path contains the pattern" do
      config = base_config
      config[:plugins] = { load_paths: ['#{1+1}'] }

      expect {
        @configurator.prepare_plugins_load_paths( 'plugins/path', config )
      }.to raise_error(CeedlingException, /:plugins/)
    end

    it "expands via #prepare_plugins_load_paths when enabled" do
      @ruby_expandinator.enable!
      config = base_config
      config[:plugins] = { load_paths: ['#{1+1}'] }

      @configurator.prepare_plugins_load_paths( 'plugins/path', config )

      expect( config[:plugins][:load_paths] ).to include( '2' )
    end

  end

  describe "#populate_test_runner_generation_config" do

    def runner_config
      {
        project:     { use_backtrace: :none },
        cmock:       { mock_prefix: 'Mock', mock_suffix: '_x', enforce_strict_ordering: true },
        unity:       { defines: ['UNITY_DEFINE'], use_param_tests: false, shuffle_tests: false },
        test_runner: { cmdline_args: false, defines: ['RUNNER_DEFINE'] },
      }
    end

    it "copies CMock options used by test runner generation" do
      config = runner_config

      @configurator.populate_test_runner_generation_config( config )

      expect( config[:test_runner][:mock_prefix] ).to eq( 'Mock' )
      expect( config[:test_runner][:mock_suffix] ).to eq( '_x' )
      expect( config[:test_runner][:enforce_strict_ordering] ).to eq( true )
    end

    it "merges Unity defines and :use_param_tests into test runner config" do
      config = runner_config
      config[:unity][:use_param_tests] = true

      @configurator.populate_test_runner_generation_config( config )

      expect( config[:test_runner][:defines] ).to eq( ['RUNNER_DEFINE', 'UNITY_DEFINE'] )
      expect( config[:test_runner][:use_param_tests] ).to eq( true )
    end

    it "carries :unity ↳ :shuffle_tests into test runner config when enabled" do
      config = runner_config
      config[:unity][:shuffle_tests] = true

      @configurator.populate_test_runner_generation_config( config )

      expect( config[:test_runner][:shuffle_tests] ).to eq( true )
    end

    it "carries :unity ↳ :shuffle_tests into test runner config when disabled" do
      config = runner_config
      config[:unity][:shuffle_tests] = false

      @configurator.populate_test_runner_generation_config( config )

      expect( config[:test_runner][:shuffle_tests] ).to eq( false )
    end

    it "forces :cmdline_args on and logs a notice when :use_backtrace is enabled" do
      config = runner_config
      config[:project][:use_backtrace] = :simple
      config[:test_runner][:cmdline_args] = false

      expect( @loginator ).to receive(:log).with( /:cmdline_args/, Verbosity::COMPLAIN, LogLabels::NOTICE )

      @configurator.populate_test_runner_generation_config( config )

      expect( config[:test_runner][:cmdline_args] ).to eq( true )
    end

    it "leaves :cmdline_args untouched when :use_backtrace is :none" do
      config = runner_config
      config[:test_runner][:cmdline_args] = false

      @configurator.populate_test_runner_generation_config( config )

      expect( config[:test_runner][:cmdline_args] ).to eq( false )
    end

  end

  describe "#set_partials_derived_config" do

    def partials_config
      { project: { use_partials: true }, defines: { test: ['TEST'] }, cmock: {} }
    end

    it "does nothing when :use_partials is disabled" do
      config = partials_config
      config[:project][:use_partials] = false

      @configurator.set_partials_derived_config( config )

      expect( config[:defines][:test] ).to eq( ['TEST'] )
      expect( config[:defines] ).to_not have_key( :preprocess )
    end

    it "leaves :defines: config untouched -- CEEDLING_PARTIALS_PREFIX is TestBuildSetup's concern, delivered unconditionally alongside other framework defines" do
      config = partials_config

      @configurator.set_partials_derived_config( config )

      expect( config[:defines][:test] ).to eq( ['TEST'] )
      expect( config[:defines] ).to_not have_key( :preprocess )
    end

  end

  describe "#populate_partials_config / #get_partials_config" do

    it "returns the :partials section handed to populate_partials_config" do
      config = { partials: { max_extraction_length: 5000 } }

      @configurator.populate_partials_config( config )

      expect( @configurator.get_partials_config ).to eq( { max_extraction_length: 5000 } )
    end

    it "returns a clone, not the same object populate_partials_config was given -- callers may mutate their own copy freely" do
      config = { partials: { max_extraction_length: 5000 } }
      @configurator.populate_partials_config( config )

      returned = @configurator.get_partials_config
      returned[:max_extraction_length] = 1

      expect( @configurator.get_partials_config[:max_extraction_length] ).to eq( 5000 )
    end

    it "defaults to an empty hash before populate_partials_config has ever run" do
      expect( @configurator.get_partials_config ).to eq( {} )
    end

  end

end
