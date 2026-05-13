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

  # C function decorators that indicate private (file-local) visibility
  PRIVATE_KEYWORDS = ['static', 'inline', '__inline', '__inline__', '__forceinline'].freeze

  # MSVC calling-convention keywords (appear between return type and function name)
  MSVC_CALLING_CONVENTIONS = ['__cdecl', '__stdcall', '__fastcall', '__thiscall', '__vectorcall'].freeze

  # C11/C23 bare specifier keywords (no argument list)
  C11_SPECIFIER_KEYWORDS = ['_Noreturn', '_Thread_local', '_Atomic', '_Bool', '_Complex', '_Imaginary'].freeze

  # Common type keywords that are part of return type, not decorators
  TYPE_KEYWORDS = ['unsigned', 'signed', 'long', 'short', 'struct', 'union', 'enum'].freeze

  # C type qualifiers
  TYPE_QUALIFIER_KEYWORDS = ['const', 'volatile', 'restrict'].freeze

  # C function modifier keywords
  MODIFIER_KEYWORDS = (['extern'] + TYPE_QUALIFIER_KEYWORDS).freeze

  # Keywords stripped when producing clean `declaration` / `signature_stripped` fields
  DECORATOR_KEYWORDS = (PRIVATE_KEYWORDS + TYPE_QUALIFIER_KEYWORDS + ['extern']).freeze
end