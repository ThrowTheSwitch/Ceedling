# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/c_extractor/c_extractor_constants'
require 'ceedling/c_extractor/c_extractor_types'
require 'ceedling/c_extractor/c_extractor_declarator'

class CExtractorFunctions

  include CExtractorConstants
  include CExtractorTypes

  constructor :c_extractor_code_text

  def setup()
    # Aliases
    @code_text = @c_extractor_code_text
  end

  def try_extract_function_declaration(scanner)
    # Look for function signature
    signature = extract_function_signature(scanner, :declaration)
    return [false, nil] unless signature

    name = extract_function_name(signature)
    decorators, signature_stripped = parse_decorators_and_strip(signature, name)
    return [true, CFunctionDeclaration.new(name: name, signature: signature, decorators: decorators, signature_stripped: signature_stripped)]
  end

  # Try to extract a complete function from the scanner
  # Returns [success, function_data] where:
  #  - success: boolean indicating if extraction was successful
  #  - function_data: CFunctionDefinition with as much info as available (may be partial on failure)
  def try_extract_function_definition(scanner, filepath)
    start_pos = scanner.pos

    # Look for function signature. extract_function_signature only ever returns
    # non-nil for :definition mode by matching the '{' case in its own scan loop, and
    # that case never consumes the brace -- the scanner is always left positioned
    # exactly on the real '{' here, so there's no separate deadspace-skip/brace-check
    # step to perform first.
    signature = extract_function_signature(scanner, :definition)
    return [false, CFunctionDefinition.new] unless signature

    # Extract function body
    success, braced_body = @code_text.extract_balanced_braces(scanner)
    unless success
      return [false, CFunctionDefinition.new(
        name: extract_function_name(signature),
        signature: signature,
        source_filepath: filepath,
        code_block: scanner.string[start_pos...scanner.pos]
      )]
    end
    
    # Extract full function definition
    code_block = scanner.string[start_pos...scanner.pos]
    
    # Fill out function data class
    name = extract_function_name(signature)
    decorators, signature_stripped = parse_decorators_and_strip(signature, name)

    func = CFunctionDefinition.new(
      name: name,
      signature: signature,
      source_filepath: filepath,
      body: braced_body,
      code_block: code_block,
      line_count: code_block.count("\n") + 1,
      decorators: decorators,
      signature_stripped: signature_stripped
    )

    return [true, func]
  end

  # Each name's pattern, compiled once, since a name is looked up for every function extracted.
  # The name must be a whole word followed by its parameter list.
  NAME_PATTERNS = Hash.new { |patterns, name| patterns[name] = /(?<![\w$])#{Regexp.escape( name )}(?=\s*\()/ } unless const_defined?(:NAME_PATTERNS, false)

  # Where a function's name starts in text that begins with its signature, or nil. The name must
  # be a whole word followed by its parameter list, so `f` is never found inside `float`.
  def self.name_position(text, name)
    return text.index( NAME_PATTERNS[name] )
  end

  # Removes each listed token once, matching whole whitespace-separated tokens only, so the
  # same word inside an attribute string or a longer name stays. Spaces after a removed token
  # go with it. A newline stays, because a caller may count the lines a decorator occupied.
  def self.remove_tokens(text, tokens)
    parts = text.split( /(\s+)/ )

    tokens.each do |token|
      index = parts.index( token )
      next if index.nil?

      parts.delete_at( index )
      parts.delete_at( index ) if parts[index]&.match?( /\A[ \t]+\z/ )
    end

    return parts.join
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
  #   A signature with no terminating ')'/'{' runs the scan to the end of
  #   whatever buffer the caller (CExtractor#extract_next_feature) has grown so
  #   far; that caller is the one place enforcing an overall length ceiling,
  #   since only it knows how much more of the file remains to try growing into.
  def extract_function_signature(scanner, type)
    start_pos = scanner.pos
    # Tracks paren depth while accumulating candidate end-positions — not suitable for collect_balanced()
    paren_depth = 0
    in_string = false
    string_char = nil
    signature_candidates = []  # Track positions where paren_depth returns to 0
    found_opening_paren = false  # Track if we've seen an opening paren

    until scanner.eos?
      char = scanner.peek(1)

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
        # Hottest comparison in the extractor -- reached for every '/' in the
        # source. `start_with?` avoids compiling and running a regex here. The
        # original anchored pattern matched exactly these two character pairs.
        if scanner.peek(2).start_with?('//', '/*')
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

          # A name inside parentheses declares a function only when a parameter list follows it.
          # Otherwise the declaration is an object's, such as a pointer to a function or an array.
          # A pointer inside the parameter list declares a parameter and decides nothing.
          # Attributes may sit among the stars, so they are stripped first.
          grouped = CExtractorDeclarator.parenthesized( @code_text.strip_compiler_extensions( cleaned ) )
          if grouped and grouped.follows != '('
            scanner.pos = start_pos
            return nil
          end

          # A function returning a pointer to an array ends with the array's size, not a ')'
          return cleaned if grouped

          # Additional check: ensure the pattern is identifier(...); not identifier[...]; or identifier;
          # Strip compiler extensions (e.g. trailing __attribute__((...)) or __declspec(...)) before
          # checking the closing paren — otherwise a trailing attribute's ')' fools the check into
          # accepting a variable declaration like `int x __attribute__((aligned(16)));` as a function.
          content_before_semicolon = @code_text.strip_compiler_extensions(cleaned.gsub(/\s*;$/, ''))
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

  # Splits a function signature into its decorators and the signature without them.
  # Decorators are the storage-class and inline keywords of FUNCTION_DECORATOR_KEYWORDS.
  # Every other word before the name keeps its place and order. That includes the return type's
  # qualifiers, type keywords and typedef names, and also `_Noreturn`, attributes, calling
  # conventions and unexpanded macros. Reconciling with the fully expanded copy resolves a
  # macro that hides a storage class.
  #
  # Parameters:
  #   signature: Complete function signature string
  #   name:      Function name string (used to split the signature)
  #
  # Returns: [decorators_array, shortened_signature_string]
  # Example: "static const char *foo(void)" with name "foo"
  #   => [["static"], "const char *foo(void)"]
  def parse_decorators_and_strip(signature, name)
    return [[], signature] if name.nil?

    cut = self.class.name_position( signature, name )
    return [[], signature] if cut.nil?

    prefix    = signature[0...cut]
    remainder = signature[cut..]

    decorators = prefix.split( /\s+/ ).select { |token| FUNCTION_DECORATOR_KEYWORDS.include?( token ) }
    return [[], signature] if decorators.empty?

    return decorators, "#{self.class.remove_tokens( prefix, decorators ).lstrip}#{remainder}"
  end

  def extract_function_name(signature)
    # If parentheses aren't balanced, return nil
    return nil unless parens_balanced?( signature )

    # Strategy: Find the main parameter list by looking for the pattern:
    # identifier followed by '(' that represents the function's parameter list

    cleaned = @code_text.strip_compiler_extensions(signature.dup)

    # A function returning a function pointer, as in int (*name(params))(params), names itself
    # inside the declarator's parentheses
    grouped = CExtractorDeclarator.parenthesized( cleaned )
    return grouped.name if grouped and grouped.follows == '('

    # Now find the function name in the cleaned signature
    # Look for: identifier followed by '('
    # The identifier should be preceded by whitespace or * (for pointer returns)
    if cleaned =~ /(?:^|[\s*])(#{IDENTIFIER.source})\s*\(/
      return $1
    end
    
    # Fallback: no valid function name found
    nil
  end

  # True when every ')' closes an earlier '(' and none stays open. It only counts, so it needs
  # nothing collect_balanced() does.
  def parens_balanced?(text)
    depth = 0
    text.each_char do |char|
      depth += 1 if char == '('
      depth -= 1 if char == ')'
      return false if depth < 0
    end

    return depth.zero?
  end

end