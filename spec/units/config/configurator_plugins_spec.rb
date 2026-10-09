# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'config_yaml_helper'
require 'ceedling/config/configurator_plugins'

# Unit coverage for plugin discovery through doubled file and system layers. Discovery
# of real plugin directories on disk is proven in
# spec/integration/configurator_plugins_spec.rb.
describe ConfiguratorPlugins do
  include ConfigYamlHelper

  before(:each) do
    @file_wrapper   = double('file_wrapper')
    @system_wrapper = double('system_wrapper', add_load_path: nil)
    @plugins        = described_class.new( { file_wrapper: @file_wrapper, system_wrapper: @system_wrapper } )

    allow(@file_wrapper).to receive(:directory_listing).and_return([])
    allow(@file_wrapper).to receive(:exist?).and_return(false)
  end

  let(:config) do
    config_from_yaml( <<~YAML )
      :plugins:
        :load_paths:
          - first
          - second
        :enabled:
          - alpha
          - beta
    YAML
  end

  # Lays out plugin content as directory listings, keyed by the glob that finds it
  def listing(pattern, *files)
    allow(@file_wrapper).to receive(:directory_listing).with(pattern).and_return(files)
  end

  def files(*paths)
    allow(@file_wrapper).to receive(:exist?) { |path| paths.include?( path ) }
  end

  it 'names only its class when inspected' do
    expect(@plugins.inspect).to eq('ConfiguratorPlugins')
  end

  describe '#process_aux_load_paths' do
    it 'adds every configured load path to the Ruby load path' do
      @plugins.process_aux_load_paths( config )

      expect(@system_wrapper).to have_received(:add_load_path).with('first')
      expect(@system_wrapper).to have_received(:add_load_path).with('second')
    end

    it 'finds a plugin by its lib/ Ruby files and adds lib/ to the load path' do
      listing('second/alpha/lib/*.rb', 'second/alpha/lib/alpha.rb')

      expect(@plugins.process_aux_load_paths( config )).to eq( { alpha_path: 'second/alpha' } )
      expect(@system_wrapper).to have_received(:add_load_path).with('second/alpha/lib')
    end

    it 'finds a plugin by its config/ Ruby files and adds config/ to the load path' do
      listing('first/alpha/config/*.rb', 'first/alpha/config/defaults_alpha.rb')

      expect(@plugins.process_aux_load_paths( config )).to eq( { alpha_path: 'first/alpha' } )
      expect(@system_wrapper).to have_received(:add_load_path).with('first/alpha/config')
    end

    it 'finds a plugin by its Rakefile' do
      listing('first/beta/*.rake', 'first/beta/beta.rake')

      expect(@plugins.process_aux_load_paths( config )).to eq( { beta_path: 'first/beta' } )
    end

    it 'takes a plugin from the first load path that holds it' do
      listing('first/alpha/lib/*.rb', 'first/alpha/lib/alpha.rb')
      listing('second/alpha/lib/*.rb', 'second/alpha/lib/alpha.rb')

      expect(@plugins.process_aux_load_paths( config )).to eq( { alpha_path: 'first/alpha' } )
    end

    it 'escapes literal brackets in a load path before globbing' do
      config[:plugins][:load_paths] = ['[vendor]']
      listing('\[vendor\]/alpha/lib/*.rb', '[vendor]/alpha/lib/alpha.rb')

      expect(@plugins.process_aux_load_paths( config )).to eq( { alpha_path: '[vendor]/alpha' } )
    end

    it 'omits a plugin found nowhere' do
      expect(@plugins.process_aux_load_paths( config )).to eq( {} )
    end
  end

  describe 'plugin discovery from found plugin paths' do
    let(:paths) { { alpha_path: 'plugins/alpha', beta_path: 'plugins/beta' } }

    it 'finds Rakefiles named for their plugin' do
      files('plugins/beta/beta.rake')

      expect(@plugins.find_rake_plugins( config, paths )).to eq( [ { plugin: 'beta', path: 'plugins/beta/beta.rake' } ] )
      expect(@plugins.rake_plugins).to eq( [ { plugin: 'beta', path: 'plugins/beta/beta.rake' } ] )
    end

    it 'finds programmatic plugins by lib/<plugin>.rb' do
      files('plugins/alpha/lib/alpha.rb')

      expect(@plugins.find_programmatic_plugins( config, paths )).to eq( [ { plugin: 'alpha', root_path: 'plugins/alpha' } ] )
      expect(@plugins.programmatic_plugins).to eq( [ { plugin: 'alpha', root_path: 'plugins/alpha' } ] )
    end

    it 'finds configuration plugins by config/<plugin>.yml' do
      files('plugins/beta/config/beta.yml')

      expect(@plugins.find_config_plugins( config, paths )).to eq( [ { plugin: 'beta', path: 'plugins/beta/config/beta.yml' } ] )
      expect(@plugins.config_plugins).to eq( [ { plugin: 'beta', path: 'plugins/beta/config/beta.yml' } ] )
    end

    it 'finds YAML defaults by config/defaults.yml' do
      files('plugins/alpha/config/defaults.yml')

      expect(@plugins.find_plugin_yml_defaults( config, paths )).to eq( { alpha: 'plugins/alpha/config/defaults.yml' } )
    end

    it 'finds Ruby defaults by config/defaults_<plugin>.rb and calls the get_default_config() it defines' do
      files('plugins/beta/config/defaults_beta.rb')
      allow(@system_wrapper).to receive(:require_file).with('defaults_beta.rb') do
        @plugins.define_singleton_method(:get_default_config) { { beta: { level: 3 } } }
      end

      expect(@plugins.find_plugin_hash_defaults( config, paths )).to eq( { beta: { beta: { level: 3 } } } )
    end

    it 'skips an enabled plugin with no found path' do
      files('plugins/beta/beta.rake')

      expect(@plugins.find_rake_plugins( config, { beta_path: 'plugins/beta' } ).map { |p| p[:plugin] }).to eq( ['beta'] )
      expect(@plugins.find_programmatic_plugins( config, {} )).to eq( [] )
    end

    it 'replaces earlier discoveries on a later call' do
      files('plugins/beta/beta.rake')
      @plugins.find_rake_plugins( config, paths )

      expect(@plugins.find_rake_plugins( config, {} )).to eq( [] )
      expect(@plugins.rake_plugins).to eq( [] )
    end
  end
end
