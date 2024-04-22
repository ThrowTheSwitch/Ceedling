# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# :flags:
#   :test:
#     :compile:
#       :*:                       # Add '-foo' to compilation of all files for all test executables
#         - -foo
#       :Model:                   # Add '-Wall' to compilation of any test executable with Model in its filename
#         - -Wall
#     :link:
#       :tests/comm/TestUsart.c:  # Add '--bar --baz' to link step of TestUsart executable
#         - --bar
#         - --baz
#   :release:
#     - -std=c99

# :flags:
#   :test:
#     :compile:                   # Equivalent to [test][compile]['*'] -- i.e. same extra flags for all test executables
#       - -foo
#       - -Wall
#     :link:                      # Equivalent to [test][link]['*'] -- i.e. same flags for all test executables
#       - --bar
#       - --baz

class Flaginator

  constructor :configurator, :streaminator, :config_matchinator, :system_wrapper

  def setup
    @section = :flags
  end

  def flags_defined?(context:, operation:nil)
    return @config_matchinator.config_include?(primary:@section, secondary:context, tertiary:operation)
  end

  def flag_down(context:, operation:, filepath:nil)
    flags = @config_matchinator.get_config(primary:@section, secondary:context, tertiary:operation)
    ret_flags = []

    if flags == nil
      ret_flags = []
    elsif flags.is_a?(Array)
      flags_parsed = flags.flatten # Flatten to handle list-nested YAML aliases
      flags_parsed.each do |element|
        element = element.replace( @system_wrapper.module_eval( element ) ) if (element =~ RUBY_STRING_REPLACEMENT_PATTERN)
      end
      ret_flags = flags_parsed
    elsif flags.is_a?(Hash)
      @config_matchinator.validate_matchers(hash:flags, section:@section, context:context, operation:operation)

      arg_hash = {
        hash: flags,
        filepath: filepath,
        section: @section,
        context: context,
        operation: operation
      }

      flags_parsed = @config_matchinator.matches?(**arg_hash)
      flags_parsed.each do |key, value|
        key = key.replace( @system_wrapper.module_eval( key ) ) if (key =~ RUBY_STRING_REPLACEMENT_PATTERN)
        if value.is_a?(Array)
          value.each do |v|
            v = v.replace( @system_wrapper.module_eval( v ) ) if (v =~ RUBY_STRING_REPLACEMENT_PATTERN)
          end
        elsif value.is_a?(Hash)
          value.each do |k,v|
            k = k.replace( @system_wrapper.module_eval( k ) ) if (k =~ RUBY_STRING_REPLACEMENT_PATTERN)
            v = v.replace( @system_wrapper.module_eval( v ) ) if (v =~ RUBY_STRING_REPLACEMENT_PATTERN)
          end
        else
          value = value.replace( @system_wrapper.module_eval( value ) ) if (value =~ RUBY_STRING_REPLACEMENT_PATTERN)
        end
      end

      ret_flags = flags_parsed
    end

    # Handle unexpected config element type
    return ret_flags
  end

end
