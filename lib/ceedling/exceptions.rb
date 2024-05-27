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
  def initialize(shell_result:, message:)
    @shell_result = shell_result
    super(message)
  end
end
