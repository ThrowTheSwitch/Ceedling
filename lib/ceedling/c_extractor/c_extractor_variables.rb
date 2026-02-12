# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/exceptions'

class CExtractorVariables

  def initialize(max_line_length)
    @max_line_length = max_line_length
  end

  # Extract a variable declaration from the scanner
  # This method is designed to be reusable by CExtractorVariables in the future
  # 
  # A variable declaration:
  #   1. May contain parentheses (for function pointers, arrays, etc.)
  #   2. Ends with a semicolon ';'
  #   3. May have initializers with braces (arrays, structs)
  # 
  # Parameters:
  #   scanner: StringScanner positioned at the start of a potential variable declaration
  # 
  # Returns:
  #   - The declaration string if this is a variable declaration
  #   - nil if this is not a variable declaration
  # 
  # Side effects:
  #   - On success: Advances scanner past the semicolon
  #   - On failure: Resets scanner to starting position
  # 
  # Examples:
  #   "int x;"                                   -> returns "int x", scanner after ';'
  #   "static const char* ptr = "hello";"        -> returns "static const char* ptr = "hello"", scanner after ';'
  #   "int array[] = {1, 2, 3};"                 -> returns "int array[] = {1, 2, 3}", scanner after ';'
  #   "struct foo { int x; } instance;"          -> returns "struct foo { int x; } instance", scanner after ';'
  def try_extract_variable_declaration(scanner)
    start_pos = scanner.pos
    paren_depth = 0
    brace_depth = 0
    in_string = false
    string_char = nil
    
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
        scanner.getch
      when ')'
        paren_depth -= 1
        scanner.getch
        if paren_depth < 0
          # Unbalanced - not a valid declaration
          scanner.pos = start_pos
          return nil
        end
      when '{'
        # Opening brace could be:
        # 1. Part of an initializer: int arr[] = {1, 2, 3};
        # 2. Part of a struct definition: struct foo { int x; } var;
        # 3. Start of a function body (not a variable declaration)
        
        # If we see a '{' at brace_depth 0 after seeing parentheses,
        # this is likely a function definition, not a variable declaration
        if brace_depth == 0 && paren_depth == 0
          # This looks like a function body
          scanner.pos = start_pos
          return nil
        end
        
        brace_depth += 1
        scanner.getch
      when '}'
        brace_depth -= 1
        scanner.getch
        if brace_depth < 0
          # Unbalanced - not a valid declaration
          scanner.pos = start_pos
          return nil
        end
      when ';'
        # Found semicolon - this completes the declaration
        if paren_depth == 0 && brace_depth == 0
          # Extract and clean the declaration
          declaration = scanner.string[start_pos...scanner.pos].strip
          declaration.gsub!(/\r\n|\r|\n|\t/, ' ')
          declaration.gsub!(/\s+/, ' ')
          
          # Skip past the semicolon
          scanner.getch
          
          return declaration
        else
          # Unbalanced - not a valid declaration
          scanner.pos = start_pos
          return nil
        end
      else
        scanner.getch
      end      
    end
    
    # Reached end without finding complete declaration
    scanner.pos = start_pos
    return nil
  end

end