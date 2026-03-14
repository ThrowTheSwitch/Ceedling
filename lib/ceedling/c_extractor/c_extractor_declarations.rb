# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/exceptions'
require 'ceedling/c_extractor/c_extractor_constants'

class CExtractorDeclarations

  # For testing access
  attr_writer :max_line_length

  def initialize()
    # Default
    @max_line_length = CExtractorConstants::DEFAULT_MAX_LINE_LENGTH
  end

  # Attempts to extract a complete variable declaration from the scanner
  #
  # Scans forward from the current scanner position looking for a complete C variable
  # declaration terminated by a semicolon. Handles complex declaration syntax including:
  #   - Simple variables: `int x;`
  #   - Pointers: `char* ptr;`, `int** buffer;`
  #   - Arrays: `int arr[10];`, `char matrix[3][4];`
  #   - Initializers: `int x = 5;`, `int arr[] = {1, 2, 3};`
  #   - String literals: `char* str = "hello";`
  #   - Qualifiers: `const int MAX;`, `static volatile int flag;`
  #   - Function pointers: `void (*callback)(int);`
  #   - Complex nested structures with balanced parentheses, brackets, and braces
  #
  # The extraction process:
  #   1. Tracks nesting depth of (), [], and {} to handle complex declarations
  #   2. Properly handles string literals (both " and ') including escape sequences
  #   3. Skips comments (both // line comments and /* block comments */)
  #   4. Stops at the first semicolon found at depth 0 (outside all nesting)
  #   5. Validates the extracted text looks like a valid declaration
  #   6. Normalizes whitespace in the final declaration string
  #
  # Parameters:
  #   scanner: StringScanner positioned at potential start of variable declaration
  #
  # Returns: Array of [success, declaration]
  #   - success: Boolean indicating if a valid declaration was found
  #   - declaration: String containing the complete declaration (nil if not found)
  #
  # Side effects:
  #   On success: Advances scanner position past the semicolon
  #   On failure: Resets scanner position to starting position
  #
  # Safety:
  #   Enforces max_line_length limit to prevent infinite loops on malformed input
  def try_extract_variable(scanner)
    start_pos = scanner.pos

    # Track depth of various constructs
    paren_depth = 0
    bracket_depth = 0
    brace_depth = 0
    in_string = false
    string_char = nil
    
    # Scan until we find a semicolon at depth 0.
    # If we reach the end of string scanner, we failed to find something.
    until scanner.eos?
      char = scanner.peek(1)
      
      # Safety check -- prevent infinite loops on malformed input
      if (scanner.pos - start_pos) > @max_line_length
        scanner.pos = start_pos
        return [false, nil]
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
        # Handle comments
        if scanner.peek(2) =~ %r{^(/[/*])}
          if scanner.peek(2) == '//'
            # Line comment -- skip to end of line
            scanner.scan_until(/\n/) || scanner.terminate
          elsif scanner.peek(2) == '/*'
            # Block comment -- skip to closing */
            scanner.pos += 2
            scanner.scan_until(%r{\*/})
          else
            scanner.getch
          end
        else
          scanner.getch
        end
      when '='
        # Track assignment for initializer detection
        scanner.getch
      when '('
        paren_depth += 1
        scanner.getch
      when ')'
        paren_depth -= 1
        scanner.getch
        # Unbalanced parentheses -- not a valid declaration
        if paren_depth < 0
          scanner.pos = start_pos
          return [false, nil]
        end
      when '['
        bracket_depth += 1
        scanner.getch
      when ']'
        bracket_depth -= 1
        scanner.getch
        # Unbalanced brackets -- not a valid declaration
        if bracket_depth < 0
          scanner.pos = start_pos
          return [false, nil]
        end
      when '{'
        # Braces after '=' are initializers, not code blocks
        brace_depth += 1
        scanner.getch
      when '}'
        brace_depth -= 1
        scanner.getch
        # Unbalanced braces -- not a valid declaration
        if brace_depth < 0
          scanner.pos = start_pos
          return [false, nil]
        end
      when ';'
        # Found semicolon - check if it's at depth 0
        if paren_depth == 0 && bracket_depth == 0 && brace_depth == 0
          # This is the end of a declaration
          scanner.getch  # Consume the semicolon
          
          # Extract the declaration
          declaration = scanner.string[start_pos...scanner.pos]

          # Verify this looks like a valid declaration
          # Must have at least a type and identifier
          # Can end with: word character, ], ), }, or " (for string initializers)
          if declaration =~ /\w+.*[\w\]\)\}"']\s*;$/
            return [true, declaration]
          else
            scanner.pos = start_pos
            return [false, nil]
          end
        else
          # Semicolon inside parens, brackets, or braces -- keep scanning
          scanner.getch
        end        
      else
        scanner.getch
      end
    end
    
    # Reached end without finding a complete declaration
    scanner.pos = start_pos
    [false, nil]
  end

end