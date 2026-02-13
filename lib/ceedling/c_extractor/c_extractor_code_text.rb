# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

class CExtractorCodeText

  # Extract a balanced block of braces from the scanner
  # Handles nested braces, string literals, and comments that might contain braces
  # 
  # Parameters:
  #   scanner: StringScanner positioned at the opening brace
  # 
  # Returns: [success, extracted_block] where:
  #   - success: boolean indicating if a complete balanced block was found
  #   - extracted_block: string containing the complete block including braces (nil on failure)
  # 
  # Side effects: Advances scanner position past the closing brace on success
  # 
  # Examples:
  #   "{ code }"           -> [true, "{ code }"]
  #   "{ a { b } c }"      -> [true, "{ a { b } c }"]
  #   "{ incomplete"       -> [false, nil]
  #   "not a brace"        -> [false, nil]
  def extract_balanced_braces(scanner)
    start_pos = scanner.pos
    
    # Verify we're starting at an opening brace
    return [false, nil] unless scanner.getch == '{'
    
    depth = 1
    
    until scanner.eos?
      char = scanner.peek(1)
      
      case char
      when '{'
        # Found nested opening brace -- increase depth
        depth += 1
        scanner.getch
      when '}'
        # Found closing brace -- decrease depth
        depth -= 1
        scanner.getch
        # When depth reaches 0, we've found the matching closing brace
        if depth == 0
          extracted_block = scanner.string[start_pos...scanner.pos]
          return [true, extracted_block]
        end
      when '"', "'"
        # Skip string literals that might contain braces
        skip_c_string(scanner, char)
      when '/'
        # Skip comments that might contain braces
        if scanner.peek(2) =~ %r{^(/[/*])}
          skip_comment(scanner)
        else
          scanner.getch
        end
      else
        # Regular character -- just advance
        scanner.getch
      end
    end
    
    # Reached end of input without finding matching closing brace
    [false, nil]
  end

  # Skip a C string or character literal
  # Handles escape sequences to avoid false termination on escaped quotes
  # 
  # Parameters:
  #   scanner: StringScanner positioned at the opening quote
  #   quote: The quote character (either '"' for strings or "'" for characters)
  # 
  # Returns: Number of bytes skipped (including opening and closing quotes)
  # 
  # Side effects: Advances scanner position past the closing quote (or to end of string if unterminated)
  # 
  # Examples:
  #   "hello"       -> skips 7 bytes
  #   'a'           -> skips 3 bytes
  #   "say \"hi\""  -> skips 11 bytes (handles escaped quotes)
  #   "path\\file"  -> skips 11 bytes (handles escaped backslashes)
  def skip_c_string(scanner, quote)
    start_pos = scanner.pos
    scanner.getch # Opening quote
    
    until scanner.eos?
      if scanner.scan(/\\/)
        scanner.getch
      elsif scanner.getch == quote
        break
      end
    end
    
    return (scanner.pos - start_pos)
  end

  # Skip consecutive semicolons and any intervening deadspace
  # 
  # This method handles cases where multiple semicolons appear in sequence,
  # potentially separated by whitespace, comments, or preprocessor directives.
  # This is valid C syntax (null statements) and can occur due to:
  #   - Macro expansions
  #   - Code generation
  #   - Coding mistakes that don't cause compilation errors
  # 
  # The method repeatedly:
  #   1. Skips any deadspace (whitespace, comments, preprocessor directives)
  #   2. Checks for a semicolon
  #   3. If found, consumes it and continues
  #   4. If not found, restores position and exits
  # 
  # Parameters:
  #   scanner: StringScanner positioned at potential semicolons/deadspace
  # 
  # Returns: Nothing (void method)
  # 
  # Side effects: Advances scanner position past all consecutive semicolons and deadspace
  # 
  # Examples:
  #   ";;;"                    -> skips all three semicolons
  #   "; ; ;"                  -> skips semicolons and spaces
  #   "; /* comment */ ;"      -> skips semicolons and comment
  #   "; code"                 -> skips first semicolon, stops at "code"
  #   "code"                   -> skips nothing
  def skip_semicolons(scanner)
    while !scanner.eos?
      start_pos = scanner.pos
      skip_deadspace(scanner)
      break if scanner.eos?
      
      # If we find a semicolon, consume it and continue
      if scanner.scan(/;/)
        next
      else
        # Not a semicolon, restore position and break
        scanner.pos = start_pos
        break
      end
    end
  end

  # Skip "deadspace" - non-code elements that should be ignored during extraction
  # Deadspace includes:
  #   - Whitespace (spaces, tabs, newlines, carriage returns)
  #   - Comments (both single-line // and multi-line /* */)
  #   - Preprocessor directives (lines starting with #, including multi-line directives)
  #
  # NOTE: C extraction is not implemented as a full C parser and/or preprocessor
  # We assume that the file to be processed is either relatively simple or has already been 
  # preprocessed to remove complex preprocessor directives, etc. Certain complex blocks
  # cannot be processed by this method.
  # 
  # This method repeatedly scans for and skips these elements until no more are found,
  # ensuring all consecutive deadspace is consumed in a single call.
  # 
  # Parameters:
  #   scanner: StringScanner positioned at potential deadspace
  # 
  # Returns: Number of bytes skipped
  # 
  # Side effects: Advances scanner position past all consecutive deadspace
  # 
  # Examples:
  #   "   \n// comment\n#define FOO\ncode" -> skips to "code"
  #   "/* block */  \t\ncode"              -> skips to "code"
  #   "code"                               -> skips 0 bytes (no deadspace)
  def skip_deadspace(scanner)
    start_pos = scanner.pos

    loop do
      initial = scanner.pos
      
      # Skip whitespace
      scanner.skip(/\s+/)
      
      # Skip comments
      skip_comment(scanner) if scanner.check(%r{/[/*]})
      
      # Skip preprocessor directives
      skip_preprocessor_directive(scanner) if scanner.check(/#/)
      
      # If nothing was skipped, we're done
      break if scanner.pos == initial
    end

    return (scanner.pos - start_pos)
  end
  
  def skip_comment(scanner)
    # Single line comment
    if scanner.scan(%r{//})
      scanner.skip_until(/\n/) || scanner.terminate
    # Multiline comment
    elsif scanner.scan(%r{/\*})
      scanner.skip_until(%r{\*/}) || scanner.terminate
    end
  end

  private
  
  # Skip preprocessor directives (lines starting with #)
  # Handles multiline directives with backslash continuation
  def skip_preprocessor_directive(scanner)
    return false unless scanner.scan(/#/)
    
    # Skip the rest of the directive line, handling line continuations
    loop do
      # Scan to end of line or backslash
      scanner.scan(/[^\n\\]*/)
      
      # Check if line continues
      if scanner.scan(/\\\n/)
        # Line continues, keep scanning
        next
      else
        # End of directive - consume the newline if present
        scanner.scan(/\n/)
        break
      end
    end
    
    true
  end
  
end