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

describe Configurator do

  before(:each) do
    @ruby_expandinator = RubyExpandinator.new

    @configurator = described_class.new({
      configurator_setup:   double('configurator_setup').as_null_object,
      configurator_builder: double('configurator_builder').as_null_object,
      configurator_plugins: double('configurator_plugins').as_null_object,
      config_walkinator:    double('config_walkinator').as_null_object,
      yaml_wrapper:         double('yaml_wrapper').as_null_object,
      system_wrapper:       double('system_wrapper').as_null_object,
      loginator:            double('loginator').as_null_object,
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

end
