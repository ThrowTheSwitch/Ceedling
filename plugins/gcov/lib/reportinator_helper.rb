require 'ceedling/constants'


class ReportinatorHelper

  def initialize(system_objects)
    @ceedling = system_objects
  end

  # Output the shell result to the console.
  def print_shell_result(shell_result)
    if !(shell_result.nil?)
      msg = "Done in %.3f seconds." % shell_result[:time]
      @ceedling[:streaminator].stdout_puts(msg, Verbosity::NORMAL)

      if !(shell_result[:output].nil?) && (shell_result[:output].length > 0)
        @ceedling[:streaminator].stdout_puts(shell_result[:output], Verbosity::OBNOXIOUS)
      end
    end
  end

end
