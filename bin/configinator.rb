require 'deep_merge'

class Configinator

  MIXINS_BASE_PATH = File.join( CEEDLING_ROOT, 'mixins' )

  constructor :config_walkinator, :projectinator, :mixinator

  def loadinate(filepath:nil, mixins:[])
    # Aliases for clarity
    cmdline_filepath = filepath
    cmdline_mixins = mixins

    # Load raw config from command line, environment variable, or default filepath
    config = @projectinator.load( filepath:cmdline_filepath, env:ENV )

    # Extract cfg_enabled_mixins mixins list plus load paths list from config
    cfg_enabled_mixins, cfg_load_paths = @projectinator.extract_mixins(
      config: config,
      mixins_base_path: MIXINS_BASE_PATH
    )

    # Remove any silly redundancies
    cfg_enabled_mixins.uniq!
    # Use absolute path to ensure proper deduplication
    cfg_load_paths.uniq! { |path| File.expand_path(path) }
    cmdline_mixins.uniq!

    # Validate :cfg_load_paths from :mixins section of project configuration
    @projectinator.validate_mixin_load_paths( cfg_load_paths )

    # Validate enabled mixins from :mixins section of project configuration
    if not @projectinator.validate_mixins(
      mixins: cfg_enabled_mixins,
      load_paths: cfg_load_paths,
      source: 'Config :mixins ↳ :cfg_enabled_mixins =>'
    )
      raise 'Project configuration file section :mixins failed validation'
    end

    # Validate command line mixins
    if not @projectinator.validate_mixins(
      mixins: cmdline_mixins,
      load_paths: cfg_load_paths,
      source: 'Mixin'
    )
      raise 'Command line failed validation'
    end

    # Find mixins from project file among load paths
    # Return ordered list of filepaths
    config_mixins = @projectinator.lookup_mixins(
      mixins: cfg_enabled_mixins,
      load_paths: cfg_load_paths,
    )

    # Find mixins from command line among load paths
    # Return ordered list of filepaths
    cmdline_mixins = @projectinator.lookup_mixins(
      mixins: cmdline_mixins,
      load_paths: cfg_load_paths,
    )

    # Fetch CEEDLING_MIXIN_# environment variables and sort into ordered list of hash tuples [{env variable => filepath}...]
    env_mixins = @mixinator.fetch_env_filepaths( ENV )
    @mixinator.validate_env_filepaths( env_mixins )
    # Redefine list as just filepaths
    env_mixins = env_mixins.map {|entry| entry.values[0] }

    # Eliminate duplicate mixins and return a list of filepaths in merge order
    mixin_filepaths = @mixinator.dedup_mixins(
      config: config_mixins,
      env: env_mixins,
      cmdline: cmdline_mixins
    )

    # Merge mixins
    @mixinator.merge( config:config, filepaths:mixin_filepaths )

    return config
  end

  def default_tasks(config:, default_tasks:)
    #  1. If :default_tasks set in config, use it
    #  2. Otherwise use the function argument (most likely a default set in the first moments of startup)
    walked = @config_walkinator.fetch_value( config, :project, :default_tasks )
    if walked[:value]
      # Update method parameter to config value
      default_tasks = walked[:value].dup()
    else
      # Set key/value in config if it's not set
      config[:project][:default_tasks] = default_tasks
    end

    return default_tasks
  end

end