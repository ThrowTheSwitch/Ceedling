# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Patch the string class so that we have a nice shortcut for cleaning string encodings
class String
  # Clean up any oddball characters in an otherwise ASCII document. Hoisted to a
  # frozen constant rather than rebuilt on every clean_encoding call -- a fresh
  # Hash literal every call was a measurable, needless allocation back when the
  # two highest-volume callers (ParsingParcels#code_lines_with_num,
  # PreprocessinatorReconstructor#_scan_expansion_for_file) each called this
  # per line; both now clean a whole buffer once instead, but the remaining
  # per-line fallback-path callers (e.g. CPreprocessorConditionals#process_directive)
  # still benefit. Only :replace varies by caller (default '' vs. e.g. '_' from
  # defineinator.rb), so the common, default-safe_char case reuses this
  # constant untouched; a non-default safe_char still allocates one small
  # merged Hash, same as before.
  DEFAULT_CLEAN_ENCODING_OPTIONS = {
    :invalid           => :replace,  # Replace invalid byte sequences
    :undef             => :replace,  # Replace anything not defined in ASCII
    :replace           => '',        # Use a safe character for those replacements
    :universal_newline => true       # Always break lines with \n
  }.freeze

  def clean_encoding(safe_char = '')
    begin
      encoding_options = safe_char.empty? ? DEFAULT_CLEAN_ENCODING_OPTIONS : DEFAULT_CLEAN_ENCODING_OPTIONS.merge(:replace => safe_char)

      return self.encode("ASCII", **encoding_options).encode('UTF-8', **encoding_options)
    rescue
      raise "String contains characters that can't be represented in standard ASCII / UTF-8."
    end
    self
  end
end