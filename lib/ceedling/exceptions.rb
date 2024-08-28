# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'


class CeedlingException < RuntimeError
  # Nothing at the moment
end


class ShellExecutionException < CeedlingException

  attr_reader :shell_result

  def initialize(shell_result:{}, name:, message:'')
    @shell_result = shell_result
    
    # If shell results exist...
    if !shell_result.empty?
      message = "Tool #{name} terminated with exit code [#{shell_result[:exit_code]}]"

      if !shell_result[:output].empty?
        message += " and output >> \"#{shell_result[:output].strip()}\""
      end

      super( message )

    # Otherwise, just report the provided message
    else
      message = "Tool #{name} encountered an error:: #{message}"
      super( message )
    end

  end
end
