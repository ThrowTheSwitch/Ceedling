
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

  constructor :configurator, :streaminator, :config_matchinator

  def setup
    @section = :flags
  end

  def flags_defined?(context:, operation:nil)
    return @config_matchinator.config_include?(primary:@section, secondary:context, tertiary:operation)
  end

  def flag_down(context:, operation:, filepath:nil)
    flags = @config_matchinator.get_config(primary:@section, secondary:context, tertiary:operation)

    if flags == nil then return []
    elsif flags.is_a?(Array) then return flags.flatten # Flatten to handle list-nested YAML aliases
    elsif flags.is_a?(Hash)
      @config_matchinator.validate_matchers(hash:flags, section:@section, context:context, operation:operation)

      arg_hash = {
        hash: flags,
        filepath: filepath,
        section: @section,
        context: context,
        operation: operation
      }

      return @config_matchinator.matches?(**arg_hash)
    end

    # Handle unexpected config element type
    return []
  end

end
