# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

module CExtractorConstants
  # 1000 character safety limit
  DEFAULT_MAX_LINE_LENGTH = 1000

  # 16 KB -- enough for most functions
  DEFAULT_CHUNK_SIZE = (16 * 1024)
  
  # 5 MB mega-length safety limit
  DEFAULT_MAX_FUNCTION_LENGTH = (5 * 1024 * 1024)
end