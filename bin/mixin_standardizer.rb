# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

class MixinStandardizer

  constructor :reportinator

  def setup
    # ...
  end

  def smart_standardize(config:, mixin:, notices:)
    modified = false
    # :defines ↳ <context> is one category level deep; :flags ↳ <context> ↳
    # <operation> is two. Both bottom out at the same matcher-hash-or-array
    # value standardize_matchers() knows how to reconcile.
    modified |= smart_standardize_section(config, mixin, notices, :defines, depth: 1)
    modified |= smart_standardize_section(config, mixin, notices, :flags, depth: 2)
    return modified
  end

  ### Private

  private

  # Walks a config section (:defines or :flags) through `depth` levels of
  # matching category keys shared between config and mixin, then
  # standardizes matcher conventions at the leaf value.
  def smart_standardize_section(config, mixin, notices, section, depth:)
    return false unless config[section] && mixin[section]

    modified = false

    walk = lambda do |config_node, mixin_node, path, remaining_depth|
      config_node.each do |key, value|
        next unless mixin_node[key]

        current_path = path + [key]

        if remaining_depth > 1
          walk.call( value, mixin_node[key], current_path, remaining_depth - 1 )
          next
        end

        # Standardize matcher conventions at the leaf so they can be merged later
        standardized, notice = standardize_matchers(
          value, mixin_node[key], config_node, mixin_node, key
        )

        if standardized
          full_path, _ = @reportinator.generate_config_walk( [section] + current_path )
          notices.push( "At #{full_path}: #{notice}" )
        end

        modified |= standardized
      end
    end

    walk.call( config[section], mixin[section], [], depth )

    return modified
  end

  def standardize_matchers(config_value, mixin_value, config_parent, mixin_parent, key)
    # If both values are the same type, do nothing
    return false, nil if (config_value.class == mixin_value.class)

    # Promote mixin value list to all-matches matcher hash
    if config_value.is_a?(Hash) && mixin_value.is_a?(Array)
      # Ensure all-matches matcher key is a symbol and not a string
      if (deleted = config_value.delete( '*' ))
        config_value[:*] = deleted
      end

      # Replace the value of a simple array list with a matcher hash that stores the original list
      mixin_parent[key] = {:* => mixin_value}
      return true, 'Converted mixin list to matcher hash to facilitate merging with configuration'
    end

    # Promote config value list to all-matches matcher hash
    if config_value.is_a?(Array) && mixin_value.is_a?(Hash)
      # mixin_value's own keys need no symbol/string normalization here --
      # Mixinator#mixin already symbolizes every mixin key before this method
      # ever runs, so a string '*' key is not possible on this side.

      # Replace the value of a simple array list with a matcher hash that stores the original list
      config_parent[key] = {:* => config_value}
      return true, 'Converted configuration list to matcher hash to facilitate merging with mixin'
    end
    
    return false, nil
  end
end