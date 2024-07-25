# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

class ConfigWalkinator
  
  def fetch_value(*keys, hash:, default:nil)
    # Safe initial values
    value = default
    depth = 0

    # Set walk variable
    walk = hash

    # Walk into hash & extract value at requested key sequence
    keys.each { |symbol|
      # Validate that we can fetch something meaningful
      if !walk.is_a?( Hash) or !symbol.is_a?( Symbol ) or walk[symbol].nil?
        value = default
        break
      end

      # Walk into the hash one more level and update value
      depth += 1
      walk  = walk[symbol]
      value = walk
    } if !walk.nil?
    
    return value, depth
  end
  
end
