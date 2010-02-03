
DEFAULT_CEEDLING_MAIN_PROJECT_FILE = 'project.yml' # main project file
DEFAULT_CEEDLING_USER_PROJECT_FILE = 'user.yml'    # supplemental user config file

class ProjectFileLoader

  attr_reader :main_project_filepath, :user_project_filepath

  constructor :yaml_wrapper, :stream_wrapper, :file_wrapper

  def setup
    @main_project_filepath = ''
    @user_project_filepath = ''
  end


  def find_project_files

    # first go hunting for optional user project file by looking for environment variable or default location on disk
    if ( not ENV['CEEDLING_USER_PROJECT_FILE'].nil? and @file_wrapper.exists?(ENV['CEEDLING_USER_PROJECT_FILE']) )
      @user_project_filepath = ENV['CEEDLING_USER_PROJECT_FILE']
    elsif(@file_wrapper.exists?(DEFAULT_CEEDLING_USER_PROJECT_FILE))
      @user_project_filepath = DEFAULT_CEEDLING_USER_PROJECT_FILE
    end        
    
    # next check for main project file by looking for environment variable or default location on disk;
    # blow up if we don't find this guy -- like, he's so totally important
    if ( not ENV['CEEDLING_MAIN_PROJECT_FILE'].nil? and @file_wrapper.exists?(ENV['CEEDLING_MAIN_PROJECT_FILE']) )
      @main_project_filepath = ENV['CEEDLING_MAIN_PROJECT_FILE']
    elsif(@file_wrapper.exists?(DEFAULT_CEEDLING_MAIN_PROJECT_FILE))
      @main_project_filepath = DEFAULT_CEEDLING_MAIN_PROJECT_FILE
    else
      # no verbosity checking since this is lowest level reporting anyhow &
      # verbosity checking depends on configurator which in turns needs this class (circular dependency)
      @stream_wrapper.stderr_puts('Found no Ceedling project file (*.yml)')
      raise
    end
    
  end


  def load_project_file
    # if there's no user project file, then just provide hash from project file
    return @yaml_wrapper.load(@main_project_filepath) if (@user_project_filepath.empty?)
    
    # if there is a user project file, load it too and merge it on top of the project file,
    # superseding anything that's common between them
    return (@yaml_wrapper.load(@main_project_filepath)).merge(@yaml_wrapper.load(@user_project_filepath))
  end
  
end
