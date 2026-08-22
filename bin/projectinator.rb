# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants' # From Ceedling application
require 'ceedling/exceptions'

class Projectinator

  PROJECT_FILEPATH_ENV_VAR = 'CEEDLING_PROJECT_FILE'
  DEFAULT_PROJECT_FILEPATH = './' + DEFAULT_PROJECT_FILENAME
  DEFAULT_YAML_FILE_EXTENSION = '.yml'

  constructor :file_wrapper, :path_validator, :yaml_wrapper, :loginator

  # Discovers project file path and loads configuration.
  # Precendence of attempts:
  #  1. Explcit flepath from argument
  #  2. Environment variable
  #  3. Default filename in working directory
  # Returns:
  #  - Absolute path of project file found and used
  #  - Config hash loaded from project file
  def load(filepath:nil, env:{}, silent:false)
    # Highest priority: command line argument
    if filepath
      filepath = @path_validator.standardize_paths( filepath ).first
      _filepath = File.expand_path( filepath )
      config = load_and_log( _filepath, 'from command line argument', silent )
      config[:history] = { config: [{type: :file, path: filepath, mechanism: :project}] }
      return _filepath, config

    # Next priority: environment variable
    elsif env[PROJECT_FILEPATH_ENV_VAR]
      filepath = @path_validator.standardize_paths( env[PROJECT_FILEPATH_ENV_VAR] ).first
      _filepath = File.expand_path( filepath )
      config = load_and_log(
        _filepath,
        "from environment variable `#{PROJECT_FILEPATH_ENV_VAR}`",
        silent
      )
      config[:history] = { config: [{type: :file, path: filepath, mechanism: :project}] }
      return _filepath, config

    # Final option: default filepath
    elsif @file_wrapper.exist?( DEFAULT_PROJECT_FILEPATH )
      filepath = DEFAULT_PROJECT_FILEPATH
      _filepath = File.expand_path( filepath )
      config = load_and_log( _filepath, "from working directory", silent )
      config[:history] = { config: [{type: :file, path: filepath, mechanism: :project}] }
      return _filepath, config

    # If no user-provided filepath and the default filepath does not exist, we have a big problem
    else
      raise "No project filepath provided and default #{DEFAULT_PROJECT_FILEPATH} not found"
    end
  end


  # Determine if project configuration is available.
  #  - Simplest, default case simply tries to load default project file location.
  #  - Otherwise, attempts to load a filepath, the default environment variable, 
  #    or both can be specified.
  def config_available?(filepath:nil, env:{}, silent:true)
    available = true

    begin
      load(filepath:filepath, env:env, silent:silent)
    rescue
      available = false
    end

    return available
  end


  def lookup_yaml_extension(config:)
    return DEFAULT_YAML_FILE_EXTENSION if config[:extension].nil?

    return DEFAULT_YAML_FILE_EXTENSION if config[:extension][:yaml].nil?

    return config[:extension][:yaml]
  end


  ### Private ###

  private

  def load_and_log(filepath, method, silent)
    begin
      # Load the filepath we settled on as our project configuration
      config = @yaml_wrapper.load( filepath )

      # A blank configuration file is technically an option (assuming mixins are merged)
      # Redefine config as empty hash
      config = {} if config.nil?

      # Log what the heck we loaded
      if !silent
        @loginator.lazy( Verbosity::NORMAL, LogLabels::CONSTRUCT ) do 
          "Loaded #{'(empty) ' if config.empty?}project configuration #{method}.\n" +
          " > Using: #{filepath}\n" +
          " > Working directory: #{Dir.pwd()}"
        end
      end

      return config
    rescue YamlLoadException => e
      if e.reason == :not_found
        # Handle special case of user-provided blank filepath
        _filepath = filepath.empty?() ? '<none>' : filepath
        raise YamlLoadException.new(
          reason: e.reason, source: e.source, original_error: e.original_error,
          message: "Could not find project filepath #{_filepath} #{method}"
        )
      else
        raise YamlLoadException.new(
          reason: e.reason, source: e.source, original_error: e.original_error,
          message: "Error loading project filepath #{filepath} #{method} ⏩️ #{e.message}"
        )
      end
    end

  end

end
