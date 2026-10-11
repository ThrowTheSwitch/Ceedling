# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'

# Generated include guards open with a hash of the header's name. Specs of the code that
# writes guards compare its output against expected text with each hash masked as <HASH>,
# so expectations state the readable stem and the guard's fixed head and tail.
# FileWrapper's own specs pin the hash itself.
module IncludeGuardHelper
  GUARD_HEAD = /\b#{GENERATED_INCLUDE_GUARD_PREFIX}[0-9A-F]{#{GENERATED_INCLUDE_GUARD_HASH_LENGTH}}_/

  def mask_include_guard_hashes(text)
    return text.gsub( GUARD_HEAD, "#{GENERATED_INCLUDE_GUARD_PREFIX}<HASH>_" )
  end
end
