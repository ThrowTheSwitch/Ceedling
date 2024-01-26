require 'ceedling/constants'

class Verbosinator

  # constructor :configurator

  def should_output?(level)
    # return (level <= @configurator.project_verbosity)
    return (level <= Verbosity::OBNOXIOUS)
  end

end
