
class Verbosity
  SILENT      = 0
  ERRORS      = 1  # only errors
  COMPLAIN    = 2  # spit out errors and warnings/notices
  NORMAL      = 3  # errors, warnings/notices, standard status messages
  OBNOXIOUS   = 4  # all messages including extra verbose output (likely used for debugging)
end


class Verbosinator

  constructor :configurator

  def should_output?(level)
    return (level <= @configurator.project_verbosity)
  end

end
