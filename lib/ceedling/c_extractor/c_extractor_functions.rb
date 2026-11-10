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

  # An identifier with a parameter list or a specifier's argument after it
  CALLED_IDENTIFIER = /(?:^|[\s*])(#{IDENTIFIER.source})\s*\(/ unless const_defined?(:CALLED_IDENTIFIER, false)

  # A specifier up to the '(' of its argument
  SPECIFIER_CALL = /(?<![\w$])(?:#{SPECIFIERS_WITH_ARGUMENTS.join( '|' )})\s*(?=\()/ unless const_defined?(:SPECIFIER_CALL, false)

  # What follows a parameter list's '('. A list is empty, or opens with a word, an ellipsis or a
  # C23 attribute. A line splice may come first, and so may a directive that fallback
  # preprocessing leaves in place.
  PARAMETERS_AHEAD = /[\s\\]*(?:\)|[A-Za-z_$#]|\.\.\.|\[\[)/ unless const_defined?(:PARAMETERS_AHEAD, false)

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
  #   - Variables with an asm label: int x asm("sym");
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
    signature_candidates = []  # Track positions where paren_depth returns to 0
    found_opening_paren = false  # Track if we've seen an opening paren

    until scanner.eos?
      char = scanner.peek(1)

      case char
      when '"', "'"
        # A literal is passed whole, escapes included, so nothing in it counts
        @code_text.skip_c_string(scanner, char)
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
        return _definition_end( scanner, start_pos, type, signature_candidates )
      when ';'
        return _declaration_end( scanner, start_pos, type, found_opening_paren )
      when '['
        # A C23 attribute passes whole, so its brackets and literals don't count
        next @code_text.collect_balanced(scanner, '[', ']') if @code_text.c23_attribute_at?(scanner)

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

  # The signature a '{' ends, or nil. Only a definition has one. Its parameter list is the last
  # group to close ahead of the brace, and with no group there the text is no function's.
  def _definition_end(scanner, start_pos, type, candidates)
    return _rewind( scanner, start_pos ) unless type == :definition and candidates.any?

    return clean_signature( scanner.string.byteslice( start_pos, candidates.last - start_pos ) )
  end

  # The signature a ';' ends, or nil. Only a declaration has one, and only when it declares a
  # function (see _prototype?). On success the scanner passes the ';'.
  def _declaration_end(scanner, start_pos, type, found_opening_paren)
    cleaned = clean_declaration( scanner.string.byteslice( start_pos, scanner.pos + 1 - start_pos ) ) if type == :declaration and found_opening_paren
    return _rewind( scanner, start_pos ) unless cleaned and _prototype?( cleaned )

    scanner.pos += 1
    return cleaned
  end

  # Whether a declaration with a parenthesis declares a function rather than a variable. A name
  # inside a pointer group declares a function only when a parameter list follows it. Otherwise the
  # declaration is an object's, such as a pointer to a function or an array. Any other
  # function's declaration ends with its parameter list. Extensions may follow that list and are
  # passed over, so `int x __attribute__((aligned(16)));` stays a variable. Attributes may sit
  # among a group's stars too. An asm label changes the rule (see _labeled_prototype?).
  def _prototype?(cleaned)
    unlabeled = CExtractorDeclarator::AsmLabel.without( cleaned )
    stripped  = @code_text.strip_compiler_extensions( unlabeled ).sub( /\s*;\z/, '' )
    grouped   = CExtractorDeclarator.parenthesized( stripped )
    return grouped.follows == '(' if grouped

    return (unlabeled == cleaned) ? stripped.end_with?( ')' ) : _labeled_prototype?( stripped )
  end

  # Whether a declaration with an asm label, read without it, declares a function. Unexpanded
  # macros may sit around the label, as in `int f(void) MY_API asm("f");`, so the text need not
  # end with the list. A function's text holds a group outside brackets that opens like a
  # parameter list. A macro's argument such as `(4)` or `(".data")` can't, so
  # `int MY_ALIGN(4) g asm("g");` stays a variable. A specifier's argument may, and is passed
  # over, as in `typeof(int) g asm("g");`. A macro's word argument reads as a parameter list,
  # since the two can't be told apart unexpanded.
  def _labeled_prototype?(text)
    scanner = StringScanner.new( text )
    depth   = 0
    while scanner.skip_until( CExtractorDeclarator::BALANCE_TOKEN )
      token = scanner.matched
      return true if token == '(' and depth.zero? and scanner.match?( PARAMETERS_AHEAD ) and !CExtractorDeclarator._specifier_argument?( text, scanner.pos - 1 )

      depth += CExtractorDeclarator::DEPTH_CHANGE.fetch( token, 0 )
    end

    return false
  end

  # Returns the scanner to where a signature's scan started, and gives nil
  def _rewind(scanner, start_pos)
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

    # The name is the first identifier followed by '(', after whitespace or a '*' for a pointer
    # return. A specifier, as in `typeof(int) f(void)`, takes parentheses too and names nothing.
    # Its argument is emptied first, since a call inside one, as in `typeof(g(1))`, names
    # another function.
    words = _without_specifier_arguments( cleaned ).scan( CALLED_IDENTIFIER ).flatten
    return words.find { |word| !SPECIFIERS_WITH_ARGUMENTS.include?( word ) }
  end

  # The text with each specifier's argument emptied, so `typeof(g(1)) f(void)` reads
  # `typeof() f(void)`
  def _without_specifier_arguments(text)
    scanner = StringScanner.new( text )
    emptied = +''
    while (before = scanner.scan_until( SPECIFIER_CALL ))
      emptied << before
      break unless CExtractorDeclarator._skip_balanced( scanner )

      emptied << '()'
    end

    return emptied << scanner.rest
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