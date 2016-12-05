require 'ceedling/constants'


class ProjectFileLoader

  attr_reader :main_file, :extra_file, :user_file

  constructor :yaml_wrapper, :stream_wrapper, :system_wrapper, :file_wrapper

  def setup
    @main_file = nil
    @extra_file = nil
    @user_file = nil
    
    @main_project_filepath = ''
    @extra_project_filepath = ''
    @user_project_filepath = ''
  end


  def find_project_files
    # first go hunting for optional extra project file by looking for environment variable and then default location on disk
    extra_filepath = @system_wrapper.env_get('CEEDLING_EXTRA_PROJECT_FILE')
    
    if ( not extra_filepath.nil? and @file_wrapper.exist?(extra_filepath) )
      @extra_project_filepath = extra_filepath
    elsif (@file_wrapper.exist?(DEFAULT_CEEDLING_EXTRA_PROJECT_FILE))
      @extra_project_filepath = DEFAULT_CEEDLING_EXTRA_PROJECT_FILE
    end
    
    # next go hunting for optional user project file by looking for environment variable and then default location on disk
    user_filepath = @system_wrapper.env_get('CEEDLING_USER_PROJECT_FILE')
    
    if ( not user_filepath.nil? and @file_wrapper.exist?(user_filepath) )
      @user_project_filepath = user_filepath
    elsif (@file_wrapper.exist?(DEFAULT_CEEDLING_USER_PROJECT_FILE))
      @user_project_filepath = DEFAULT_CEEDLING_USER_PROJECT_FILE
    end
    
    # next check for main project file by looking for environment variable and then default location on disk;
    # blow up if we don't find this guy -- like, he's so totally important
    main_filepath = @system_wrapper.env_get('CEEDLING_MAIN_PROJECT_FILE')
    
    if ( not main_filepath.nil? and @file_wrapper.exist?(main_filepath) )
      @main_project_filepath = main_filepath
    elsif (@file_wrapper.exist?(DEFAULT_CEEDLING_MAIN_PROJECT_FILE))
      @main_project_filepath = DEFAULT_CEEDLING_MAIN_PROJECT_FILE
    else
      # no verbosity checking since this is lowest level reporting anyhow &
      # verbosity checking depends on configurator which in turns needs this class (circular dependency)
      @stream_wrapper.stderr_puts('Found no Ceedling project file (*.yml)')
      raise
    end
    
    @main_file = File.basename( @main_project_filepath )
    @extra_file = File.basename( @extra_project_filepath ) if ( not @extra_project_filepath.empty? )
    @user_file = File.basename( @user_project_filepath ) if ( not @user_project_filepath.empty? )
  end


  def load_project_config
    config_hash = {}
    project_hast = {}
    extra_hash = {}
    user_hash = {}

    # load project hash from project file if existing
    if ( not @main_project_filepath.empty? )
      project_hash = @yaml_wrapper.load(@main_project_filepath)
    end

    # load extra hash from extra file if existing
    if ( not @extra_project_filepath.empty? )
      extra_hash = @yaml_wrapper.load(@extra_project_filepath)
    end

    # load user hash from user file if existing
    if ( not @user_project_filepath.empty? )
      user_hash = @yaml_wrapper.load(@user_project_filepath)
    end

    config_hash = project_hash.merge(extra_hash).merge(user_hash)

    return config_hash
  end
      
end
