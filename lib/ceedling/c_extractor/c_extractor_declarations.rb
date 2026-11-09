# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/exceptions'
require 'ceedling/c_extractor/c_extractor_constants'
require 'ceedling/c_extractor/c_extractor_types'
require 'ceedling/c_extractor/c_extractor_declarator'

class CExtractorDeclarations

  include CExtractorConstants
  include CExtractorTypes

  constructor :c_extractor_code_text

  def setup()
    # Aliases
    @code_text = @c_extractor_code_text
  end

  # Text without a quote, a '/', a delimiter or a ';', which the scan passes in one step. A run
  # stops at every '/', since one may start a comment.
  PLAIN_RUN = %r{[^"'/()\[\]{};]+} unless const_defined?(:PLAIN_RUN, false)

  # Each delimiter's own kind of depth, and how the delimiter changes it
  DELIMITER_DEPTH = {
    '(' => [:paren, 1], ')' => [:paren, -1], '[' => [:bracket, 1], ']' => [:bracket, -1],
    '{' => [:brace, 1], '}' => [:brace, -1]
  }.freeze unless const_defined?(:DELIMITER_DEPTH, false)

  # How a declaration's text looks once its comments are blanked. A type and a name come first,
  # and the last character before the ';' closes a name, a suffix, an initializer or a literal.
  # A multiline initializer still matches.
  DECLARATION_SHAPE = /\w+.*[\w\]\)\}"']\s*;$/m unless const_defined?(:DECLARATION_SHAPE, false)

  # Extracts a complete variable declaration from the scanner, through its terminating ';'.
  #
  # The scan counts parentheses, brackets and braces apart, and the declaration ends at the
  # first ';' outside all three. Literals and comments are passed whole, so nothing inside one
  # counts. A compound declaration, such as `int x, y;`, yields one record per variable.
  #
  # Fallback preprocessing leaves comments in place. So each comment is blanked to a space
  # before the text is checked, split and parsed, and a `//` can't swallow the rest of a joined
  # line. Each record's `original` keeps the text as the scan read it.
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
  #   A declaration with no terminating ';', or with a block comment that never closes, runs
  #   the scan to the end of the buffer. The caller, CExtractor#extract_next_feature, grows the
  #   buffer and alone enforces the overall length ceiling, since only it knows how much of the
  #   file remains.
  def try_extract_variable(scanner)
    start_pos = scanner.pos
    depths    = Hash.new( 0 )

    until scanner.eos?
      token = _pass_token( scanner )
      break unless _track_depth( depths, token )
      return _variable_found( scanner, start_pos ) if token == ';' and depths.values.all?( &:zero? )
    end

    scanner.pos = start_pos
    return [false, nil]
  end

  private

  # Moves the scanner past one token. Returns it when it's a delimiter, a ';' or a lone '/', and
  # nil when it's a literal, a comment or a run of plain text.
  def _pass_token(scanner)
    char = scanner.peek( 1 )
    if char == '"' or char == "'"
      @code_text.skip_c_string( scanner, char )
    elsif scanner.check( %r{/[/*]} )
      @code_text.skip_comment( scanner )
    elsif !scanner.skip( PLAIN_RUN )
      return scanner.getch
    end

    return nil
  end

  # Counts a delimiter into its own kind's depth. False once any kind closes more than it opened.
  def _track_depth(depths, token)
    kind, change = DELIMITER_DEPTH[token]
    depths[kind] += change if kind
    return depths.values.none?( &:negative? )
  end

  # The declaration ending at the scanner, split and parsed, or a failure when its text doesn't
  # look like a declaration. The check and the parse read the text with its comments blanked.
  def _variable_found(scanner, start_pos)
    raw   = scanner.string.byteslice( start_pos, scanner.pos - start_pos )
    clean = _blank_comments( raw )
    return [true, expand_and_parse( clean, raw )] if clean.match?( DECLARATION_SHAPE )

    scanner.pos = start_pos
    return [false, nil]
  end

  # The text with each comment replaced by a space. A literal stays whole, so `"//"` survives.
  def _blank_comments(text)
    return text.gsub( CExtractorDeclarator::LITERAL_OR_COMMENT ) { |match| match.start_with?( '/' ) ? ' ' : match }
  end

  # Expand compound declarations and parse each into CVariableDeclaration structs
  #
  # Parameters:
  #   text:     A complete declaration with its comments blanked (e.g., "static int x, y;")
  #   raw_text: The same declaration as written, which each record keeps as its `original`
  #
  # Returns: Array<CVariableDeclaration>
  def expand_and_parse(text, raw_text)
    expand_compound(text).map { |individual| parse_declaration(individual, raw_text) }
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

    # Combined depth across (), [], {} for comma-splitting — not suitable for collect_balanced()
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
  #       "static int (*a)(int)" => "static int"
  def extract_base_type_prefix(first_declarator_text)
    # Remove leading/trailing whitespace
    text = first_declarator_text.strip

    # A parenthesized declarator is everything from its group onward
    grouped = CExtractorDeclarator.parenthesized( text )
    return grouped.base_type if grouped

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
    decorators, remaining = extract_decorators(individual_text)
    clean_text      = normalize_declaration_whitespace(remaining)
    # Strip compiler extensions for name/type/array_suffix extraction only;
    # clean_text (stored as .text) retains attributes for correct compilation.
    extraction_text = @code_text.strip_compiler_extensions(clean_text)
    # A function pointer or a pointer to an array names its variable inside parentheses
    grouped         = CExtractorDeclarator.parenthesized( CExtractorDeclarator.without_initializer( extraction_text ) )
    name            = grouped ? grouped.name : extract_name(extraction_text)

    CVariableDeclaration.new(
      original:     original_text,
      name:         name,
      type:         grouped ? grouped.base_type : extract_type(extraction_text, name),
      array_suffix: grouped ? '' : extract_array_suffix(extraction_text),
      decorators:   decorators,
      text:         clean_text,
      declarator:   written_declarator(clean_text, grouped)
    )
  end

  # The declarator as written. An extern repeats it, so a calling convention or attribute among
  # its stars and an asm label after it must stay to agree with the definition. Stripping
  # extensions removes them. The written text stands only when it opens the same group, which
  # the text ahead of each group shows once extensions are stripped. Otherwise the stripped
  # declarator stands.
  def written_declarator(clean_text, grouped)
    return nil if grouped.nil?

    written = CExtractorDeclarator.parenthesized( CExtractorDeclarator.without_initializer( clean_text ) )
    same    = (written and @code_text.strip_compiler_extensions( written.base_type ) == grouped.base_type)
    return same ? written.declarator : grouped.declarator
  end

  # Storage-class specifiers and base-type qualifiers precede a C declaration's type as a
  # contiguous run of keywords -- `static`, `extern`, and a `const`/`volatile` that qualifies
  # the type itself all appear here (e.g. `static const int MAX;`). A qualifier bound to a
  # pointer level instead, such as the second `const` in `char * const p;`, sits after the
  # type and its `*` tokens rather than in this leading run, so it is grammatically part of
  # the declarator, not a decorator. Peeling keywords off one at a time from the front, and
  # stopping at the first non-keyword token, naturally separates the two: the same keyword
  # (e.g. `const`) can appear once here and again later in the declarator without the two
  # occurrences being confused with each other, since only the leading run is ever consumed.
  #
  # Returns: [Array<String> ordered decorator keywords found at start of text, String remaining text after that run]
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
    [decorators, remaining]
  end

  # A declaration with its leading decorator run already removed (see extract_decorators)
  # still carries whatever whitespace and line breaks appeared in the source between its
  # remaining tokens. This collapses that whitespace to single spaces and guarantees a
  # trailing semicolon, so `.text` is stable, single-line C ready to compile.
  #
  # Returns: String with whitespace normalized, semicolon retained
  def normalize_declaration_whitespace(remaining)
    result = remaining.dup
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
    # Strip only the trailing semicolon (not inner semicolons in e.g. struct bodies)
    text = clean_text.sub(/\s*;\s*$/, '')
    # Strip initializer (from first = onward)
    text = text.sub(/\s*=.*/, '')
    # Strip array subscripts
    text = text.gsub(/\[.*?\]/, '')
    # Strip trailing whitespace and return last word token
    text.strip =~ /(\w+)\s*$/ ? $1 : nil
  end

  # Extract array subscript suffix from a clean (decorator/extension-stripped) declaration.
  # Returns the complete subscript string (e.g., "[8]", "[M][N]") or "" for scalars.
  def extract_array_suffix(clean_text)
    text = clean_text.sub(/\s*;\s*$/, '').sub(/\s*=.*/, '')
    text =~ /\w+(\s*(?:\[[^\]]*\])+)\s*$/ ? $1.strip : ''
  end

  # Extract the type from a clean (decorator-stripped) declaration
  #
  # Returns: String or nil
  def extract_type(clean_text, name)
    return nil if name.nil?

    # Find last occurrence of name in the text (before ; or [)
    # Strip only trailing semicolon to avoid matching inner semicolons (e.g., in struct bodies)
    text = clean_text.sub(/\s*;\s*$/, '').sub(/\s*=.*/, '').gsub(/\[.*?\]/, '').strip

    # Find the name in the text and take everything before it (including pointer specifiers).
    # A plain rindex(name) would find the last substring occurrence of `name` anywhere in
    # text, even inside an unrelated longer identifier that merely ends with it (e.g. `name`
    # "count" inside a type-side identifier like "recount") -- \b anchors this to a whole
    # identifier occurrence. Greedy `.*` in a single match (not scan) naturally finds the
    # rightmost such occurrence, since it consumes as much as possible before backtracking
    # just enough to let the trailing \bname\b still match.
    match = text.match(/\A(.*)\b#{Regexp.escape(name)}\b/m)
    return nil if match.nil?

    type_part = match[1]
    type_part.strip
  end

end
