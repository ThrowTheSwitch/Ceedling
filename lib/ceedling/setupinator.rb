
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


  def load_project_files
    @ceedling[:project_file_loader].find_project_files
    return @ceedling[:project_file_loader].load_project_config
  end

  def do_setup(config_hash)
    @config_hash = config_hash

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
    @ceedling[:configurator].merge_imports( config_hash )
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
    @ceedling[:loginator].project_log_filepath = form_log_filepath()
    @ceedling[:project_config_manager].config_hash = config_hash
  end

  def reset_defaults(config_hash)
    @ceedling[:configurator].reset_defaults( config_hash )
  end

### Private

private

  def form_log_filepath()
    # Various project files and options files can combine to create different configurations.
    # Different configurations means different behaviors.
    # As these variations are easy to run from the command line, a resulting log file 
    # should differentiate its context.
    # We do this by concatenating config/options names into a log filename.

    config_files = []

    config_files << @ceedling[:project_file_loader].main_file
    config_files << @ceedling[:project_file_loader].user_file
    config_files += @ceedling[:project_config_manager].options_files
    config_files.compact! # Remove empties
    
    # Drop component file name extensions and smoosh together with underscores
    log_name = config_files.map{ |file| file.ext('') }.join( '_' )

    return File.join( @ceedling[:configurator].project_log_path, log_name.ext('.log') )
  end

end
