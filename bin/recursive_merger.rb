# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

##
## RecursiveMerger
## ===============
##
## Merges a mixin hash into a base configuration hash, key by key, recursing
## into nested hashes. The goal is for higher-priority mixin content to "win"
## in a predictable way:
##
##   Single values (strings, numbers, symbols, booleans):
##     The mixin value replaces the config value. Because mixins are merged in
##     priority order — lowest first, highest last — the last mixin's single
##     value is the one that sticks.
##
##   Lists (arrays):
##     GENERAL RULE — the mixin's entries are placed BEFORE the config's
##     entries in the combined list. This means higher-priority mixin entries
##     appear earlier in the merged list. For example, when a command line
##     mixin adds include search paths and a config file mixin also adds
##     search paths, the command line paths come first and are searched first.
##
##     EXCEPTION — tool argument lists under the key path
##     [:tools, <tool name>, :arguments] are APPENDED (mixin entries added
##     at the END of the list). Compilers and linkers process arguments
##     left-to-right, so a later occurrence of a flag like -O0 overrides an
##     earlier -O2. Appending ensures that a higher-priority mixin's tool
##     arguments still take effect.
##
##   Single value merged into a config list:
##     The mixin's single value is wrapped in a one-element list and then
##     placed BEFORE the config list entries, consistent with the general
##     list rule above.
##
##   List merged into a config single value:
##     The mixin's list replaces the config value outright. This is flagged
##     as a type mismatch by validate_merge() before this method runs.
##
##   Hash merged into a config non-hash:
##     The mixin's hash replaces the config value. Exception: if the config
##     value is itself a list, the mixin hash is treated as a single value
##     and prepended (consistent with single-value-into-list behavior).
##
##   Hash merged with a config hash:
##     Recurse into both hashes at the matching key so each nested key is
##     handled individually by the same rules.
##
## Usage
## -----
##   RecursiveMerger.merge!(config_hash, mixin_hash)
##
## The merge is destructive: config_hash is modified in place.
##

class RecursiveMerger

  # Merge mixin into config in place. path is used internally to track the
  # current key path for the tool-arguments exception check.
  def self.merge!(config, mixin, path = [])
    mixin.each do |key, mixin_val|
      config_val   = config[key]
      current_path = path + [key]

      if mixin_val.is_a?(Hash) && config_val.is_a?(Hash)
        # Both sides have a hash at this key — recurse so each nested key is
        # handled individually rather than replacing the entire sub-hash.
        merge!(config_val, mixin_val, current_path)

      elsif config_val.is_a?(Array)
        # Config already has a list at this key. Regardless of whether the
        # mixin value is a list, a hash, or a single value, we keep the list
        # and merge the mixin value into it.
        if mixin_val.is_a?(Array)
          # Both sides are lists.
          if tool_arguments_path?(current_path)
            # EXCEPTION: tool argument lists are extended at the end so that
            # a later (higher-priority) flag overrides an earlier one when
            # the compiler or linker processes arguments left-to-right.
            config[key] = config_val + mixin_val
          else
            # GENERAL: prepend mixin entries so higher-priority content
            # appears first in the combined list (e.g. include search paths).
            config[key] = mixin_val + config_val
          end
        else
          # Mixin has a single value (or hash treated as a value) where config
          # has a list. Wrap the mixin value in a one-element list and prepend
          # it so the mixin value appears first.
          config[key] = [mixin_val] + config_val
        end

      elsif mixin_val.is_a?(Array)
        # Mixin has a list where config has a single value (or nothing).
        # Replace the config value with the mixin list.
        # Note: validate_merge() flags this as an incompatible type change
        # when the config key already exists with a non-array value.
        config[key] = mixin_val

      elsif mixin_val.is_a?(Hash)
        # Mixin has a hash where config has a non-hash, non-array value (or
        # the key is absent in config). Replace outright.
        config[key] = mixin_val

      else
        # Both sides have single values — mixin replaces config.
        # Because mixins are merged in lowest-to-highest-priority order,
        # the last mixin to write a key wins.
        config[key] = mixin_val
      end
    end
  end

  ### Private

  private_class_method def self.tool_arguments_path?(path)
    # Match exactly [:tools, <any tool name>, :arguments].
    # The first element is :tools, the third is :arguments, and the middle
    # element is the tool name (any symbol). Path length must be exactly 3
    # so deeper nesting (e.g. inside :arguments) is not accidentally matched.
    path.length == 3 && path[0] == :tools && path[2] == :arguments
  end

end
