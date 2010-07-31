require 'rubygems'
require 'rake' # for ext()
require 'constants'


class ProjectConfigManager

  attr_reader :main_project_filepath, :user_project_filepath, :input_config_cache_filepath
  attr_accessor :project_options_filepath

  constructor :yaml_wrapper, :stream_wrapper, :system_wrapper, :file_wrapper

  def setup
    @main_project_filepath = ''
    @user_project_filepath = ''
    
    # only used outside this file
    @project_options_filepath = ''
    
    @input_config_cache_filepath          = ''
    @previous_input_config_cache_filepath = ''
  end


  def find_project_files

    # first go hunting for optional user project file by looking for environment variable and then default location on disk
    user_file = @system_wrapper.env_get('CEEDLING_USER_PROJECT_FILE')
    
    if ( not user_file.nil? and @file_wrapper.exist?(user_file) )
      @user_project_filepath = user_file
    elsif (@file_wrapper.exist?(DEFAULT_CEEDLING_USER_PROJECT_FILE))
      @user_project_filepath = DEFAULT_CEEDLING_USER_PROJECT_FILE
    end        
    
    # next check for main project file by looking for environment variable and then default location on disk;
    # blow up if we don't find this guy -- like, he's so totally important
    main_file = @system_wrapper.env_get('CEEDLING_MAIN_PROJECT_FILE')
    
    if ( not main_file.nil? and @file_wrapper.exist?(main_file) )
      @main_project_filepath = main_file
    elsif (@file_wrapper.exist?(DEFAULT_CEEDLING_MAIN_PROJECT_FILE))
      @main_project_filepath = DEFAULT_CEEDLING_MAIN_PROJECT_FILE
    else
      # no verbosity checking since this is lowest level reporting anyhow &
      # verbosity checking depends on configurator which in turns needs this class (circular dependency)
      @stream_wrapper.stderr_puts('Found no Ceedling project file (*.yml)')
      raise
    end
    
  end


  def load_project_configuration
    config_hash = {}
    
    # if there's no user project file, then just provide hash from project file
    if (@user_project_filepath.empty?)
      config_hash = @yaml_wrapper.load(@main_project_filepath)
    # if there is a user project file, load it too and merge it on top of the project file,
    # superseding anything that's common between them
    else
      config_hash = (@yaml_wrapper.load(@main_project_filepath)).merge(@yaml_wrapper.load(@user_project_filepath))
    end
    
    return config_hash
  end
  
  
  def cache_project_configuration(path, config)
    @input_config_cache_filepath          = File.join(path, 'input_config.yml')
    @previous_input_config_cache_filepath = @input_config_cache_filepath.ext('.previous')

    @file_wrapper.cp( @input_config_cache_filepath, @previous_input_config_cache_filepath ) if @file_wrapper.exist?(@input_config_cache_filepath)
    @yaml_wrapper.dump( @input_config_cache_filepath, config )
  end
  
  
  def input_configuration_changed_from_last_run?
    return false if not @file_wrapper.exist?(@input_config_cache_filepath)
    return false if not @file_wrapper.exist?(@previous_input_config_cache_filepath)
    
    return !(@yaml_wrapper.load(@input_config_cache_filepath) == @yaml_wrapper.load(@previous_input_config_cache_filepath))
  end

end
