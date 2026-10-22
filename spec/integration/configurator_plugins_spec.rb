# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Integration coverage for plugin discovery and plugin configuration.
#
# Plugins of each kind the plugin development guide describes are laid out on disk in a
# temp project and enabled through a YAML project configuration. The real configuration
# pipeline then finds them, merges their configuration and defaults, and validates them.
# spec/units/config/configurator_plugins_spec.rb owns discovery's decisions through
# doubled file and system layers.

require 'spec_helper'
require 'configurator_integration_helper'

describe 'Configurator plugins (integration)' do
  include ConfiguratorIntegrationHelpers

  around(:each) do |example|
    load_path = $LOAD_PATH.dup
    example.run
  ensure
    $LOAD_PATH.replace( load_path )
  end

  def with_plugins(*names)
    minimal_project_yaml + ":plugins:\n  :load_paths: [support/plugins]\n  :enabled: [#{names.join( ', ' )}]\n"
  end

  def plugin_files(name, files)
    files.to_h { |path, content| [File.join( 'support/plugins', name, path ), content] }
  end

  it 'finds a programmatic plugin and merges its YAML and Ruby defaults' do
    files = minimal_project_files
      .merge( plugin_files( 'cfg_spec_lib', 'lib/cfg_spec_lib.rb' => "\n" ) )
      .merge( plugin_files( 'cfg_spec_lib', 'config/defaults.yml' => ":cfg_spec_lib:\n  :level: 1\n  :name: yaml\n" ) )
      .merge( plugin_files( 'cfg_spec_lib', 'config/defaults_cfg_spec_lib.rb' => "def get_default_config() = { cfg_spec_lib: { name: 'ruby', size: 2 } }\n" ) )

    in_temp_project( files ) do
      objects = configure( with_plugins( 'cfg_spec_lib' ) )

      expect(objects[:configurator].programmatic_plugins).to eq( [ { plugin: 'cfg_spec_lib', root_path: 'support/plugins/cfg_spec_lib' } ] )
      expect(objects[:configurator].cfg_spec_lib_level).to eq(1)
      expect(objects[:configurator].cfg_spec_lib_name).to eq('yaml')
      expect(objects[:configurator].cfg_spec_lib_size).to eq(2)
      expect($LOAD_PATH).to include('support/plugins/cfg_spec_lib/lib', 'support/plugins/cfg_spec_lib/config')
    end
  end

  it "merges a plugin's configuration, resolving $PLUGIN_PATH in its :paths" do
    files = minimal_project_files
      .merge( plugin_files( 'cfg_spec_paths', 'lib/cfg_spec_paths.rb' => "\n", 'support/helper.c' => "\n" ) )
      .merge( plugin_files( 'cfg_spec_paths', 'config/cfg_spec_paths.yml' => ":paths:\n  :support: [$PLUGIN_PATH/support]\n" ) )

    in_temp_project( files ) do |dir|
      configurator = configure( with_plugins( 'cfg_spec_paths' ) )[:configurator]

      expect(configurator.paths_support).to eq( [ File.join( File.realpath( dir ), 'support/plugins/cfg_spec_paths/support' ) ] )
    end
  end

  it 'finds a plugin that is only a Rakefile' do
    files = minimal_project_files.merge( plugin_files( 'cfg_spec_rake', 'cfg_spec_rake.rake' => "\n" ) )

    in_temp_project( files ) do
      configurator = configure( with_plugins( 'cfg_spec_rake' ) )[:configurator]

      expect(configurator.rake_plugins).to eq( [ { plugin: 'cfg_spec_rake', path: 'support/plugins/cfg_spec_rake/cfg_spec_rake.rake' } ] )
      expect(configurator.project_rakefile_component_files).to include( 'support/plugins/cfg_spec_rake/cfg_spec_rake.rake' )
    end
  end

  it 'finds a plugin that is only YAML configuration and merges it' do
    files = minimal_project_files
      .merge( plugin_files( 'cfg_spec_yaml', 'config/cfg_spec_yaml.yml' => ":cfg_spec_yaml:\n  :volume: 11\n:paths:\n  :support: [test/support]\n" ) )
      .merge( 'test/support/.keep' => '' )

    in_temp_project( files ) do
      configurator = configure( with_plugins( 'cfg_spec_yaml' ) )[:configurator]

      expect(configurator.cfg_spec_yaml_volume).to eq(11)
      expect(configurator.paths_support).to eq( [ File.join( File.realpath( Dir.pwd ), 'test/support' ) ] )
    end
  end

# A plugin declares its build context a peer of :test in its defaults, where core
# validation reads it. Declarations from several plugins combine.
it "accepts matcher hashes for each context a plugin declares in its defaults" do
  declaring = ->(name) { plugin_files( name, "lib/#{name}.rb" => "\n", "config/defaults.yml" => ":plugins:\n  :test_build_contexts:\n    - :#{name}\n" ) }
  files = minimal_project_files.merge( declaring.( "cfg_spec_ctx_a" ) ).merge( declaring.( "cfg_spec_ctx_b" ) )
  yaml  = with_plugins( "cfg_spec_ctx_a", "cfg_spec_ctx_b" ) +
          ":defines:\n  :cfg_spec_ctx_a:\n    :Model: [A]\n:flags:\n  :cfg_spec_ctx_b:\n    :compile:\n      :*: [-g]\n"

  in_temp_project( files ) do
    configurator = configure( yaml )[:configurator]

    expect(configurator.plugins_test_build_contexts).to match_array( [:cfg_spec_ctx_a, :cfg_spec_ctx_b] )
  end
end

  it 'takes a plugin from the first load path that holds it' do
    files = minimal_project_files
      .merge( 'first/cfg_spec_twice/lib/cfg_spec_twice.rb' => "\n", 'second/cfg_spec_twice/lib/cfg_spec_twice.rb' => "\n" )

    in_temp_project( files ) do
      yaml = minimal_project_yaml + ":plugins:\n  :load_paths: [first, second]\n  :enabled: [cfg_spec_twice]\n"

      expect(configure( yaml )[:configurator].programmatic_plugins.first[:root_path]).to eq('first/cfg_spec_twice')
    end
  end

  it 'refuses an enabled plugin found nowhere' do
    in_temp_project( minimal_project_files.merge( 'support/plugins/.keep' => '' ) ) do
      expect { configure( with_plugins( 'cfg_spec_missing' ) ) }.to raise_error(CeedlingException, /failed validation/)
      expect(logged.join).to include("Plugin 'cfg_spec_missing' not found")
    end
  end
end
