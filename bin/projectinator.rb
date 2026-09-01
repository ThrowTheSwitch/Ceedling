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
  # #1250 -- self-documenting alternative default project filename, tried only
  # alongside DEFAULT_PROJECT_FILEPATH during default discovery below.
  ALTERNATE_PROJECT_FILEPATH = './' + ALTERNATE_PROJECT_FILENAME
  DEFAULT_YAML_FILE_EXTENSION = '.yml'

  constructor :file_wrapper, :path_validator, :yaml_wrapper, :loginator

  # Discovers project file path and loads configuration.
  # Precendence of attempts:
  #  1. Explcit flepath from argument
  #  2. Environment variable
  #  3. Default filename in working directory (project.yml or ceedling.yml --
  #     #1250 -- an error if both exist, since neither is "preferred" over the other)
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

    # Final option: default filepath(s) in the working directory
    else
      default_exists     = @file_wrapper.exist?( DEFAULT_PROJECT_FILEPATH )
      alternate_exists    = @file_wrapper.exist?( ALTERNATE_PROJECT_FILEPATH )

      # #1250 -- two default project files in one directory is almost certainly a
      # mistake (which one would silently win?) -- error out rather than guess.
      if default_exists && alternate_exists
        raise CeedlingException.new( ambiguous_default_message() )
      end

      filepath =
        if default_exists
          DEFAULT_PROJECT_FILEPATH
        elsif alternate_exists
          ALTERNATE_PROJECT_FILEPATH
        end

      if filepath
        _filepath = File.expand_path( filepath )
        config = load_and_log( _filepath, "from working directory", silent )
        config[:history] = { config: [{type: :file, path: filepath, mechanism: :project}] }
        return _filepath, config

      # If no user-provided filepath and neither default filepath exists, we have a big problem
      else
        raise CeedlingException.new(
          "No project filepath provided and neither default " \
          "#{DEFAULT_PROJECT_FILEPATH} nor #{ALTERNATE_PROJECT_FILEPATH} found"
        )
      end
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

  # #1250 -- mirrors PathMatcher's own ambiguous-file message style (path_matcher.rb).
  def ambiguous_default_message
    "Ambiguous default project file: both #{DEFAULT_PROJECT_FILEPATH} and " \
    "#{ALTERNATE_PROJECT_FILEPATH} exist in the working directory. " \
    "Remove or rename one, or specify which to use with --project/-p."
  end

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
