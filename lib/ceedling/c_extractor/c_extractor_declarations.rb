# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/exceptions'

class CExtractorDeclarations

  def initialize(max_line_length)
    @max_line_length = max_line_length
  end

  def try_extract_variable(scanner)
    start_pos = scanner.pos

    # Track depth of various constructs
    paren_depth = 0
    bracket_depth = 0
    brace_depth = 0
    in_string = false
    string_char = nil
    seen_equals = false  # Track if we've seen an assignment operator
    
    # Scan until we find a semicolon at depth 0
    until scanner.eos?
      char = scanner.peek(1)
      
      # Safety check - prevent infinite loops on malformed input
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
            # Line comment - skip to end of line
            scanner.scan_until(/\n/) || scanner.terminate
          elsif scanner.peek(2) == '/*'
            # Block comment - skip to closing */
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
        seen_equals = true
        scanner.getch
      when '('
        paren_depth += 1
        scanner.getch
      when ')'
        paren_depth -= 1
        scanner.getch
        # Unbalanced parentheses - not a valid declaration
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
        # Unbalanced brackets - not a valid declaration
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
        # Unbalanced braces - not a valid declaration
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

          # Clean up whitespace
          declaration = declaration.strip
          declaration.gsub!(/\r\n|\r|\n|\t/, ' ')
          declaration.gsub!(/\s+/, ' ')
          
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
          # Semicolon inside parens, brackets, or braces - keep scanning
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