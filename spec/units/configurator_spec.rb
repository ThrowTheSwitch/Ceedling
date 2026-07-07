# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/config/configurator'

describe Configurator do

  before(:each) do
    @configurator = described_class.new({
      configurator_setup:   double('configurator_setup').as_null_object,
      configurator_builder: double('configurator_builder').as_null_object,
      configurator_plugins: double('configurator_plugins').as_null_object,
      config_walkinator:    double('config_walkinator').as_null_object,
      yaml_wrapper:         double('yaml_wrapper').as_null_object,
      system_wrapper:       double('system_wrapper').as_null_object,
      loginator:            double('loginator').as_null_object,
      reportinator:         double('reportinator').as_null_object,
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

end
