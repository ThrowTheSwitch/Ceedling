# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/exceptions'

class CExtractorFunctions

  # Data class representing an extracted C function
  CFunction = Struct.new(
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

  # Try to extract a complete function from the scanner
  # Returns [success, function_data] where:
  #  - success: boolean indicating if extraction was successful
  #  - function_data: CFunction with as much info as available (may be partial on failure)
  def try_extract_function(scanner)
    start_pos = scanner.pos
    
    # Look for function signature
    signature = extract_function_signature(scanner)
    return [false, CFunction.new] unless signature
    
    @code_text.skip_deadspace(scanner)

    unless scanner.peek(1) == '{'
      return [false, CFunction.new(
        name: parse_function_name(signature),
        signature: signature
      )]
    end
    
    # Extract function body
    success, braced_body = @code_text.extract_balanced_braces(scanner)
    unless success
      return [false, CFunction.new(
        name: parse_function_name(signature),
        signature: signature,
        code_block: scanner.string[start_pos...scanner.pos]
      )]
    end
    
    # Extract full function definition
    code_block = scanner.string[start_pos...scanner.pos]
    
    # Fill out function data class
    func = CFunction.new(
      name: parse_function_name(signature),
      signature: signature,
      body: braced_body,
      code_block: code_block,
      line_count: code_block.count("\n") + 1
    )
    
    return [true, func]
  end

  private

  def parse_function_name(signature)
    # Find the opening parenthesis
    paren_pos = signature.index('(')
    return nil unless paren_pos
    
    # Extract everything before the parenthesis
    before_paren = signature[0...paren_pos]
    
    # Split by whitespace and special characters, get the last token
    # This handles cases like:
    #   "int foo" -> "foo"
    #   "static void* bar" -> "bar"
    #   "unsigned long long baz" -> "baz"
    #   "int (*func_ptr)" -> "func_ptr" (function pointer)
    tokens = before_paren.split(/[\s*]+/)
    
    # Get the last non-empty token
    name = tokens.reverse.find { |t| !t.empty? }
    
    # Handle function pointers: remove parentheses
    # e.g., "(*func_ptr)" -> "func_ptr"
    name&.gsub(/[()]/, '')
  end
  
  # Extract a function signature from the scanner
  # 
  # A valid function signature must:
  #   1. Contain balanced parentheses (for parameter list)
  #   2. Be followed by an opening brace '{' (function definition)
  #   3. NOT be followed by a semicolon (which indicates a declaration, not a definition)
  # 
  # This method handles complex signatures including:
  #   - Simple functions: "int foo(void)"
  #   - Function pointers in return type: "int (*getFunction(void))(int, int)"
  #   - Function pointers in parameters: "void process(int (*callback)(void))"
  #   - Nested parentheses: "int foo((int)(x), (int)(y))"
  # 
  # The key insight is that we need to find the OUTERMOST balanced parentheses that represent
  # the function's parameter list, not just any balanced parentheses.
  # 
  # Parameters:
  #   scanner: StringScanner positioned at the start of a potential function signature
  # 
  # Returns:
  #   - The signature string (cleaned and normalized) if this is a function definition
  #   - nil if this is not a function definition (declaration, struct, etc.)
  # 
  # Side effects:
  #   - On success (function definition): Advances scanner to the opening brace '{'
  #   - On failure (declaration): Advances scanner past the semicolon ';'
  #   - On failure (other): Resets scanner to starting position
  # 
  # Examples:
  #   "int foo(void) {"                          -> returns "int foo(void)", scanner at '{'
  #   "int foo(void);"                           -> returns nil, scanner after ';'
  #   "struct foo {"                             -> returns nil, scanner at start
  #   "int foo(int x,\n  int y) {"               -> returns "int foo(int x, int y)", scanner at '{'
  #   "int (*getFunction(void))(int, int) {"     -> returns "int (*getFunction(void))(int, int)", scanner at '{'
  #   "void process(int (*callback)(void)) {"    -> returns "void process(int (*callback)(void))", scanner at '{'
  def extract_function_signature(scanner)
    start_pos = scanner.pos
    paren_depth = 0
    in_string = false
    string_char = nil
    signature_candidates = []  # Track positions where paren_depth returns to 0
    
    until scanner.eos?
      char = scanner.peek(1)

      # Safety check
      if (scanner.pos - start_pos) > @max_line_length
        raise CeedlingException.new("Function signature extraction exceeds maximum length of #{@max_line_length} characters")
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
        # Found opening brace - check if any of our candidates is valid
        if signature_candidates.empty?
          # No balanced parens found before brace - not a function
          scanner.pos = start_pos
          return nil
        end
        
        # The last candidate (outermost closing paren) should be the function parameter list
        signature_end_pos = signature_candidates.last
        
        # Extract and clean the signature
        signature = scanner.string[start_pos...signature_end_pos].strip
        signature.gsub!(/\r\n|\r|\n|\t/, ' ')
        signature.gsub!(/\s+/, ' ')
        
        return signature
      when ';'
        # Found semicolon - this is a declaration, not a definition
        if signature_candidates.any?
          # Skip past the semicolon
          scanner.getch
        else
          # No balanced parens found - reset position
          puts('B')
          scanner.pos = start_pos
        end
        return nil
      else
        scanner.getch
      end      
    end
    
    # Reached end without finding complete signature
    scanner.pos = start_pos
    nil
  end
  
end