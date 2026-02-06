# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/c_extractinator'

class PartializerHelper

  PRIVATE_KEYWORDS = ['static', 'inline', '__inline', '__inline__']

  # Common type keywords that are part of return type, not decorators
  TYPE_KEYWORDS = ['unsigned', 'signed', 'long', 'short', 'struct', 'union', 'enum']

  MODIFIER_KEYWORDS = ['extern', 'const', 'volatile', 'restrict']

  # Check if function decorators match the desired visibility
  def matches_visibility?(decorators, visibility)
    case visibility
    when :public
      return !is_function_private?(decorators)
    when :private
      return is_function_private?(decorators)
    else
      case visibility
      when Symbol
        visibility = " :#{visibility}"
      when NilClass, nil
        visibility = ': nil'
      when String
        visibility = ": \"#{visibility}\""
      else
        visibility = ": #{visibility}"
      end

      raise ArgumentError, "Invalid visibility#{visibility}"
    end
  end

  def extract_module_functions(header_filepath:, source_filepath:)
    header_funcs = []
    source_funcs = []

    if header_filepath
      header_funcs = CExtractinator.from_file(header_filepath).extract_functions()
    end

    if source_filepath
      source_funcs = CExtractinator.from_file(source_filepath).extract_functions()
    end    

    return header_funcs + source_funcs
  end

  # Extracts decorators from a C function signature and returns shortened signature
  # Returns: [decorators_array, shortened_signature_string]
  # Example: "static inline int foo(void)" with name "foo"
  #   => [["static", "inline"], "int foo(void)"]
  def parse_signature_decorators(signature, name)
    # Find the function name in the signature
    name_index = signature.index(name)
    return [[], signature] if name_index.nil?
    
    # Extract everything before the function name
    prefix = signature[0...name_index]
    
    # Extract everything from the function name onwards (preserves original formatting)
    remainder = signature[name_index..-1]
    
    # Split prefix by whitespace to get tokens (handles multiline)
    tokens = prefix.split(/\s+/).reject(&:empty?)
    
    # Return empty decorators if no tokens
    return [[], signature] if tokens.empty?
    
    # Find where decorators end and return type begins
    # Return type can be multiple tokens (e.g., "unsigned int", "long long", "struct foo")
    # or include pointer notation (e.g., "int*", "char *", "const char*")
        
    # Find the split point: decorators come before return type
    decorator_end_index = 0
    tokens.each_with_index do |token, idx|
      # If token is a type keyword or looks like a type (not a decorator keyword)
      if TYPE_KEYWORDS.include?(token) || 
        !PRIVATE_KEYWORDS.any? { |kw| token == kw.downcase } &&
        !MODIFIER_KEYWORDS.include?(token)
        # This is where return type starts
        decorator_end_index = idx
        break
      end
    end
    
    # If all tokens are decorators (shouldn't happen in valid C), treat last as return type
    decorator_end_index = tokens.length - 1 if decorator_end_index == 0 && tokens.length > 1
    
    # Split into decorators and return type tokens
    decorators = tokens[0...decorator_end_index]
    return_type_tokens = tokens[decorator_end_index..-1]
    
    # Return empty decorators if only one token (just return type)
    return [[], signature] if decorators.empty?
    
    # Reconstruct return type portion from original prefix to preserve formatting
    # Find where the first return type token appears in the prefix
    first_return_type_token = return_type_tokens.first
    return_type_start_index = prefix.index(first_return_type_token)
    
    # Everything from first return type token onwards is the return type portion
    return_type_portion = prefix[return_type_start_index..-1]
    
    # Build shortened signature: return_type_portion + remainder
    shortened_signature = "#{return_type_portion}#{remainder}"
    
    return decorators, shortened_signature
  end

  private

  # Does any decorator in a list matche any private keyword (case-insensitive)
  def is_function_private?(decorators)
    return decorators.any? do |decorator|
      PRIVATE_KEYWORDS.any? { |keyword| decorator.downcase == keyword.downcase }
    end
  end


end