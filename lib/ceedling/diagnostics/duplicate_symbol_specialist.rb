# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/diagnostics/build_step_doctor'

# Explains linker errors for symbols more than one linked object defines.
class DuplicateSymbolSpecialist

  def diagnoses()
    return []
  end
end
