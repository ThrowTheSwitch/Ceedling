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


class ShellException < CeedlingException

  attr_reader :shell_result

  def initialize(shell_result:{}, name:, message:'')
    @shell_result = shell_result

    _message = ''
    
    # Most shell exceptions will be from build compilation and linking.
    # The formatting of these messages should place the tool output on its own
    # lines without any other surrounding characters.
    # This formatting maximizes the ability of IDEs to parse, highlight, and make 
    # actionable the build errors that appear within their terminal windows.

    # If shell results exist, report the exit code...
    if !shell_result.empty?
      _message = "#{name} terminated with exit code [#{shell_result[:exit_code]}]"

      if !shell_result[:output].empty?
        _message += " and output >>\n#{shell_result[:output].strip()}"
      end

    # Otherwise, just report the exception message
    else
      _message = "#{name} encountered an error with output >>\n#{message}"
    end

    # Hand the message off to parent Exception
    super( _message )
  end
end
