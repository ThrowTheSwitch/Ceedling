# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Patch the string class so that we have a nice shortcut for cleaning string encodings
class String
  def clean_encoding(safe_char = '')
    begin
      # Clean up any oddball characters in an otherwise ASCII document
      encoding_options = {
        :invalid           => :replace,  # Replace invalid byte sequences
        :undef             => :replace,  # Replace anything not defined in ASCII
        :replace           => safe_char, # Use a safe character for those replacements
        :universal_newline => true       # Always break lines with \n
      }
    
      return self.encode("ASCII", **encoding_options).encode('UTF-8', **encoding_options)
    rescue 
      raise "String contains characters that can't be represented in standard ASCII / UTF-8."
    end 
    self 
  end
end