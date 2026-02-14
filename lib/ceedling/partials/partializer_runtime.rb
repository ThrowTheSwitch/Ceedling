# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

module PartializerRuntime

  # Format a mistaken configuration parameter for error messages
  # @param option [Object] The mistaken value to format
  # @return [String] Formatted string representation
  def self.raise_on_option(option)
    str = ''

    case option
    when Symbol
      str = " :#{option}"
    when NilClass, nil
      str = ': nil'
    when String
      str = ": \"#{option}\""
    else
      str = ": #{option}"
    end

    raise ArgumentError, "Invalid internal option#{str}"
  end
end