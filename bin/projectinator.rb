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

  constructor :file_wrapper, :path_validator, :yaml_wrapper, :loginator, :system_wrapper, :ruby_expandinator

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


  # Pick apart a :mixins projcet configuration section and return components
  # Layout mirrors :plugins section
  def extract_mixins(config:)
    # Get mixins config hash
    _mixins = config[:mixins]

    # If no :mixins section, return:
    #  - Empty enabled list
    #  - Empty load paths
    return [], [] if _mixins.nil?

    # Build list of load paths
    # Configured load paths are higher in search path ordering
    load_paths = _mixins[:load_paths] || []

    # Get list of mixins
    enabled = _mixins[:enabled] || []
    enabled = enabled.clone # Ensure it's a copy of configuration section

    # Handle any inline Ruby string expansion, then standardize Windows backslashes --
    # cmdline and env var mixin paths already go through standardize_paths elsewhere,
    # so config :mixins section paths need the same treatment for consistency.
    load_paths.each do |load_path|
      load_path.replace( @ruby_expandinator.expand( load_path, source: ":mixins ↳ :load_paths" ) )
      load_path.replace( @path_validator.standardize_paths( load_path ).first )
    end

    enabled.each do |mixin|
      mixin.replace( @ruby_expandinator.expand( mixin, source: ":mixins ↳ :enabled" ) )
      mixin.replace( @path_validator.standardize_paths( mixin ).first )
    end

    # Remove the :mixins section of the configuration
    config.delete( :mixins )

    return enabled, load_paths
  end


  # Validate :load_paths from :mixins section in project configuration
  def validate_mixin_load_paths(load_paths)
    validated = @path_validator.validate(
      paths: load_paths,
      source: 'Config :mixins ↳ :load_paths =>',
      type: :directory
    )

    if !validated
      raise 'Project configuration file section :mixins failed validation'
    end
  end


  # Validate mixins list
  def validate_mixins(mixins:, load_paths:, source:, yaml_extension:)
    validated = true

    mixins.each do |mixin|
      # Validate mixin filepaths
      if @path_validator.filepath?( mixin )
        if !@file_wrapper.exist?( mixin )
          @loginator.log( "Cannot find mixin at #{mixin}", Verbosity::ERRORS )
          validated = false
        end

      # Otherwise, validate that mixin name can be found in load paths
      else
        found = false
        load_paths.each do |path|
          if @file_wrapper.exist?( File.join( path, mixin + yaml_extension ) )
            found = true
            break
          end
        end

        if !found
          msg = "#{source} '#{mixin}' cannot be found in mixin load paths as '#{mixin + yaml_extension}'"
          @loginator.log( msg, Verbosity::ERRORS )
          validated = false
        end
      end
    end

    return validated
  end


  # Yield ordered list of filepaths
  def lookup_mixins(mixins:, load_paths:, yaml_extension:)
    _mixins = []

    # Already validated, so we know any mixin filepath or name is found in load_paths

    # Fill filepaths array with filepaths
    mixins.each do |mixin|
      # Handle explicit filepaths
      if @path_validator.filepath?( mixin )
        _mixins << mixin
        next # Success, move on in mixin iteration
      end

      # Look for mixin in load paths.
      # Move on in mixin iteration if mixin is found.
      next if load_paths.any? do |path|
        filepath = File.join( path, mixin + yaml_extension )
        exist = @file_wrapper.exist?( filepath )
        _mixins << filepath if exist
        exist
      end

      # Finally, fall through to simply add the unmodified name to the list.
      # validate_mixins() should have already confirmed it exists in load_paths.
      _mixins << mixin
    end

    return _mixins
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
