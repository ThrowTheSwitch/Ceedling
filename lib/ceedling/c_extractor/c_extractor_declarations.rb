# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'set'
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

  # One item of a declaration's leading run. That is a decorator keyword, read whole, or an
  # alignment specifier or attribute with its arguments, whose literals may hold parentheses.
  LEADING_RUN_ITEM = /\A(?:(?<keyword>#{DECORATOR_KEYWORDS.map { |kw| Regexp.escape( kw ) }.join( '|' )})(?![\w$])|(?:_Alignas|alignas|__attribute__|__attribute|__declspec)\s*(?<group>\((?>[^()"']+|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|\g<group>)*\)))\s*/ unless const_defined?(:LEADING_RUN_ITEM, false)

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

  # A parenthesis or a bracket, or a literal or comment whose brackets don't count
  SIZE_TOKEN = Regexp.union( /[()\[]/, CExtractorDeclarator::LITERAL_OR_COMMENT ) unless const_defined?(:SIZE_TOKEN, false)

  # How each parenthesis changes the depth
  PAREN_CHANGE = { '(' => 1, ')' => -1 }.freeze unless const_defined?(:PAREN_CHANGE, false)

  # A declaration's array sizes, which follow its name
  ARRAY_SUFFIX = /[\w$](\s*(?:\[[^\]]*\])+)\s*\z/ unless const_defined?(:ARRAY_SUFFIX, false)

  # A comma, or a bracket or literal whose commas don't split a compound declaration
  SPLIT_TOKEN = Regexp.union( /,/, CExtractorDeclarator::BALANCE_TOKEN ) unless const_defined?(:SPLIT_TOKEN, false)

  # A bracket, a literal, a star or a word, which locate where a declarator starts
  DECLARATOR_TOKEN = Regexp.union( CExtractorDeclarator::BALANCE_TOKEN, /\*/, CExtractorDeclarator::WORD ) unless const_defined?(:DECLARATOR_TOKEN, false)

  # A base type's last two words, which may be a type and a name misread as part of it
  LAST_TWO_WORDS = /(?<![\w$])(?<type>[A-Za-z_$][\w$]*)\s+(?<word>[A-Za-z_$][\w$]*)\s*\z/ unless const_defined?(:LAST_TWO_WORDS, false)

  # Words that are no type, so the word after one is no name
  NOT_A_TYPE = (DECORATOR_KEYWORDS + CExtractorDeclarator::QUALIFIERS + %w[struct union enum _Thread_local thread_local __thread]).to_set.freeze unless const_defined?(:NOT_A_TYPE, false)

  # Keywords that may follow a builtin type or a tag ahead of a name, qualifiers and type and
  # storage keywords among them. None can be a name.
  TYPE_WORDS = (CExtractorDeclarator::QUALIFIERS + %w[
    void char short int long float double signed unsigned _Bool _Complex _Imaginary _Atomic _Thread_local thread_local
  ]).to_set.freeze unless const_defined?(:TYPE_WORDS, false)

  # A macro's spelling, all capitals
  MACRO_CASE = /\A[A-Z_][A-Z0-9_$]*\z/ unless const_defined?(:MACRO_CASE, false)

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
  # one's base type, the text ahead of its declarator. A misread base type means a macro after
  # the first name was read as the name, so the statement stays whole (see _misread_base?).
  #
  # Parameters:
  #   text: A complete declaration with its comments blanked, its trailing semicolon included
  #
  # Returns: Array<String> of individual declaration strings, or nil for a compound declaration
  #   whose first name can't be read, which leaves its base type unknown
  def expand_compound(text)
    first, *rest = _top_level_pieces( text.rstrip.chomp( ';' ).strip )
    return [text] if rest.empty?

    head      = CExtractorDeclarator::AsmLabel.without( CExtractorDeclarator.without_initializer( first ) ).gsub( /\s+/, ' ' )
    base_type, name = _base_type( head )
    return nil if base_type.nil?
    return [text] if _misread_base?( base_type, head, name )

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

  # The first declarator's base type and name. The base type is nil when the name can't be read.
  # The head is that declarator without its initializer and asm label, its spaces collapsed. A
  # star and the qualifiers after it belong to the declarator, as does an attribute after the
  # name, so the base type ends at the first star outside brackets or else at the name. The name
  # is read as the declaration's own record reads it.
  def _base_type(head)
    grouped = CExtractorDeclarator.parenthesized( head )
    return [grouped.base_type, grouped.name] if grouped

    name  = extract_name( @code_text.strip_compiler_extensions( head ) )
    start = name && _declarator_start( head, name )
    return [start && head.byteslice( 0, start ).strip, name]
  end

  # Whether the base type shows that a macro after the first name, such as an attribute, was
  # read as the name. A word ahead of a star is never the name, so a base type ending at a star
  # stands. An array size outside parentheses follows a name. A word after a type follows one
  # too when the name read is spelled as a macro is, in capitals or with a leading `__`, as in
  # `const u8 MAX_A UNUSED = 3, MAX_B = 1;` or `int a1 __maybe_unused, b1;`. A keyword or a
  # compiler's `__` extension there is part of the type, as in `int __far a, b;`. Any other word
  # is taken for a qualifier, as in `int MYQ a, b;` or `unsigned char xdata a, b;`. Without
  # expanding the macros, the two readings can't be told apart.
  def _misread_base?(base_type, head, name)
    return false if head.byteslice( base_type.bytesize, head.bytesize ).lstrip.start_with?( '*' )
    return true unless _without_array_sizes( base_type ) == base_type
    return false unless _type_then_name?( base_type.match( LAST_TWO_WORDS ) )

    return (name.to_s.match?( MACRO_CASE ) or name.to_s.start_with?( '__' ))
  end

  # Whether a base type's last two words may be a type and a name: the first is no storage
  # class, qualifier or keyword ahead of a tag, and the second no type keyword or extension
  def _type_then_name?(words)
    return false if words.nil? or NOT_A_TYPE.include?( words[:type] )

    return !(TYPE_WORDS.include?( words[:word] ) or words[:word].start_with?( '__' ))
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
  # An alignment specifier or attribute may sit in that run, as in `_Alignas(8) static int x;`.
  # It is no decorator, so it keeps its place ahead of the rest of the text.
  #
  # Returns: [Array<String> ordered decorator keywords found at start of text, String remaining text after that run]
  def extract_decorators(text)
    decorators = []
    kept       = []
    remaining  = text.strip
    while (found = remaining.match( LEADING_RUN_ITEM ))
      found[:keyword] ? decorators << found[:keyword] : kept << found[0].strip
      remaining = found.post_match
    end

    return [decorators, [*kept, remaining].join( ' ' )]
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
    scanner = StringScanner.new( text )
    kept    = +''
    parens  = 0
    while (before = scanner.scan_until( SIZE_TOKEN ))
      parens += PAREN_CHANGE.fetch( scanner.matched, 0 )
      next kept << before unless scanner.matched == '[' and parens.zero?

      kept << (_skip_size( scanner ) ? before.byteslice( 0, before.bytesize - 1 ) : before)
    end

    return kept << scanner.rest
  end

  # Moves the scanner, just past an array size's '[', past its matching ']'. When none follows,
  # the scanner stays, and the '[' is text.
  def _skip_size(scanner)
    after = scanner.pos
    scanner.pos = after - 1
    return true if CExtractorDeclarator._skip_balanced( scanner )

    scanner.pos = after
    return false
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
