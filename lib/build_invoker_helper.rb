require 'constants'


class BuildInvokerHelper

  constructor :configurator, :streaminator
  
  def process_exception(exception, context, test_build=true)
    if (exception.message =~ /Don't know how to build task '(.+)'/i)
      error_header  = "ERROR: Rake could not find file referenced in source"
      error_header += " or test" if (test_build) 
      error_header += ": '#{$1}'."
      
      @streaminator.stderr_puts( error_header )

      if (@configurator.project_use_auxiliary_dependencies)
        help_message = "Possible stale dependency due to a file name change, etc. Maybe '#{context.to_s}:refresh' task and try again."      
        @streaminator.stderr_puts( help_message )
      end
      
      raise ''
    else
      raise exception
    end
  end
  
end
