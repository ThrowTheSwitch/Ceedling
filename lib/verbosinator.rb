
class Verbosity
  ERRORS      = 0  # only errors
  COMPLAIN    = 1  # spit out errors and warnings/notices
  NORMAL      = 2  # errors, warnings/notices, standard status messages
  OBNOXIOUS   = 3  # all messages including extra verbose output (likely used for debugging)
end


class Verbosinator

  constructor :configurator

  def should_output?(level)
    return (level <= @configurator.project_verbosity)
  end

end
