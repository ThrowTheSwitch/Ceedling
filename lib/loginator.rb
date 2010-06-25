
class Loginator

  constructor :configurator, :file_wrapper, :system_wrapper

  def log(string, heading=nil)
    return if (not @configurator.project_logging)
  
    output  = "\n[#{@system_wrapper.time_now}]"
    output += " :: #{heading}" if (not heading.nil?)
    output += "\n#{string.strip}\n"

    @file_wrapper.write(@configurator.project_log_filepath, output, 'a')
  end
  
end
