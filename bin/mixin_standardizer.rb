# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

class MixinStandardizer

  constructor :reportinator

  def setup
    # ...
  end

  def smart_standardize(config:, mixin:, notices:)
    modified = false
    modified |= smart_standardize_defines(config, mixin, notices)
    modified |= smart_standardize_flags(config, mixin, notices)
    return modified
  end

  ### Private

  private

  def smart_standardize_defines(config, mixin, notices)
    modified = false
    
    # Bail out if config and mixin do noth both have :defines
    return false unless config[:defines] && mixin[:defines]
    
    # Iterate over :defines ↳ <context> keys
    # If both config and mixin contain the same key paths, process their (matcher) values
    config[:defines].each do |context, context_hash|
      if mixin[:defines][context]

        # Standardize :defines ↳ <context> matcher conventions if they differ so they can be merged later
        standardized, notice = standardize_matchers(
          config[:defines][context],
          mixin[:defines][context],
          config[:defines],
          mixin[:defines],
          context
        )

        if standardized
          path, _ = @reportinator.generate_config_walk( [:defines, context] )
          _notice = "At #{path}: #{notice}"
          notices.push( _notice )
        end

        modified |= standardized
      end
    end
    
    return modified
  end

  def smart_standardize_flags(config, mixin, notices)
    modified = false
    
    # Bail out if config and mixin do noth both have :flags
    return false unless config[:flags] && mixin[:flags]
    
    # Iterate over :flags ↳ <context> ↳ <operation> keys
    # If both config and mixin contain the same key paths, process their (matcher) values
    config[:flags].each do |context, context_hash|
      next unless mixin[:flags][context]
      
      context_hash.each do |operation, operation_hash|
        if mixin[:flags][context][operation]

          # Standardize :flags ↳ <context> ↳ <operation> matcher conventions if they differ so they can be merged later
          standardized, notice = standardize_matchers(
            config[:flags][context][operation],
            mixin[:flags][context][operation],
            config[:flags][context],
            mixin[:flags][context],
            operation
          )

          if standardized
            path, _ = @reportinator.generate_config_walk( [:flags, context, operation] )
            _notice = "At #{path}: #{notice}"
            notices.push( _notice )
          end

          modified |= standardized
        end
      end
    end
    
    return modified
  end

  def standardize_matchers(config_value, mixin_value, config_parent, mixin_parent, key)
    # If both values are the same type, do nothing
    return false, nil if (config_value.class == mixin_value.class)

    # Promote mixin value list to all-matches matcher hash
    if config_value.is_a?(Hash) && mixin_value.is_a?(Array)
      mixin_parent[key] = {:* => mixin_value}
      return true, 'Converted mixin list to matcher hash to facilitate merging with configuration'
    end

    # Promote config value list to all-matches matcher hash
    if config_value.is_a?(Array) && mixin_value.is_a?(Hash)
      config_parent[key] = {:* => config_value}
      return true, 'Converted configuration list to matcher hash to facilitate merging with mixin'
    end
    
    return false, nil
  end
end