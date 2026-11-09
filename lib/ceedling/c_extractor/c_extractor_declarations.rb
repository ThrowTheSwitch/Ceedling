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
  DECLARATION_SHAPE = /[\w$]+.*[\w$\]\)\}"']\s*;$/m unless const_defined?(:DECLARATION_SHAPE, false)

  # A declaration's last identifier, which names its variable once suffixes are gone
  LAST_IDENTIFIER = /(?<![\w$])(#{IDENTIFIER.source})\s*\z/ unless const_defined?(:LAST_IDENTIFIER, false)

  # A parenthesized group, nested ones included, or an array size outside any group
  GROUP_OR_ARRAY_SIZE = /(?<group>\((?:[^()]|\g<group>)*\))|\[[^\]]*\]/ unless const_defined?(:GROUP_OR_ARRAY_SIZE, false)

  # A declaration's array sizes, which follow its name
  ARRAY_SUFFIX = /[\w$](\s*(?:\[[^\]]*\])+)\s*\z/ unless const_defined?(:ARRAY_SUFFIX, false)

  # A comma, or a bracket or literal whose commas don't split a compound declaration
  SPLIT_TOKEN = Regexp.union( /,/, CExtractorDeclarator::BALANCE_TOKEN ) unless const_defined?(:SPLIT_TOKEN, false)

  # A bracket, a literal, a star or a word, which locate where a declarator starts
  DECLARATOR_TOKEN = Regexp.union( CExtractorDeclarator::BALANCE_TOKEN, /\*/, CExtractorDeclarator::WORD ) unless const_defined?(:DECLARATOR_TOKEN, false)

  # A base type no declaration has. An array size follows a name, and a builtin type or a tag
  # can't be followed by a plain word. Either means a macro after the first name, such as an
  # attribute, was read as the name.
  MISREAD_BASE = /[\w$]\s*\[|\b(?:(?:void|char|short|int|long|float|double|signed|unsigned|_Bool|_Complex)|(?:struct|union|enum)\s+[A-Za-z_$][\w$]*)\s+(?!(?:const|volatile|restrict|void|char|short|int|long|float|double|signed|unsigned|_Bool|_Complex)\b)[A-Za-z_$][\w$]*\s*\z/ unless const_defined?(:MISREAD_BASE, false)

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

  # Expand compound declarations and parse each into CVariableDeclaration structs. A compound
  # declaration that can't be split stays one record with no name, like any declaration whose
  # name can't be read.
  #
  # Parameters:
  #   text:     A complete declaration with its comments blanked (e.g., "static int x, y;")
  #   raw_text: The same declaration as written, which each record keeps as its `original`
  #
  # Returns: Array<CVariableDeclaration>
  def expand_and_parse(text, raw_text)
    pieces = expand_compound(text)
    return [parse_declaration(text, raw_text).tap { |var| var.name = var.type = var.declarator = nil }] if pieces.nil?

    pieces.map { |individual| parse_declaration(individual, raw_text) }
  end

  # Splits a compound declaration into one per variable, as `int x = 0, y;` into `int x = 0;`
  # and `int y;`. A comma outside parentheses, brackets, braces and literals separates two
  # declarators, wherever the initializers sit. Each declarator after the first takes the first
  # one's base type, the text ahead of its declarator. A base type no declaration has means a
  # macro after the first name was read as the name, so the statement stays whole.
  #
  # Parameters:
  #   text: A complete declaration with its comments blanked, its trailing semicolon included
  #
  # Returns: Array<String> of individual declaration strings, or nil for a compound declaration
  #   whose first name can't be read, which leaves its base type unknown
  def expand_compound(text)
    first, *rest = _top_level_pieces( text.rstrip.chomp( ';' ).strip )
    return [text] if rest.empty?

    base_type = _base_type( first )
    return nil if base_type.nil?
    return [text] if base_type.match?( MISREAD_BASE )

    return ["#{first};"] + rest.map { |declarator| "#{base_type} #{declarator};" }
  end

  # The text's pieces between commas outside parentheses, brackets, braces and literals
  def _top_level_pieces(body)
    scanner = StringScanner.new( body )
    depth   = 0
    cuts    = [0]
    while scanner.skip_until( SPLIT_TOKEN )
      depth += CExtractorDeclarator::DEPTH_CHANGE.fetch( scanner.matched, 0 )
      cuts << scanner.pos if scanner.matched == ',' and depth.zero?
    end

    return _between( body, cuts << (body.bytesize + 1) )
  end

  # The text between each pair of cuts, stripped and less the comma that ends each piece. An
  # empty piece is dropped.
  def _between(body, cuts)
    return cuts.each_cons( 2 ).map { |from, to| body.byteslice( from, to - from - 1 ).strip }.reject( &:empty? )
  end

  # The first declarator's base type, or nil when its name can't be read. A star and the
  # qualifiers after it belong to the declarator, as do an attribute or asm label after the
  # name, so the base type ends at the first star outside brackets or else at the name. The name
  # is read as the declaration's own record reads it.
  def _base_type(first)
    head    = CExtractorDeclarator::AsmLabel.without( CExtractorDeclarator.without_initializer( first ) ).gsub( /\s+/, ' ' )
    grouped = CExtractorDeclarator.parenthesized( head )
    return grouped.base_type if grouped

    name  = extract_name( @code_text.strip_compiler_extensions( head ) )
    start = name && _declarator_start( head, name )
    return start && head.byteslice( 0, start ).strip
  end

  # Where a declarator starts in the text ahead of any initializer. That is its first star or
  # its name, whichever comes first, outside brackets. The name is its last appearance there, as
  # a tag may share it, as in `struct count count`.
  def _declarator_start(head, name)
    scanner = StringScanner.new( head )
    depth   = 0
    while scanner.skip_until( DECLARATOR_TOKEN )
      token  = scanner.matched
      depth += CExtractorDeclarator::DEPTH_CHANGE.fetch( token, 0 )
      next unless depth.zero?

      star ||= scanner.pos - 1 if token == '*'
      at     = scanner.pos - name.bytesize if token == name
    end

    return [star, at].compact.min
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
    clean_text = normalize_declaration_whitespace(remaining)

    return CVariableDeclaration.new(
      original: original_text, decorators: decorators, text: clean_text,
      asm_label: CExtractorDeclarator::AsmLabel.of( clean_text ),
      **_declared( CExtractorDeclarator::AsmLabel.without( clean_text ) )
    )
  end

  # The name, type, array size and declarator of a declaration without its decorators and asm
  # label. They are read with compiler extensions stripped. The record's text keeps the
  # extensions and the label, so the definition compiles as the module's does.
  def _declared(unlabeled)
    extraction_text = @code_text.strip_compiler_extensions( unlabeled )
    # A function pointer or a pointer to an array names its variable inside parentheses
    grouped = CExtractorDeclarator.parenthesized( CExtractorDeclarator.without_initializer( extraction_text ) )
    return { name: grouped.name, type: grouped.base_type, array_suffix: '', declarator: written_declarator( unlabeled, grouped ) } if grouped

    name = extract_name( extraction_text )
    return { name: name, type: extract_type( extraction_text, name ), array_suffix: extract_array_suffix( extraction_text ) }
  end

  # The declarator as written. An extern repeats it, so a calling convention or attribute among
  # its stars must stay to agree with the definition. Stripping extensions removes them. The
  # written text stands only when it opens the same group, which the text ahead of each group
  # shows once extensions are stripped. Otherwise the stripped declarator stands.
  def written_declarator(clean_text, grouped)
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
    # Strip the trailing semicolon and any initializer. Only an '=' outside brackets starts one,
    # so an array size such as `[N == 2 ? 2 : 3]` stays.
    text = CExtractorDeclarator.without_initializer( clean_text )
    # Strip array subscripts
    text = _without_array_sizes( text )
    # Strip trailing whitespace and return the last identifier
    text.strip[LAST_IDENTIFIER, 1]
  end

  # The text without its array sizes. A bracket inside parentheses belongs to a type a specifier
  # spells, as in `typeof(int[3])`, so it stays.
  def _without_array_sizes(text)
    return text.gsub( GROUP_OR_ARRAY_SIZE ) { |match| match.start_with?( '(' ) ? match : '' }
  end

  # Extract array subscript suffix from a clean (decorator/extension-stripped) declaration.
  # Returns the complete subscript string (e.g., "[8]", "[M][N]") or "" for scalars.
  def extract_array_suffix(clean_text)
    text = CExtractorDeclarator.without_initializer( clean_text )
    text =~ ARRAY_SUFFIX ? $1.strip : ''
  end

  # Extract the type from a clean (decorator-stripped) declaration
  #
  # Returns: String or nil
  def extract_type(clean_text, name)
    return nil if name.nil?

    # Find last occurrence of name in the text, once its semicolon, initializer and array
    # subscripts are gone
    text = _without_array_sizes( CExtractorDeclarator.without_initializer( clean_text ) ).strip

    # Find the name in the text and take everything before it, pointer specifiers included. The
    # name must be a whole identifier, so `count` isn't found inside `recount` or `count$2`.
    # Greedy `.*` in a single match finds its rightmost such occurrence, since it consumes as
    # much as it can before backtracking just enough for the name to match.
    match = text.match(/\A(.*)(?<![\w$])#{Regexp.escape(name)}(?![\w$])/m)
    return nil if match.nil?

    type_part = match[1]
    type_part.strip
  end

end
