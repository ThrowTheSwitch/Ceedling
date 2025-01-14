# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'deep_merge'

class Merginator

  constructor :reportinator

  def setup
    # ...
  end


  def merge(config:, mixin:, warnings:)
    # Find any incompatible merge values in config and mixin
    validate = validate_merge( config:config, mixin:mixin, mismatches:warnings )

    # Merge this bad boy
    config.deep_merge(
      mixin,
      # In cases of a primitive and a hash of primitives, add single item to array
      # Handle merge cases where valid config entries can be a single string or array of strings
      :extend_existing_arrays => true
    )

    return validate
  end

  ### Private

  private

  # Recursive inspection of mergeable base config & mixin
  def validate_merge(config:, mixin:, key_path:[], mismatches:)
    # Track whether all matching hash key paths have matching value types
    valid = true
    
    # Get all keys from both hashes
    all_keys = (config.keys + mixin.keys).uniq
    
    all_keys.each do |key|
      current_path = key_path + [key]
      
      # Skip if key doesn't exist in both hashes
      next unless config.key?(key) && mixin.key?(key)
      
      config_value = config[key]
      mixin_value = mixin[key]
      
      if config_value.is_a?(Hash) && mixin_value.is_a?(Hash)
        # Recursively check nested hashes
        sub_result = validate_merge(
          config: config_value,
          mixin: mixin_value,
          key_path: current_path,
          mismatches: mismatches
        )

        valid = false unless sub_result
      else
        # Compare types of non-hash values
        unless config_value.class == mixin_value.class
          # If mergeable values at key paths in common are not the same type, register this
          valid = false
          key_path_str = @reportinator.generate_config_walk( current_path )
          warning = "Incompatible merge at key path #{key_path_str} ==> Project configuration has #{config_value.class} while Mixin has #{mixin_value.class}"
 
          # Do not use `<<` as it is locally scoped
          mismatches.push( warning )
        end
      end
    end
        
    return valid
  end

end