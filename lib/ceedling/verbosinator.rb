require 'ceedling/constants'

class Verbosinator

  def should_output?(level)
    # Rely on global constant created at early stages of command line processing
    return (level <= PROJECT_VERBOSITY)
  end

end
