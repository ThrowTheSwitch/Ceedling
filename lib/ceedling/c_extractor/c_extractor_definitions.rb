# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'strscan'
require 'ceedling/c_extractor/c_extractor_constants'
require 'ceedling/c_extractor/c_extractor_declarator'

class CExtractorDefinitions

  constructor :c_extractor_code_text

  # How a brace changes a body's nesting depth
  BRACE_DEPTH = { '{' => 1, '}' => -1 }.freeze unless const_defined?(:BRACE_DEPTH, false)

  # Text without a literal, a comment, a brace or a ';', which a statement's scan takes in one step
  PLAIN_RUN = %r{[^"'/{};]+} unless const_defined?(:PLAIN_RUN, false)

  # A group only a function's head ends with, `(void)` or one around a pointer as in `(*get(void))`
  FUNCTION_GROUP = /\A(?:\(\s*void\s*\)\z|#{CExtractorDeclarator::POINTER_GROUP.source})/ unless const_defined?(:FUNCTION_GROUP, false)

  # A word C reserves for the implementation with no arguments after it, as an attribute macro
  # such as `__packed` is
  BARE_EXTENSION = /__[\w$]*+(?!\s*\()/ unless const_defined?(:BARE_EXTENSION, false)

  # An attribute whose arguments come next, as in `__attribute__((packed))` and `__aligned(8)`
  ATTRIBUTE_CALL = /(?:__attribute__|__attribute|__aligned)(?![\w$])\s*(?=\()/ unless const_defined?(:ATTRIBUTE_CALL, false)

  # Extracts a typedef from its keyword through the ';' that ends it. Called as a feature
  # extractor by CExtractor#extract_next_feature. A ';' inside a struct, union or enum body, a
  # literal or a comment doesn't end it. Comments in the text become a single space, and
  # literals stay as written.
  #
  # @param scanner [StringScanner] positioned at the start of a potential typedef
  # @return [Array(Boolean, String)]
  #   [true,  "typedef struct { int x; } Point;"]   the typedef's text
  #   [false, nil                               ]   no typedef here, or no ';' before the text ends
  def try_extract_typedef(scanner)
    return [false, nil] unless scanner.check(/typedef\b/)

    text  = +''
    depth = 0

    until scanner.eos?
      token  = _take_token( scanner, text )
      depth += BRACE_DEPTH.fetch( token, 0 )
      return [true, _finish( scanner, text )] if depth.zero? and token == ';'
    end

    [false, nil]
  end

  # Extracts a file-scope struct, enum or union type definition that has no typedef. Called as
  # a feature extractor by CExtractor#extract_next_feature.
  #
  # The same keyword can lead a variable or a function. A variable's initializer and a
  # function's body are braced too, so the text ahead of the first '{' must head a type (see
  # _type_head?). Only a ';' may follow the closing '}', perhaps after extensions, comments and
  # line breaks, which the text keeps as written. Comments in the head and the body become a
  # single space, and literals stay as written.
  #
  # Extracts:
  #   struct [attributes] [tag] { member-list } [extensions];
  #   enum   [attributes] [tag] [: type] { enumerator-list } [extensions];
  #   union  [attributes] [tag] { member-list } [extensions];
  #
  # Declines, leaving the scanner where it was, so a later extractor reads the statement:
  #   struct ops g = { 1 };              a variable with an initializer
  #   struct ops *make(void) { ... };    a function
  #   struct ops { int a; } g;           a type with a variable
  #   struct ops;                        a forward declaration
  #
  # @param scanner [StringScanner] positioned at a potential aggregate definition
  # @return [Array(Boolean, String|nil)]
  #   [true,  "struct Foo { int x; };"]   the definition's text
  #   [false, nil                     ]   no type definition here, or the text ends first. The scanner doesn't move.
  def try_extract_aggregate_definition(scanner)
    return [false, nil] unless scanner.check(/(?:struct|enum|union)\b/)

    start_pos   = scanner.pos
    text        = _aggregate_text( scanner )
    scanner.pos = start_pos if text.nil?
    return [!text.nil?, text]
  end

  private

  # The type definition's text, or nil when the statement defines no type or the text ends first
  def _aggregate_text(scanner)
    text  = +''
    depth = 0

    until scanner.eos?
      token = _take_token( scanner, text )
      return nil if depth.zero? and _not_a_type_body?( token, text )

      depth += BRACE_DEPTH.fetch( token, 0 )
      return _type_end( scanner, text ) if token == '}' and depth.zero?
    end

    return nil
  end

  # Whether a token outside any body ends the search for a type's body. A ';' first means a
  # declaration without one. A '{' that opens a variable's initializer or a function's body
  # means the statement defines no type.
  def _not_a_type_body?(token, text)
    return true if token == ';'

    return (token == '{' and !_type_head?( text.chop ))
  end

  # Whether the text ahead of a body's '{' heads a type. A type's head never holds an '=' or a
  # star outside its groups, as a variable's initializer and a pointer-returning function do.
  # Nor does it end in `(void)` or a group around a pointer, as a function's head can. Any other
  # group ending the head may belong to a macro spelling the tag, as in `struct FOO_TYPE(bar) {`,
  # so the head stays a type's. A function with other parameters then reads as a type only when
  # a stray ';' follows its body. Groups are emptied first, so nothing inside one counts.
  def _type_head?(head)
    flat = head.match?( /[(\[]/ ) ? _empty_groups( head ) : head
    return !(flat.match?( /[=*]/ ) or flat.match?( /\(p\)\s*\z/ ))
  end

  # The head with each top-level group reduced to a stand-in, so `struct ops make(void)` reads
  # `struct ops make()`. A bracket inside a literal or a comment doesn't count.
  def _empty_groups(head)
    scanner = StringScanner.new( head )
    flat    = +''
    while (before = scanner.scan_until( /(?=[(\[])/ ))
      flat << before
      emptied = _emptied_group( scanner )
      break if emptied.nil?

      flat << emptied
    end

    return flat << scanner.rest
  end

  # What stands for the group at the scanner, once the scanner has passed it, or nil when the
  # group never closes. A group only a function's head ends with reads `(p)`, and any other `()`.
  def _emptied_group(scanner)
    from = scanner.pos
    return nil unless CExtractorDeclarator._skip_balanced( scanner )

    return scanner.string.byteslice( from, scanner.pos - from ).match?( FUNCTION_GROUP ) ? '(p)' : '()'
  end

  # The definition's text through its ';', or nil. Extensions, comments and line breaks may sit
  # between the body's '}' and the ';', and the text keeps them as written. Anything else there
  # is a declarator, or the text ends first.
  def _type_end(scanner, text)
    after = scanner.pos
    return nil unless _skip_type_extensions( scanner ) and scanner.scan( /;/ )

    text << scanner.string.byteslice( after, scanner.pos - after )
    return _finish( scanner, text )
  end

  # A statement's text, once the scanner has passed the blanks and the line break after it
  def _finish(scanner, text)
    scanner.scan(/[ \t]*\n/)
    return text.rstrip
  end

  # Passes whitespace, comments and extensions after a type's body, or says false when an
  # attribute's arguments never close. An extension is a word C reserves for the implementation,
  # such as the common `__packed` macro, or an attribute with its arguments. A module's own
  # variable may not legally take such a name. Any other reserved word with arguments, such as
  # `__asm__("...")`, begins a statement of its own.
  def _skip_type_extensions(scanner)
    loop do
      @c_extractor_code_text.skip_deadspace( scanner )
      next if scanner.skip( BARE_EXTENSION )
      return true unless scanner.skip( ATTRIBUTE_CALL )
      return false unless CExtractorDeclarator._skip_balanced( scanner )
    end
  end

  # Moves the scanner past one token of a statement and appends it to `text`. A literal is one
  # token and a comment becomes a space, so neither can end the statement or change its depth.
  # A run of plain text is one token as well, so the scan doesn't step one character at a time.
  def _take_token(scanner, text)
    return _next_token( scanner ).tap { |token| text << token }
  end

  def _next_token(scanner)
    quote = scanner.peek( 1 )
    return _literal( scanner, quote ) if quote == '"' or quote == "'"
    return scanner.scan( PLAIN_RUN ) || scanner.getch unless scanner.check( %r{/[/*]} )

    @c_extractor_code_text.skip_comment( scanner )
    return ' '
  end

  # The scanner's positions count bytes, so the literal is sliced by bytes too
  def _literal(scanner, quote)
    before = scanner.pos
    @c_extractor_code_text.skip_c_string( scanner, quote )
    return scanner.string.byteslice( before, scanner.pos - before )
  end

end
