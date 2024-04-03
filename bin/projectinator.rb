require 'ceedling/constants' # From Ceedling application

class Projectinator

  PROJECT_FILEPATH_ENV_VAR = 'CEEDLING_PROJECT_FILE'
  DEFAULT_PROJECT_FILEPATH = './' + DEFAULT_PROJECT_FILENAME

  constructor :file_wrapper, :path_validator, :yaml_wrapper, :logger

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
      config = load_filepath( filepath, 'from command line argument', silent )
      return File.expand_path( filepath ), config

    # Next priority: environment variable
    elsif env[PROJECT_FILEPATH_ENV_VAR]
      filepath = env[PROJECT_FILEPATH_ENV_VAR]
      @path_validator.standardize_paths( filepath )
      config = load_filepath( 
        filepath,
        "from environment variable `#{PROJECT_FILEPATH_ENV_VAR}`",
        silent
      )
      return File.expand_path( filepath ), config

    # Final option: default filepath
    elsif @file_wrapper.exist?( DEFAULT_PROJECT_FILEPATH )
      filepath = DEFAULT_PROJECT_FILEPATH
      config = load_filepath( filepath, "at default location", silent )
      return File.expand_path( filepath ), config

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
  def config_available?(filepath:nil, env:{})
    available = true

    begin
      load(filepath:filepath, env:env, silent:true)
    rescue
      available = false
    end

    return available
  end


  # Pick apart a :mixins projcet configuration section and return components
  # Layout mirrors :plugins section
  def extract_mixins(config:, mixins_base_path:)
    # Get mixins config hash
    _mixins = config[:mixins]

    # If no :mixins section, return:
    #  - Empty enabled list
    #  - Load paths with only the built-in Ceedling mixins/ path
    return [], [mixins_base_path] if _mixins.nil?

    # Build list of load paths
    # Configured load paths are higher in search path ordering
    load_paths = _mixins[:load_paths] || []
    load_paths += [mixins_base_path] # += forces a copy of configuration section

    # Get list of mixins
    enabled = _mixins[:enabled] || []
    enabled = enabled.clone # Ensure it's a copy of configuration section

    # Remove the :mixins section of the configuration
    config.delete( :mixins )

    return enabled, load_paths
  end

  # Validate :load_paths from :mixins section in project configuration
  def validate_mixin_load_paths(load_paths)
    validated = @path_validator.validate(
      paths: load_paths,
      source: 'Config :mixins ↳ :load_paths',
      type: :directory
    )

    if !validated
      raise 'Project configuration file section :mixins failed validation'
    end
  end

  # Validate mixins list
  def validate_mixins(mixins:, load_paths:, source:)
    validated = true

    mixins.each do |mixin|
      # Validate mixin filepaths
      if !File.extname( mixin ).empty? or mixin.include?( File::SEPARATOR )
        if !@file_wrapper.exist?( mixin )
          @logger.log( "ERROR: Cannot find mixin at #{mixin}" )
          validated = false
        end

      # Otherwise, validate that mixin name can be found among the load paths
      else
        found = false
        load_paths.each do |path|
          if @file_wrapper.exist?( File.join( path, mixin + '.yml') )
            found = true
            break
          end
        end

        if !found
          @logger.log( "ERROR: #{source} '#{mixin}' cannot be found in the mixin load paths" )
          validated = false
        end
      end
    end

    return validated
  end

  # Yield ordered list of filepaths
  def lookup_mixins(mixins:, load_paths:)
    filepaths = []

    # Fill results hash with mixin name => mixin filepath
    # Already validated, so we know the mixin filepath exists
    mixins.each do |mixin|
      # Handle explicit filepaths
      if !File.extname( mixin ).empty? or mixin.include?( File::SEPARATOR )
        filepaths << mixin

      # Find name in load_paths (we already know it exists from previous validation)
      else
        load_paths.each do |path|
          filepath = File.join( path, mixin + '.yml' )
          if @file_wrapper.exist?( filepath )
            filepaths << filepath
            break
          end
        end
      end
    end

    return filepaths
  end

  ### Private ###

  private

  def load_filepath(filepath, method, silent)
    begin
      # Load the filepath we settled on as our project configuration
      config = @yaml_wrapper.load( filepath )

      # A blank configuration file is technically an option (assuming mixins are merged)
      # Redefine config as empty hash
      config = {} if config.nil?

      # Log what the heck we loaded
      @logger.log( "🌱 Loaded #{'(empty) ' if config.empty?}project configuration #{method} using #{filepath}" ) if !silent

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