
class Projectinator

  PROJECT_FILEPATH_ENV_VAR = 'CEEDLING_PROJECT_FILE'
  DEFAULT_PROJECT_FILEPATH = './project.yml'

  constructor :file_wrapper, :path_validator, :yaml_wrapper, :logger

  def load(filepath:nil, env:{})
    # Highest priority: command line argument
    if filepath
      return load_filepath( filepath, 'from command line argument' )

    # Next priority: environment variable
    elsif env[PROJECT_FILEPATH_ENV_VAR]
      return load_filepath( env[PROJECT_FILEPATH_ENV_VAR], "from environment variable `#{PROJECT_FILEPATH_ENV_VAR}`" )

    # Final option: default filepath
    elsif @file_wrapper.exist?( DEFAULT_PROJECT_FILEPATH )
      return load_filepath( DEFAULT_PROJECT_FILEPATH, "at default location" )

    # If no user provided filepath and the default filepath does not exist,
    # we have a big problem
    else
      raise "No project filepath provided and default location #{DEFAULT_PROJECT_FILEPATH} not found"
    end

    # We'll never get here but return empty configuration for completeness
    return {}
  end

  # Pick apart a :mixins projcet configuration section and return components
  # Layout mirrors :plugins section
  def extract_mixins(config:, mixins_base_path:)
    # Get mixins config hash
    _mixins = config[:mixins]

    return [], [] if _mixins.nil?

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
      found = false

      # Validate that each mixin is just a name
      if !File.extname(mixin).empty? or mixin.include?(File::SEPARATOR)
        @logger.log( "ERROR: #{source} '#{mixin}' should be a name, not a filename" )
        validated = false
        next
      end

      # Validate that each mixin can be found among the load paths
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

    return validated
  end

  # Yield ordered list of filepaths
  def lookup_mixins(mixins:, load_paths:)
    filepaths = []

    # Fill results hash with mixin name => mixin filepath
    # Already validated, so we know the mixin filepath exists
    mixins.each do |mixin|
      load_paths.each do |path|
        filepath = File.join( path, mixin + '.yml' )
        if @file_wrapper.exist?( filepath )
          filepaths << filepath
          break
        end
      end
    end

    return filepaths
  end

  ### Private ###

  private

  def load_filepath(filepath, method)
    begin
      # Load the filepath we settled on as our project configuration
      config = @yaml_wrapper.load( filepath )

      # Report if it was blank or otherwise produced no hash
      raise "Empty configuration in project filepath #{filepath} #{method}" if config.nil?

      # Log what the heck we loaded
      @logger.log( "Loaded project configuration from #{filepath}" )

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