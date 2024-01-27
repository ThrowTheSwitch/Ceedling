
class Loginator

  attr_accessor :project_logging, :project_log_filepath

  constructor :file_wrapper, :system_wrapper


  def setup()
    @project_logging = false
    @project_log_filepath = nil
  end

  def log(string, heading=nil)
    return if (not @project_logging) or @project_log_filepath.nil?
  
    output  = "\n[#{@system_wrapper.time_now}]"
    output += " :: #{heading}" if (not heading.nil?)
    output += "\n#{string.strip}\n"

    @file_wrapper.write( @project_log_filepath, output, 'a' )
  end
  
end
