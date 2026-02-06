# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/partials'
require 'ceedling/partializer_constants'
require 'ceedling/partializer_runtime'

class PartializerUtils
  include PartializerConstants

  # Check if function decorators match the desired visibility
  def matches_visibility?(decorators, visibility)
    case visibility
    when :public
      return !is_function_private?(decorators)
    when :private
      return is_function_private?(decorators)
    else
      PartializerRuntime.raise_on_option(visibility)
    end
  end

  # Transform function to appropriate output format `FunctionDefinition` or `FunctionDeclaration`
  def transform_function(func, signature, output_type)
    case output_type
    when :impl
      Partials.manufacture_function_definition(
        signature: signature,
        # TODO: Handle preserving whitespace between signature and body
        code_block: signature + "\n" + func.body
      )
    when :interface
      Partials.manufacture_function_declaration(
        signature: signature
      )
    else
      PartializerRuntime.raise_on_option(output_type)
    end
  end

  private

  # Does any decorator in a list matche any private keyword (case-insensitive)
  def is_function_private?(decorators)
    return decorators.any? do |decorator|
      PRIVATE_KEYWORDS.any? { |keyword| decorator.downcase == keyword.downcase }
    end
  end

end