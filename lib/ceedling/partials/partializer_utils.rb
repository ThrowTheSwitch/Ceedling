# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/partials/partials'
require 'ceedling/partials/partializer_constants'
require 'ceedling/partials/partializer_runtime'

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
        name: func.name,
        signature: signature,
        source_filepath: func.source_filepath,
        line_num: func.line_num,
        # Extract code block as beginning with the signature to end of original code block.
        # This omits any decorators before signature in original code_block and preserves 
        # original whitespace (i.e. indentation & newlines including connecting signature to body).
        code_block: extract_code_block(func.code_block, signature)
      )
    when :interface
      Partials.manufacture_function_declaration(
        name: func.name,
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

  # Extract code block starting from signature to end of original, omitting any decorators before signature.
  # Preserves original function indentation and newlines.
  def extract_code_block(code_block, signature)
    start_index = code_block.index(signature)
    
    # Handle case where signature is not found in code_block
    if start_index.nil?
      raise ArgumentError, "Signature '#{signature}' not found in code block"
    end
    
    # Return code block minus any decorators before signature
    return code_block[start_index..-1]
  end

end