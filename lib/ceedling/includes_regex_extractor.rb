
# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/includes'
require 'set'

class IncludesRegexExtractor

  def self.extract_user_include(line)
    # Look for user #include statements
    results = line.match(PATTERNS::USER_INCLUDE_DIRECTIVE_FILENAME)
    if !results.nil?
      return UserInclude.new(results[1])
    end

    return nil
  end

  def self.extract_system_include(line)
    # Look for system #include statements
    results = line.match(PATTERNS::SYSTEM_INCLUDE_DIRECTIVE_FILENAME)
    if !results.nil?
      return SystemInclude.new(results[1])
    end

    return nil
  end
end
