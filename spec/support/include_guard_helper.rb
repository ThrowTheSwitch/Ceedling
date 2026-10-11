# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Generated include guards open with a hash of the header's name. Specs of the code that
# writes guards compare its output against expected text with each hash masked as <HASH>,
# so expectations state the readable stem and the guard's fixed head and tail.
# FileWrapper's own specs pin the hash itself.
module IncludeGuardHelper
  def mask_include_guard_hashes(text)
    return text.gsub( /\bGEN[0-9A-F]{8}_/, 'GEN<HASH>_' )
  end
end
