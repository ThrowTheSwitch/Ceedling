# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/exceptions'
require 'ceedling/c_extractor/c_extractor_constants'

class CExtractorDeclarations

  include CExtractorConstants

  # Struct representing a single parsed C variable declaration
  CVariableDeclaration = Struct.new(
    :original,    # Full original C text (e.g., "static int x, y;") -- shared by all Structs 
                  # created from a single compound declaration.
    :name,        # Variable name (e.g., "x")
    :type,        # Type without decorator keywords (e.g., "int", "char*")
    :decorators,  # Array of decorator keyword strings (e.g., ["static", "const"])
    :declaration, # Cleaned declaration without decorators, whitespace normalized (e.g., "int x;")
    keyword_init: true
  ) do
    def initialize(original: nil, name: nil, type: nil, decorators: [], declaration: nil)
      super
    end
  end

  # For testing access
  attr_writer :max_line_length

  def initialize()
    # Default
    @max_line_length = DEFAULT_MAX_LINE_LENGTH
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
  #   - Compound declarations: `int x, y;` expanded to one struct per variable
  #
  # The extraction process:
  #   1. Tracks nesting depth of (), [], and {} to handle complex declarations
  #   2. Properly handles string literals (both " and ') including escape sequences
  #   3. Skips comments (both // line comments and /* block comments */)
  #   4. Stops at the first semicolon found at depth 0 (outside all nesting)
  #   5. Validates the extracted text looks like a valid declaration
  #   6. Expands compound declarations and parses each into a CVariableDeclaration struct
  #
  # Parameters:
  #   scanner: StringScanner positioned at potential start of variable declaration
  #
  # Returns: Array of [success, declarations]
  #   - success: Boolean indicating if a valid declaration was found
  #   - declarations: Array of CVariableDeclaration structs (nil if not found)
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
            return [true, expand_and_parse(declaration)]
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

  private

  # Expand compound declarations and parse each into CVariableDeclaration structs
  #
  # Parameters:
  #   raw_text: String containing a complete C declaration (e.g., "static int x, y;")
  #
  # Returns: Array<CVariableDeclaration>
  def expand_and_parse(raw_text)
    expand_compound(raw_text).map { |individual| parse_declaration(individual, raw_text) }
  end

  # Detect and split compound declarations (e.g., "int x, y;" => ["int x;", "int y;"])
  #
  # Splits at depth-0 commas that appear before any initializer (=).
  # Preserves pointer specifiers (*) from the base type prefix.
  #
  # Parameters:
  #   raw_text: Complete declaration string including trailing semicolon
  #
  # Returns: Array<String> of individual declaration strings
  def expand_compound(raw_text)
    # Determine the text before any initializer to look for commas
    pre_init = raw_text.split('=', 2).first || raw_text

    # Find depth-0 commas in the pre-initializer portion
    depth = 0
    comma_positions = []
    pre_init.each_char.with_index do |ch, i|
      case ch
      when '(', '[', '{' then depth += 1
      when ')', ']', '}' then depth -= 1
      when ',' then comma_positions << i if depth == 0
      end
    end

    return [raw_text] if comma_positions.empty?

    # Extract the base type prefix (everything before the first declarator)
    # The prefix is everything up to the first declarator token after the last type keyword
    first_comma = comma_positions.first
    prefix_with_first = raw_text[0...first_comma].strip

    # Determine the type prefix: everything before the last identifier/pointer declarator
    # Split the pre-comma text to identify the base type
    base_type = extract_base_type_prefix(prefix_with_first)

    # Collect all declarators: split by depth-0 commas, then handle the last one (before ;)
    # Build the full raw text without the semicolon
    text_body = raw_text.rstrip.chomp(';').strip

    declarators = []
    depth = 0
    current = ''
    text_body.each_char do |ch|
      case ch
      when '(', '[', '{' then depth += 1; current << ch
      when ')', ']', '}' then depth -= 1; current << ch
      when ','
        if depth == 0
          declarators << current.strip
          current = ''
        else
          current << ch
        end
      else
        current << ch
      end
    end
    declarators << current.strip unless current.strip.empty?

    # Reconstruct individual declarations
    declarators.map do |declarator|
      # Strip leading type tokens from subsequent declarators (they already have the type from base_type)
      # The first declarator already includes the full type; subsequent ones just have the name/pointer
      if declarator == declarators.first
        "#{declarator};"
      else
        # Subsequent declarators: prepend base type (without trailing pointer specifiers)
        clean_base = base_type.gsub(/\*+\s*$/, '').strip
        # Preserve pointer specifiers on the declarator name itself
        "#{clean_base} #{declarator};"
      end
    end
  end

  # Extract the base type prefix from the first declarator in a compound declaration
  # e.g., "static int *p" => "static int"
  #       "const char *s1" => "const char"
  #       "unsigned long x" => "unsigned long"
  def extract_base_type_prefix(first_declarator_text)
    # Remove leading/trailing whitespace
    text = first_declarator_text.strip

    # Remove pointer specifiers and the identifier at the end
    # The identifier is the last word token; pointers are * before it
    text_no_ptr = text.gsub(/\*+\s*\w+\s*$/, '').strip
    if text_no_ptr.empty? || text_no_ptr == text
      # No pointer -- remove just the trailing identifier
      text.gsub(/\s*\w+\s*$/, '').strip
    else
      text_no_ptr
    end
  end

  # Parse a single (non-compound) declaration string into a CVariableDeclaration struct
  #
  # Parameters:
  #   individual_text: Single declaration string (e.g., "static int x;")
  #   original_text:   The original (possibly compound) declaration text
  #
  # Returns: CVariableDeclaration
  def parse_declaration(individual_text, original_text)
    decorators = extract_decorators(individual_text)
    clean_text  = strip_decorators(individual_text, decorators)
    name        = extract_name(clean_text)
    type        = extract_type(clean_text, name)

    CVariableDeclaration.new(
      original:    original_text,
      name:        name,
      type:        type,
      decorators:  decorators,
      declaration: clean_text
    )
  end

  # Scan leading whole-word tokens against DECORATOR_KEYWORDS
  #
  # Returns: Array<String> ordered decorator keywords found at start of text
  def extract_decorators(text)
    decorators = []
    remaining = text.strip
    loop do
      matched = false
      DECORATOR_KEYWORDS.each do |kw|
        if remaining =~ /\A#{Regexp.escape(kw)}\b(.*)/m
          decorators << kw
          remaining = $1.strip
          matched = true
          break
        end
      end
      break unless matched
    end
    decorators
  end

  # Remove decorator keywords from text and normalize whitespace
  #
  # Returns: String with decorators removed, whitespace normalized, semicolon retained
  def strip_decorators(text, decorators)
    result = text.dup
    decorators.each do |kw|
      result.gsub!(/\b#{Regexp.escape(kw)}\b\s*/, '')
    end
    # Normalize whitespace but preserve semicolon
    result.gsub!(/\r\n|\r|\n|\t/, ' ')
    result.gsub!(/\s+/, ' ')
    result.strip!
    # Ensure ends with semicolon (may have been trimmed)
    result << ';' unless result.end_with?(';')
    result
  end

  # Extract the variable name from a clean (decorator-stripped) declaration
  #
  # Returns: String or nil
  def extract_name(clean_text)
    # Function pointers: void (*callback)(int);
    if clean_text =~ /\(\s*\*(\w+)\s*\)/
      return $1
    end

    # Strip only the trailing semicolon (not inner semicolons in e.g. struct bodies)
    text = clean_text.sub(/\s*;\s*$/, '')
    # Strip initializer (from first = onward)
    text = text.sub(/\s*=.*/, '')
    # Strip array subscripts
    text = text.gsub(/\[.*?\]/, '')
    # Strip trailing whitespace and return last word token
    text.strip =~ /(\w+)\s*$/ ? $1 : nil
  end

  # Extract the type from a clean (decorator-stripped) declaration
  #
  # Returns: String or nil
  def extract_type(clean_text, name)
    return nil if name.nil?

    # Find last occurrence of name in the text (before ; or [)
    # Strip only trailing semicolon to avoid matching inner semicolons (e.g., in struct bodies)
    text = clean_text.sub(/\s*;\s*$/, '').sub(/\s*=.*/, '').gsub(/\[.*?\]/, '').strip

    # For function pointers like "void (*callback)(int)", type is everything before (*name)
    if text =~ /^(.*?)\(\s*\*#{Regexp.escape(name)}\s*\)/
      return $1.strip
    end

    # Find the name in the text and take everything before it (including pointer specifiers)
    idx = text.rindex(name)
    return nil if idx.nil?

    type_part = text[0...idx]
    # Include any pointer specifiers attached to the name
    if text[idx..] =~ /^#{Regexp.escape(name)}/
      # Look for * immediately before name (with optional space)
      type_part = type_part.rstrip
    end
    type_part.strip
  end

end
