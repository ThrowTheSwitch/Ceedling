# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

class PartializerConfig

  MACRO_NAMES = [
    'TEST_PARTIAL_PUBLIC_MODULE',
    'TEST_PARTIAL_PRIVATE_MODULE',
    'MOCK_PARTIAL_PUBLIC_MODULE',
    'MOCK_PARTIAL_PRIVATE_MODULE',
    'TEST_PARTIAL_MODULE',
    'MOCK_PARTIAL_MODULE',
    'TEST_PARTIAL_CONFIG',
    'MOCK_PARTIAL_CONFIG',
  ].freeze

end
