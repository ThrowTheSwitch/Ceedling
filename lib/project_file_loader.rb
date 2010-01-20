
DEFAULT_CEEDLING_PROJECT_FILE = 'project.yml'

class ProjectFileLoader

  attr_reader :project_file

  constructor :yaml_wrapper, :stream_wrapper, :file_wrapper


  def find_project_file
    if(@file_wrapper.exists?(DEFAULT_CEEDLING_PROJECT_FILE))
      @project_file = DEFAULT_CEEDLING_PROJECT_FILE
      return
    end
    
    if ( not ENV['CEEDLING_PROJECT_FILE'].nil? and @file_wrapper.exists?(ENV['CEEDLING_PROJECT_FILE']) )
      @project_file = ENV['CEEDLING_PROJECT_FILE']
      return
    end
    
    # no verbosity checking since this is lowest level anyhow & verbosity checking depends on configurator which needs this class
    @stream_wrapper.stderr_puts('Found no test project file (*.yml)')
    raise
  end

  def load_project
    return @yaml_wrapper.load(@project_file)
  end

  
end
