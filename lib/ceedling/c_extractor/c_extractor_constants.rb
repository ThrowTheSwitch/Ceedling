# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

module CExtractorConstants
  # 16 KB -- enough for most functions
  DEFAULT_CHUNK_SIZE = (16 * 1024) unless const_defined?(:DEFAULT_CHUNK_SIZE, false)

  # 5 MB mega-length safety limit
  DEFAULT_MAX_FUNCTION_LENGTH = (5 * 1024 * 1024) unless const_defined?(:DEFAULT_MAX_FUNCTION_LENGTH, false)

  # C function decorators that indicate private (file-local) visibility
  PRIVATE_KEYWORDS = ['static', 'inline', '__inline', '__inline__', '__forceinline'].freeze unless const_defined?(:PRIVATE_KEYWORDS, false)

  # MSVC calling-convention keywords (appear between return type and function name)
  MSVC_CALLING_CONVENTIONS = ['__cdecl', '__stdcall', '__fastcall', '__thiscall', '__vectorcall'].freeze unless const_defined?(:MSVC_CALLING_CONVENTIONS, false)

  # C11/C23 bare specifier keywords (no argument list)
  C11_SPECIFIER_KEYWORDS = ['_Noreturn', '_Thread_local', '_Atomic', '_Bool', '_Complex', '_Imaginary'].freeze unless const_defined?(:C11_SPECIFIER_KEYWORDS, false)

  # Common type keywords that are part of return type, not decorators
  TYPE_KEYWORDS = ['unsigned', 'signed', 'long', 'short', 'struct', 'union', 'enum'].freeze unless const_defined?(:TYPE_KEYWORDS, false)

  # C type qualifiers
  TYPE_QUALIFIER_KEYWORDS = ['const', 'volatile', 'restrict'].freeze unless const_defined?(:TYPE_QUALIFIER_KEYWORDS, false)

  # C function modifier keywords
  MODIFIER_KEYWORDS = (['extern'] + TYPE_QUALIFIER_KEYWORDS).freeze unless const_defined?(:MODIFIER_KEYWORDS, false)

  # Keywords stripped when producing clean `declaration` / `signature_stripped` fields
  DECORATOR_KEYWORDS = (PRIVATE_KEYWORDS + TYPE_QUALIFIER_KEYWORDS + ['extern']).freeze unless const_defined?(:DECORATOR_KEYWORDS, false)
end
