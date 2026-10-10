# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Integration coverage for configuration validation against a real project tree.
#
# Whether a configured path exists, and what a glob yields, are filesystem facts. The
# real ConfiguratorValidator and FileWrapper run here against a temp project directory.
# spec/units/config/configurator_validator_spec.rb owns every decision observable
# through a doubled file layer.

require 'spec_helper'
require 'config_yaml_helper'
require 'configurator_integration_helper'

describe 'Configurator validation (integration)' do
  include ConfigYamlHelper
  include ConfiguratorIntegrationHelpers

  let(:validator) { configurator_objects( quiet_loginator )[:configurator_validator] }

  let(:files) do
    {
      'src/a.c'               => "\n",
      'src/drivers/b.c'       => "\n",
      'src/[legacy]/c.c'      => "\n",
      'test/support/helper.h' => "\n"
    }
  end

  def paths_config(*paths)
    config_from_yaml( ":paths:\n  :source:\n" + paths.map { |path| "    - '#{path}'\n" }.join )
  end

  def files_config(*paths)
    config_from_yaml( ":files:\n  :source:\n" + paths.map { |path| "    - '#{path}'\n" }.join )
  end

  it 'accepts directories, recursive globs, and bracket-named directories under :paths' do
    in_temp_project( files ) do
      config = paths_config( 'src', 'src/**', '-:src/drivers', 'src/[legacy]' )

      expect(validator.validate_path_list( config, :paths, :source )).to be true
      expect(validator.validate_paths_entries( config, :source )).to be true
    end
  end

  it 'reports a :paths entry that does not exist' do
    in_temp_project( files ) do
      expect(validator.validate_path_list( paths_config( 'src/missing/**' ), :paths, :source )).to be false
      expect(logged.join).to include("'src/missing' does not exist in the filesystem")
    end
  end

  it 'warns about and ignores a :paths entry naming a file' do
    in_temp_project( files ) do
      expect(validator.validate_paths_entries( paths_config( 'src/a.c' ), :source )).to be true
      expect(logged.join).to include("'src/a.c' is a filepath and will be ignored")
    end
  end

  it 'reports a :paths glob that yields no directories' do
    in_temp_project( files ) do
      expect(validator.validate_paths_entries( paths_config( 'src/nothing*' ), :source )).to be false
      expect(logged.join).to include("'src/nothing*' yielded no directories")
    end
  end

  it 'accepts files and file globs, including in bracket-named directories, under :files' do
    in_temp_project( files ) do
      expect(validator.validate_files_entries( files_config( 'src/a.c', 'src/**/*.c', '-:src/[legacy]/c.c' ), :source )).to be true
    end
  end

  it 'warns about and ignores a :files entry naming a directory' do
    in_temp_project( files ) do
      expect(validator.validate_files_entries( files_config( 'src/drivers' ), :source )).to be true
      expect(logged.join).to include("'src/drivers' is a directory path and will be ignored")
    end
  end

  it 'reports a :files glob that yields no files' do
    in_temp_project( files ) do
      expect(validator.validate_files_entries( files_config( 'src/*.cpp' ), :source )).to be false
      expect(logged.join).to include("'src/*.cpp' yielded no files")
    end
  end

  it 'checks a simple path such as a Unity helper' do
    in_temp_project( files ) do
      expect(validator.validate_filepath_simple( 'test/support/helper.h', :cmock, :unity_helper_path )).to be true
      expect(validator.validate_filepath_simple( 'test/support/missing.h', :cmock, :unity_helper_path )).to be false
    end
  end
end
