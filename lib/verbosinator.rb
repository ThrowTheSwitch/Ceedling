
class Verbosity
  ERRORS      = 0
  COMPLAIN    = 1
  NORMAL      = 2
  OBNOXIOUS   = 3
end


class Verbosinator

  constructor :configurator

  def should_output?(level)
    return (level <= @configurator.project_verbosity)
  end

end
