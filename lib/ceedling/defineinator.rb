# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# :defines:
#   :test:
#     :*:                                # Define TEST during compilation of all files for all test executables
#       - TEST
#     :Model:                            # Define PLATFORM_B during compilation of any test executable with Model in its filename
#       - -PLATFORM_B
#   :unity:
#     - UNITY_INCLUDE_PRINT_FORMATTED    # Define Unity configuration symbols during all test compilation
#     - UNITY_FLOAT_PRECISION=0.001f     # ...
#   :release:
#     - COM=Serial                       # Define COM for compilation of all files during release build

# :defines:
#   :test:                               # Equivalent to [test]['*'] -- i.e. same defines for all test executables
#     - TEST
#     - PLATFORM_B

class Defineinator

  constructor :configurator, :loginator, :config_matchinator

  def setup
    @topkey = :defines
  end

  def defines_defined?(context:)
    return @config_matchinator.config_include?(primary:@topkey, secondary:context)
  end

  # Defaults to inspecting configurations beneath top-level :defines
  # (But, we can also lookup defines symbol lists within framework configurations--:unity, :cmock, :cexception)
  def defines(topkey:@topkey, subkey:, filepath:nil, default:[])
    defines = @config_matchinator.get_config(primary:topkey, secondary:subkey)

    if defines == nil then return default
    # Flatten to handle list-nested YAML aliasing (should have already been flattened during validation)
    elsif defines.is_a?(Array) then return defines.flatten
    elsif defines.is_a?(Hash)
      arg_hash = {
        hash: defines,
        filepath: filepath,
        section: topkey,
        context: subkey
      }

      return @config_matchinator.matches?(**arg_hash)
    end

    # Handle unexpected config element type
    return []
  end

  # Optionally create a command line compilation symbol that is a test file's sanitized/converted name
  def generate_test_definition(filepath:)
    defines = []

    if @configurator.defines_use_test_definition
      # Get filename with no path or extension
      test_def = File.basename(filepath, '.*').strip

      # Replace any non-ASCII characters with underscores
      test_def = test_def.encode("ASCII", "UTF-8", invalid: :replace, undef: :replace, replace: "_")

      # Replace all non-alphanumeric characters (including spaces/punctuation but excluding underscores) with underscores
      test_def.gsub!(/[^0-9a-z_]/i, '_')

      # Convert to all caps
      test_def.upcase!

      # Add leading and trailiing underscores unless they already exist
      test_def = test_def.start_with?('_') ? test_def : ('_' + test_def)
      test_def = test_def.end_with?('_') ? test_def : (test_def + '_')

      # Add the test filename as a #define symbol to the array
      defines << test_def
    end

    return defines
  end

end
