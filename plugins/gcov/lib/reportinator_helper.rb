# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'


class ReportinatorHelper

  def initialize(system_objects)
    # Convenience alias
    @loginator = system_objects[:loginator]
  end

  # Output the shell result to the console.
  def print_shell_result(shell_result)
    if !(shell_result.nil?)
      msg = "Done in %.3f seconds." % shell_result[:time]
      @loginator.log(msg, Verbosity::NORMAL)

      if !(shell_result[:output].nil?) && (shell_result[:output].length > 0)
        @loginator.log(shell_result[:output], Verbosity::OBNOXIOUS)
      end
    end
  end

end
