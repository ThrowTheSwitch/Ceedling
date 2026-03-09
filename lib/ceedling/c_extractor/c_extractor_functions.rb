# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

class CExtractorFunctions

  # Data class representing an extracted C function
  CFunctionDefinition = Struct.new(
    :name,            # Function name only (e.g., "foo")
    :signature,       # Function signature (e.g., "int foo(void)")
    :body,            # Function body including containing braces
    :code_block,      # Complete function text (signature + body)
    :line_count,      # Total number of lines in code_block
    keyword_init: true
  ) do
    # Constructor to set unassigned fields to nil for convenience
    def initialize(name: nil, signature: nil, body: nil, code_block: nil, line_count: 0)
      super
    end
  end

  def initialize(code_text, max_line_length)
    # Dependency injection
    @code_text = code_text
    @max_line_length = max_line_length
  end

  def try_extract_function_declaration(scanner)
    start_pos = scanner.pos

    # Look for function signature
    signature = extract_function_signature(scanner, :declaration)        
    return [true, signature] if signature

    return [false, nil]
  end

  # Try to extract a complete function from the scanner
  # Returns [success, function_data] where:
  #  - success: boolean indicating if extraction was successful
  #  - function_data: CFunctionDefinition with as much info as available (may be partial on failure)
  def try_extract_function_definition(scanner)
    start_pos = scanner.pos

    # Look for function signature
    signature = extract_function_signature(scanner, :definition)
    return [false, CFunctionDefinition.new] unless signature
    
    @code_text.skip_deadspace(scanner)

    unless scanner.peek(1) == '{'
      return [false, CFunctionDefinition.new(
        name: extract_function_name(signature),
        signature: signature
      )]
    end
    
    # Extract function body
    success, braced_body = @code_text.extract_balanced_braces(scanner)
    unless success
      return [false, CFunctionDefinition.new(
        name: extract_function_name(signature),
        signature: signature,
        code_block: scanner.string[start_pos...scanner.pos]
      )]
    end
    
    # Extract full function definition
    code_block = scanner.string[start_pos...scanner.pos]
    
    # Fill out function data class
    func = CFunctionDefinition.new(
      name: extract_function_name(signature),
      signature: signature,
      body: braced_body,
      code_block: code_block,
      line_count: code_block.count("\n") + 1
    )
    
    return [true, func]
  end

  private

  # Extract a function signature from the scanner
  #
  # This method attempts to extract either a function declaration or definition signature
  # from the current scanner position. It distinguishes between functions and variables by
  # analyzing the structure of the extracted code.
  #
  # @param scanner [StringScanner] The scanner positioned at potential function start
  # @param type [Symbol] Either :declaration or :definition
  #   - :declaration expects pattern: type name(...);
  #   - :definition expects pattern: type name(...) { ... }
  #
  # @return The extracted and cleaned signature string, or nil if:
  #   - No valid signature found
  #   - Unbalanced parentheses detected
  #   - Variable declaration detected (not a function)
  #   - Type mismatch (e.g., semicolon found when expecting definition)
  #
  # Variable declarations are rejected based on these patterns:
  #   - Simple variables: int x;
  #   - Arrays: int arr[10];
  #   - Function pointers: int (*ptr)(int);
  #   - Initialized variables: int x = 42;
  #
  # The method handles:
  #   - String literals (both single and double quoted)
  #   - C-style comments (// and /* */)
  #   - Nested parentheses in function parameters
  #   - Whitespace and newlines
  #
  # On failure, the scanner position is reset to the starting position.
  # On success, the scanner is positioned after the signature:
  #  - After ';' for declarations
  #  - Before '{' for definitions)
  #
  # Safety:
  #   Enforces max_line_length limit to prevent infinite loops on malformed input
  def extract_function_signature(scanner, type)
    start_pos = scanner.pos
    paren_depth = 0
    in_string = false
    string_char = nil
    signature_candidates = []  # Track positions where paren_depth returns to 0
    found_opening_paren = false  # Track if we've seen an opening paren
    
    until scanner.eos?
      char = scanner.peek(1)

      # Safety check
      if (scanner.pos - start_pos) > @max_line_length
        scanner.pos = start_pos
        return nil
      end

      # Handle string literals
      if in_string
        if char == '\\'
          scanner.getch
          scanner.getch unless scanner.eos?
          next
        elsif char == string_char
          scanner.getch
          in_string = false
          string_char = nil
          next
        else
          scanner.getch
          next
        end
      end
      
      case char
      when '"', "'"
        in_string = true
        string_char = char
        scanner.getch
      when '/'
        if scanner.peek(2) =~ %r{^(/[/*])}
          @code_text.skip_comment(scanner)
        else
          scanner.getch
        end
      when '('
        paren_depth += 1
        found_opening_paren = true
        scanner.getch
      when ')'
        paren_depth -= 1
        scanner.getch
        
        # When we return to depth 0, this could be the end of the function's parameter list
        if paren_depth == 0
          signature_candidates << scanner.pos
        elsif paren_depth < 0
          # Unbalanced parentheses - not a valid function signature
          scanner.pos = start_pos
          return nil
        end
      when '{'
        # Found opening brace
        if type == :declaration
          scanner.pos = start_pos
          return nil
        else # :definition
          # Check if any of our candidates is valid
          if signature_candidates.empty?
            # No balanced parens found before brace - not a function
            scanner.pos = start_pos
            return nil
          end

          # The last candidate (outermost closing paren) should be the function parameter list
          signature_end_pos = signature_candidates.last
          
          # Extract and clean the signature
          signature = scanner.string[start_pos...signature_end_pos]
          return clean_signature(signature)
        end
      when ';'
        # Found semicolon - this is a declaration, not a definition

        if type == :declaration
          # Before accepting this as a function declaration, verify it has parentheses
          # and doesn't look like a variable declaration
          unless found_opening_paren
            # No parentheses found - this is a variable declaration
            scanner.pos = start_pos
            return nil
          end
          
          scanner.getch
          signature = scanner.string[start_pos...scanner.pos]

          # Validate this looks like a function declaration, not a variable
          # Function declarations should have: type name(...) ;
          # NOT: type (*name)(...) ; (function pointer variable)
          # NOT: type name[...] ; (array variable)
          # NOT: type name = ... ; (variable with initializer)
          cleaned = clean_declaration(signature)
          
          # Check if this looks like a function declaration
          # Pattern: ends with identifier followed by (...) and semicolon
          # NOT: contains (*identifier) pattern (function pointer variable)
          if cleaned =~ /\(\s*\*\s*[a-zA-Z_][a-zA-Z0-9_]*\s*\)/
            # This is a function pointer variable, not a function declaration
            scanner.pos = start_pos
            return nil
          end
          
          # Additional check: ensure the pattern is identifier(...); not identifier[...]; or identifier;
          # Extract the part before the semicolon and check if it ends with )
          content_before_semicolon = cleaned.gsub(/\s*;$/, '')
          unless content_before_semicolon.end_with?(')')
            # Doesn't end with closing paren - likely a variable declaration
            scanner.pos = start_pos
            return nil
          end
          
          return cleaned
        else # :definition
          scanner.pos = start_pos
          return nil
        end
      when '['
        # Found opening bracket - this could be an array declaration
        # If we haven't found any opening parenthesis yet, this is likely a variable
        unless found_opening_paren
          scanner.pos = start_pos
          return nil
        end
        scanner.getch
      when '='
        # Found assignment operator - this is a variable with initializer
        # Only reject if we're at depth 0 (not inside function parameters)
        if paren_depth == 0
          scanner.pos = start_pos
          return nil
        end
        scanner.getch
      else
        scanner.getch
      end      
    end
    
    # Reached end without finding complete signature
    scanner.pos = start_pos
    return nil
  end

  def clean_signature(signature)
    # Remove C-style line comments (in multiline signatures)
    _signature = signature.gsub(/\/\/.*$/, '')
    # Remove newlines and tabs
    _signature.gsub!(/\r\n|\r|\n|\t/, ' ')
    # Remove C-style block comments
    _signature.gsub!(/\/\*.*?\*\//m, '')
    # Collapse consecutive whitespace
    _signature.gsub!(/\s+/, ' ')
    # Tidy up leadinga and trailing whitespace
    _signature.strip!()
    return _signature
  end

  def clean_declaration(declaration)
    _declaration = clean_signature(declaration)
    # Removes any whitespace before final semicolon
    _declaration.gsub!(/\s*;$/, ';')
    return _declaration
  end

  def extract_function_name(signature)
    # Verify balanced parentheses first
    paren_depth = 0
    signature.each_char do |char|
      case char
      when '('
        paren_depth += 1
      when ')'
        paren_depth -= 1
        return nil if paren_depth < 0  # Unbalanced - closing before opening
      end
    end
    
    # If parentheses aren't balanced, return nil
    return nil unless paren_depth == 0
    
    # Strategy: Find the main parameter list by looking for the pattern:
    # identifier followed by '(' that represents the function's parameter list
    
    # First, handle function pointer return types: int (*name(params))(params)
    # Pattern: (*identifier(...))
    if signature =~ /\(\s*\*\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*\(/
      return $1
    end
    
    # Handle attributes and other constructs with double parentheses
    # Pattern: __attribute__((...)). We need to skip these and find the actual function name
    # Remove all __attribute__((...)) and similar patterns
    cleaned = signature.dup
    
    # Remove __attribute__((...)) patterns and similar decorators
    loop do
      before = cleaned.dup
      # Match __word__((...)) patterns (like __attribute__((interrupt)))
      cleaned.gsub!(/\b__\w+__\s*\(\([^)]*\)\)/, '')
      # Match __word__(...) patterns (like __declspec(dllexport))
      cleaned.gsub!(/\b__\w+__\s*\([^)]*\)/, '')
      # Match __declspec(...) patterns
      cleaned.gsub!(/\b__declspec\s*\([^)]*\)/, '')
      # Match specific C11/C23 specifiers (not general _word pattern)
      cleaned.gsub!(/\b_Noreturn\b/, '')
      cleaned.gsub!(/\b_Thread_local\b/, '')
      cleaned.gsub!(/\b_Atomic\b/, '')
      cleaned.gsub!(/\b_Bool\b/, '')
      cleaned.gsub!(/\b_Complex\b/, '')
      cleaned.gsub!(/\b_Imaginary\b/, '')
      break if cleaned == before  # No more changes
    end
    
    # Now find the function name in the cleaned signature
    # Look for: identifier followed by '('
    # The identifier should be preceded by whitespace or * (for pointer returns)
    if cleaned =~ /(?:^|[\s*])([a-zA-Z_][a-zA-Z0-9_]*)\s*\(/
      return $1
    end
    
    # Fallback: no valid function name found
    nil
  end
  
end