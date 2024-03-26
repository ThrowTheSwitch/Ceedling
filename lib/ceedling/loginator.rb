
class Loginator

  attr_reader :project_logging

  constructor :file_wrapper, :system_wrapper

  def setup()
    @project_logging = false
    @log_filepath = nil
  end

  def set_logfile( log_filepath )
    if !log_filepath.empty?
      @project_logging = true
      @log_filepath = log_filepath
    end
  end

  def log(string, heading='')
    return if not @project_logging
  
    output = "#{heading} | #{@system_wrapper.time_now}\n#{string.strip}\n"

    @file_wrapper.write( @log_filepath, output, 'a' )
  end
  
end
