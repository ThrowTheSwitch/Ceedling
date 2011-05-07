
class BuildInvokerHelper

  constructor :configurator, :streaminator
  
  def process_exception(exception)
    if (exception.message =~ /Don't know how to build task '(.+)'/i)
      @streaminator.stderr_puts("ERROR: Rake could not find file referenced in source or test: '#{$1}'.")
      @streaminator.stderr_puts("Possible stale dependency due to a file name change, etc. Maybe 'clean' task and try again.") if (@configurator.project_use_auxiliary_dependencies)
      raise ''
    else
      raise exception
    end
  end
  
end
