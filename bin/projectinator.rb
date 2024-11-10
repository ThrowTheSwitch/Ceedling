# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants' # From Ceedling application

class Projectinator

  PROJECT_FILEPATH_ENV_VAR = 'CEEDLING_PROJECT_FILE'
  DEFAULT_PROJECT_FILEPATH = './' + DEFAULT_PROJECT_FILENAME
  DEFAULT_YAML_FILE_EXTENSION = '.yml'

  constructor :file_wrapper, :path_validator, :yaml_wrapper, :loginator, :system_wrapper

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
      @path_validator.standardize_paths( filepath )
      _filepath = File.expand_path( filepath )
      config = load_and_log( _filepath, 'from command line argument', silent )
      return _filepath, config

    # Next priority: environment variable
    elsif env[PROJECT_FILEPATH_ENV_VAR]
      # ENV lookup is frozen so dup() to operate on the string
      filepath = env[PROJECT_FILEPATH_ENV_VAR].dup()
      @path_validator.standardize_paths( filepath )
      _filepath = File.expand_path( filepath )
      config = load_and_log( 
        _filepath,
        "from environment variable `#{PROJECT_FILEPATH_ENV_VAR}`",
        silent
      )
      return _filepath, config

    # Final option: default filepath
    elsif @file_wrapper.exist?( DEFAULT_PROJECT_FILEPATH )
      filepath = DEFAULT_PROJECT_FILEPATH
      _filepath = File.expand_path( filepath )
      config = load_and_log( _filepath, "from working directory", silent )
      return _filepath, config

    # If no user provided filepath and the default filepath does not exist,
    # we have a big problem
    else
      raise "No project filepath provided and default #{DEFAULT_PROJECT_FILEPATH} not found"
    end

    # We'll never get here but return nil/empty for completeness
    return nil, {}
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

    # Handle any inline Ruby string expansion
    load_paths.each do |load_path|
      load_path.replace( @system_wrapper.module_eval( load_path ) ) if (load_path =~ RUBY_STRING_REPLACEMENT_PATTERN)
    end

    enabled.each do |mixin|
      mixin.replace( @system_wrapper.module_eval( mixin ) ) if (mixin =~ RUBY_STRING_REPLACEMENT_PATTERN)
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
  def validate_mixins(mixins:, load_paths:, builtins:, source:, yaml_extension:)
    validated = true

    mixins.each do |mixin|
      # Validate mixin filepaths
      if @path_validator.filepath?( mixin )
        if !@file_wrapper.exist?( mixin )
          @loginator.log( "Cannot find mixin at #{mixin}", Verbosity::ERRORS )
          validated = false
        end

      # Otherwise, validate that mixin name can be found in load paths or builtins
      else
        found = false
        load_paths.each do |path|
          if @file_wrapper.exist?( File.join( path, mixin + yaml_extension ) )
            found = true
            break
          end
        end

        builtins.keys.each {|key| found = true if (mixin == key.to_s)}

        if !found
          msg = "#{source} '#{mixin}' cannot be found in mixin load paths as '#{mixin + yaml_extension}' or among built-in mixins"
          @loginator.log( msg, Verbosity::ERRORS )
          validated = false
        end
      end
    end

    return validated
  end


  # Yield ordered list of filepaths or built-in mixin names
  def lookup_mixins(mixins:, load_paths:, builtins:, yaml_extension:)
    _mixins = []

    # Already validated, so we know:
    #  1. Any mixin filepaths exists
    #  2. Built-in mixin names exist in the internal hash

    # Fill filepaths array with filepaths or builtin names
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
      # It's a built-in mixin.
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
        msg  = "Loaded #{'(empty) ' if config.empty?}project configuration #{method}.\n"
        msg += " > Using: #{filepath}\n"
        msg += " > Working directory: #{Dir.pwd()}"

        @loginator.log( msg, Verbosity::NORMAL, LogLabels::CONSTRUCT )
      end

      return config
    rescue Errno::ENOENT
      # Handle special case of user-provided blank filepath
      filepath = filepath.empty?() ? '<none>' : filepath
      raise "Could not find project filepath #{filepath} #{method}"

    rescue StandardError => e
      # Catch-all error handling
      raise "Error loading project filepath #{filepath} #{method}: #{e.message}"
    end

  end

end
