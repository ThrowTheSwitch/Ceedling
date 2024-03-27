
class Setupinator

  attr_reader :config_hash
  attr_writer :ceedling

  def setup
    @ceedling = {}
    @config_hash = {}
  end


  # Override to prevent exception handling from walking & stringifying the object variables.
  # Object variables are gigantic and produce a flood of output.
  def inspect
    # TODO: When identifying information is added to constructor, insert it into `inspect()` string
    return this.class.name
  end


  def do_setup( app_cfg )
    @config_hash = app_cfg[:project_config]
    log_filepath = app_cfg[:log_filepath]

    @ceedling[:configurator].include_test_case = app_cfg[:include_test_case]
    @ceedling[:configurator].exclude_test_case = app_cfg[:exclude_test_case]

    # Load up all the constants and accessors our rake files, objects, & external scripts will need.
    # Note: Configurator modifies the cmock section of the hash with a couple defaults to tie 
    #       projects together -- the modified hash is used to build the cmock object.
    @ceedling[:configurator].set_verbosity( config_hash )
    @ceedling[:configurator].populate_defaults( config_hash )
    @ceedling[:configurator].populate_unity_defaults( config_hash )
    @ceedling[:configurator].populate_cmock_defaults( config_hash )
    @ceedling[:configurator].eval_environment_variables( config_hash )
    @ceedling[:configurator].eval_paths( config_hash )
    @ceedling[:configurator].standardize_paths( config_hash )
    @ceedling[:configurator].find_and_merge_plugins( config_hash )
    @ceedling[:configurator].tools_setup( config_hash )
    @ceedling[:configurator].validate( config_hash )
    # Partially flatten config + build Configurator accessors and globals
    @ceedling[:configurator].build( config_hash, :environment )

    @ceedling[:configurator].insert_rake_plugins( @ceedling[:configurator].rake_plugins )
    @ceedling[:configurator].tools_supplement_arguments( config_hash )
    
    # Merge in any environment variables that plugins specify after the main build
    @ceedling[:plugin_manager].load_programmatic_plugins( @ceedling[:configurator].programmatic_plugins, @ceedling ) do |env|
      @ceedling[:configurator].eval_environment_variables( env )
      @ceedling[:configurator].build_supplement( config_hash, env )
    end
    
    @ceedling[:plugin_reportinator].set_system_objects( @ceedling )

    # Logging set up
    @ceedling[:loginator].set_logfile( form_log_filepath( log_filepath ) )
    @ceedling[:configurator].project_logging = @ceedling[:loginator].project_logging
  end

  def reset_defaults(config_hash)
    @ceedling[:configurator].reset_defaults( config_hash )
  end

### Private

private

  def form_log_filepath( log_filepath )
    # Bail out early if logging is disabled
    return log_filepath if log_filepath.empty?()

    # If there's no directory path, put named log file in default location
    if File.dirname( log_filepath ).empty?()
      return File.join( @ceedling[:configurator].project_log_path, log_filepath )
    end

    # Otherwise, log filepath includes a directory (that's already been created)
    return log_filepath
  end

end
