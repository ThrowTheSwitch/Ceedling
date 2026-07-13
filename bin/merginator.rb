# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require_relative 'recursive_merger'

class Merginator

  constructor :reportinator

  def setup
    # ...
  end


  def merge(config:, mixin:, warnings:)
    # Find any incompatible merge values in config and mixin
    validate = validate_merge( config:config, mixin:mixin, mismatches:warnings )

    # Merge mixin into config using custom recursive logic that preserves
    # priority order for both single values and lists. See RecursiveMerger
    # for the full set of merge rules.
    RecursiveMerger.merge!( config, mixin )

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

      # When the config value is already a list, merging any mixin value into it is allowed —
      # RecursiveMerger handles all list combinations without type errors.
      elsif !config_value.is_a?(Array)
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