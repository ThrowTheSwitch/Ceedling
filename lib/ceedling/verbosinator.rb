# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'

class Verbosinator

  def should_output?(level)
    # Rely on global constant created at early stages of command line processing
    return (!defined?(PROJECT_VERBOSITY)) || (level <= PROJECT_VERBOSITY)
  end

end
