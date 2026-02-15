
# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

module PartializerConstants
  # C function decorators that indicate private (file-local) visibility
  PRIVATE_KEYWORDS = ['static', 'inline', '__inline', '__inline__'].freeze
  
  # Common type keywords that are part of return type, not decorators
  TYPE_KEYWORDS = ['unsigned', 'signed', 'long', 'short', 'struct', 'union', 'enum'].freeze
  
  # C type qualifiers
  TYPE_QUALIFIER_KEYWORDS = ['const', 'volatile', 'restrict'].freeze

  # C function modifier keywords
  MODIFIER_KEYWORDS = (['extern'] + TYPE_QUALIFIER_KEYWORDS).freeze
end
