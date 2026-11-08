# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'strscan'
require 'ceedling/c_extractor/c_extractor_constants'

# Reads the parenthesized declarator a C declaration may have, as in `int (*hook)(int)`.
#
# The declared name sits inside that group, past pointer stars and qualifiers. What follows the
# name decides what the declaration declares. A parameter list makes it a function, even one
# returning a function pointer. Anything else makes it an object, such as a pointer to a function
# or to an array. A plain declaration has no such group, and each caller reads it its own way.
# Every scan here is a single forward pass, so a declaration's cost stays linear.
module CExtractorDeclarator

  # A declaration's parenthesized declarator. `follows` is the '(' or '[' right after the name,
  # or nil. `base_type` is the text ahead of the group, and `declarator` the group onward.
  Parenthesized = Struct.new( :name, :follows, :base_type, :declarator, keyword_init: true ) unless const_defined?(:Parenthesized, false)

  # A calling convention, which may come ahead of a group's star
  CALLING_CONVENTION = /(?:#{CExtractorConstants::MSVC_CALLING_CONVENTIONS.join( '|' )})\b/ unless const_defined?(:CALLING_CONVENTION, false)

  # A '(' opening a declarator, perhaps through redundant parentheses and a calling convention
  POINTER_GROUP = /\([\s(]*(?:#{CALLING_CONVENTION}\s*)*\*/ unless const_defined?(:POINTER_GROUP, false)

  # A nested pointer group. After a word, a '(' that opens one is no parameter list.
  NESTED_GROUP = /\(\s*(?:#{CALLING_CONVENTION}\s*)*\*/ unless const_defined?(:NESTED_GROUP, false)

  # Words that qualify a pointer ahead of the name, including ones a compiler adds. A '(' after
  # one of these still opens a redundant group, as in `(* const (name))`.
  QUALIFIERS = (CExtractorConstants::TYPE_QUALIFIER_KEYWORDS + CExtractorConstants::MSVC_CALLING_CONVENTIONS +
    %w[__restrict __restrict__ _Nullable _Nonnull _Null_unspecified __far __near __huge __ptr32 __ptr64 __unaligned]).freeze unless const_defined?(:QUALIFIERS, false)

  # An identifier, which GCC lets hold '$'
  WORD = /[A-Za-z_$][\w$]*/ unless const_defined?(:WORD, false)

  # Space between a group's tokens. Fallback preprocessing leaves comments in place.
  GAP = %r{(?:\s|/\*.*?\*/|//[^\n]*)*}m unless const_defined?(:GAP, false)

  # An attribute after a declarator. An extern leaves it out, since some draw a warning there.
  ATTRIBUTE = /(?:__attribute__|__declspec)\s*(?=\()/ unless const_defined?(:ATTRIBUTE, false)

  # Declarator text up to the next group, bracket or attribute
  PLAIN_TEXT = /(?:(?!__attribute__|__declspec)[^(\[])+/ unless const_defined?(:PLAIN_TEXT, false)

  # A bracket, or a literal or comment whose brackets don't count toward a group's balance
  BALANCE_TOKEN = %r{[()\[\]{}]|"(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'|/\*.*?\*/|//[^\n]*}m unless const_defined?(:BALANCE_TOKEN, false)

  # Where a walk through a declarator group stands. That is the name read so far, and how many
  # '(' have passed since the last star. Those only group the name, and close right after it.
  GroupWalk = Struct.new( :name, :opens ) unless const_defined?(:GroupWalk, false)

  # What may follow a declarator's name. That is the group's own ')', a parameter list or an
  # array size.
  NAME_ENDS = [')', '(', '['].freeze unless const_defined?(:NAME_ENDS, false)

  # How each delimiter changes the nesting depth
  DEPTH_CHANGE = { '(' => 1, '[' => 1, '{' => 1, ')' => -1, ']' => -1, '}' => -1 }.freeze unless const_defined?(:DEPTH_CHANGE, false)

  # The declaration's parenthesized declarator, or nil when it has none. The text has no
  # initializer (see without_initializer). Words and attributes ahead of the group are passed
  # over like the type, and end up in the base type. A group whose name ends any other way,
  # such as at the ',' of a macro's arguments, is no declarator.
  def self.parenthesized(text)
    text  = text.sub( /\s*;\s*\z/, '' )
    start = _group_start( text )
    return nil if start.nil?

    name, ending = _name_in( text, start )
    return nil unless NAME_ENDS.include?( ending )

    return Parenthesized.new( name: name, follows: (ending == ')' ? nil : ending),
                              base_type: text.byteslice( 0, start ).strip, declarator: _declarator_text( text, start ) )
  end

  # The declaration up to any initializer, less its semicolon. Only an '=' outside brackets,
  # parentheses and braces starts one.
  def self.without_initializer(text)
    scanner = StringScanner.new( text )
    depth   = 0
    while scanner.skip_until( /[=()\[\]{}]/ )
      depth += DEPTH_CHANGE.fetch( scanner.matched, 0 )
      return text.byteslice( 0, scanner.pos - 1 ).rstrip if scanner.matched == '=' and depth.zero?
    end

    return text.sub( /\s*;\s*\z/, '' )
  end

  # Where the declarator group opens. That is the first top-level '(' whose next token is a '*',
  # perhaps after a calling convention. Any other group is a parameter list or a macro's
  # arguments, a bracket holds an array size, and a brace holds a struct's members, so each is
  # passed over whole.
  def self._group_start(text)
    scanner = StringScanner.new( text )
    while scanner.skip_until( /[(\[{]/ )
      open = scanner.pos - 1
      scanner.pos = open
      return open if scanner.match?( POINTER_GROUP )
      return nil unless _skip_balanced( scanner )
    end

    return nil
  end

  # Moves the scanner past the group, bracket or brace it sits at. A bracket in a string, a
  # character literal or a comment doesn't count. False when the text ends first.
  def self._skip_balanced(scanner)
    depth = 0
    while scanner.skip_until( BALANCE_TOKEN )
      depth += DEPTH_CHANGE.fetch( scanner.matched, 0 )
      return true if depth.zero?
    end

    return false
  end

  # The name inside the group at `start`, with the character that ends it. The name is the last
  # word ahead of that end that isn't a qualifier. A star or '(' ahead of the name clears any word
  # read so far, since a qualifier the list lacks may come before the name. Parentheses around the
  # name close before its end is read. After the name, a '(' opens a parameter list unless a
  # nested pointer group starts there.
  def self._name_in(text, start)
    scanner = StringScanner.new( text )
    scanner.pos = start + 1
    walk = GroupWalk.new( nil, 0 )

    while (step = _next_in_group( scanner, walk.name ))
      _take_step( walk, step )
    end

    return [walk.name, _name_end( scanner, walk.opens )]
  end

  # Moves the scanner past the next token in a group and says what it was. That is :star, :group
  # for a '(' passed through, or the word read. It is nil at anything else, which ends the name.
  def self._next_in_group(scanner, name)
    scanner.skip( GAP )
    return :star if scanner.skip( /\*/ )
    return scanner.scan( WORD ) unless scanner.check( /\(/ ) and (name.nil? or scanner.match?( NESTED_GROUP ))

    scanner.pos += 1
    return :group
  end

  # Records one step of the walk. A qualifier changes nothing. A star clears the name and the '('
  # counted, and a '(' clears the name and counts one more.
  def self._take_step(walk, step)
    return if QUALIFIERS.include?( step )

    walk.opens = (step == :star) ? 0 : walk.opens + 1 unless step.is_a?( String )
    walk.name  = step.is_a?( String ) ? step : nil
  end

  # What ends the name. A ')' closing a parenthesis that only groups the name is passed, and the
  # first character past those decides, as in `(*(get)(void))` and `(*(get(void)))` alike.
  def self._name_end(scanner, opens)
    loop do
      scanner.skip( GAP )
      return scanner.peek( 1 ) unless scanner.check( /\)/ ) and opens.positive?

      scanner.pos += 1
      opens -= 1
    end
  end

  # The declarator's text, from its group's '(' to its end, less any attribute outside its
  # groups and brackets. An extern repeats this text, needs no attribute, and some draw a warning
  # there. An asm label names the symbol, so it stays, and so does anything else.
  def self._declarator_text(text, start)
    scanner = StringScanner.new( text )
    scanner.pos = start
    kept = text.byteslice( start, 0 )

    until scanner.eos?
      piece = _declarator_piece( scanner )
      return text.byteslice( start, text.bytesize - start ).strip if piece.nil?

      kept << piece
    end

    # Declaration text holds single spaces, and an attribute left out leaves two together
    return kept.squeeze( ' ' ).strip
  end

  # The next piece of a declarator's text. That is a whole group or bracket, other text, or ''
  # for an attribute left out. Nil when a group never closes.
  def self._declarator_piece(scanner)
    from = scanner.pos
    return (_skip_balanced( scanner ) ? '' : nil) if scanner.skip( ATTRIBUTE )
    return scanner.scan( PLAIN_TEXT ) || scanner.getch unless scanner.check( /[(\[]/ )
    return _skip_balanced( scanner ) ? scanner.string.byteslice( from, scanner.pos - from ) : nil
  end

end
