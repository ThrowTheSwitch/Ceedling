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

  # A type specifier ending the text ahead of a group, whose argument the group holds
  SPECIFIER_AHEAD = /(?<![\w$])(?:#{CExtractorConstants::SPECIFIERS_WITH_ARGUMENTS.join( '|' )})\s*\z/ unless const_defined?(:SPECIFIER_AHEAD, false)

  # A nested pointer group. After a word, a '(' that opens one is no parameter list.
  NESTED_GROUP = /\(\s*(?:#{CALLING_CONVENTION}\s*)*\*/ unless const_defined?(:NESTED_GROUP, false)

  # Words that qualify a pointer ahead of the name, including ones a compiler adds. A '(' after
  # one of these still opens a redundant group, as in `(* const (name))`.
  QUALIFIERS = (CExtractorConstants::TYPE_QUALIFIER_KEYWORDS + CExtractorConstants::MSVC_CALLING_CONVENTIONS +
    %w[__restrict __restrict__ _Nullable _Nonnull _Null_unspecified __far __near __huge __ptr32 __ptr64 __unaligned]).freeze unless const_defined?(:QUALIFIERS, false)

  # An identifier, which GCC and Clang let hold '$'
  WORD = CExtractorConstants::IDENTIFIER unless const_defined?(:WORD, false)

  # Space between a group's tokens. Fallback preprocessing leaves comments in place.
  GAP = %r{(?:\s|/\*.*?\*/|//[^\n]*)*}m unless const_defined?(:GAP, false)

  # A string or character literal, or a comment. What looks like code inside one isn't. A literal
  # may run past a line's end here, as CExtractorCodeText#skip_c_string reads one, so blanking
  # comments and passing literals agree on where each ends.
  LITERAL_OR_COMMENT = %r{"(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'|/\*.*?\*/|//[^\n]*}m unless const_defined?(:LITERAL_OR_COMMENT, false)

  # A bracket, or a literal or comment whose brackets don't count toward a group's balance
  BALANCE_TOKEN = Regexp.union( /[()\[\]{}]/, LITERAL_OR_COMMENT ) unless const_defined?(:BALANCE_TOKEN, false)

  # A balance token, or the '=' that may start an initializer
  INITIALIZER_TOKEN = Regexp.union( /=/, BALANCE_TOKEN ) unless const_defined?(:INITIALIZER_TOKEN, false)

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
                              base_type: text.byteslice( 0, start ).strip, declarator: Extent.text( text, start ) )
  end

  # The declaration up to any initializer, less its semicolon. Only an '=' outside brackets,
  # parentheses and braces starts one, and a bracket in a comment or literal doesn't count.
  def self.without_initializer(text)
    scanner = StringScanner.new( text )
    depth   = 0
    while scanner.skip_until( INITIALIZER_TOKEN )
      depth += DEPTH_CHANGE.fetch( scanner.matched, 0 )
      return text.byteslice( 0, scanner.pos - 1 ).rstrip if scanner.matched == '=' and depth.zero?
    end

    return text.sub( /\s*;\s*\z/, '' )
  end

  # Where the declarator group opens. That is the first top-level '(' whose next token is a '*',
  # perhaps after a calling convention. Any other group is a parameter list or a macro's
  # arguments, a bracket holds an array size, and a brace holds a struct's members, so each is
  # passed over whole. So is a type specifier's argument, as in `typeof(*p)`.
  def self._group_start(text)
    scanner = StringScanner.new( text )
    while scanner.skip_until( /[(\[{]/ )
      open = scanner.pos - 1
      scanner.pos = open
      return open if scanner.match?( POINTER_GROUP ) and !_specifier_argument?( text, open )
      return nil unless _skip_balanced( scanner )
    end

    return nil
  end

  # Whether the group at `open` follows a specifier. Only the few bytes ahead of it are read,
  # which the longest specifier and its space fit in. Every caller collapses whitespace and
  # blanks or removes comments first, so nothing longer sits between the two.
  def self._specifier_argument?(text, open)
    from = [open - 24, 0].max
    return text.byteslice( from, open - from ).scrub( '' ).match?( SPECIFIER_AHEAD )
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

  # Where a declarator's text ends. An extern repeats the text, from the group's '(' through its
  # last suffix. What follows the last suffix is left out. An extern needs no attribute or macro
  # there, and some draw a warning. An asm label there is read apart (see AsmLabel).
  module Extent

    # Words, such as a macro, that may sit ahead of an array size among a declarator's suffixes
    SUFFIX_WORDS = /(?:#{WORD}#{GAP})+/ unless const_defined?(:SUFFIX_WORDS, false)

    # The declarator's text from its group's '(' at `start`
    def self.text(text, start)
      scanner = StringScanner.new( text )
      scanner.pos = start
      return text.byteslice( start, text.bytesize - start ).strip unless CExtractorDeclarator._skip_balanced( scanner )

      finish = _suffixes_end( scanner )
      return text.byteslice( start, finish - start ).strip
    end

    # Where the last of a declarator's parameter lists and array sizes ends, read from the scanner
    # just past the group. A word may sit ahead of an array size, but a word ahead of a '(' makes
    # a macro call, an attribute or an asm label, which ends the suffixes.
    def self._suffixes_end(scanner)
      finish = scanner.pos
      loop do
        scanner.skip( GAP )
        opening = scanner.skip( SUFFIX_WORDS ) ? /\[/ : /[(\[]/
        break unless scanner.check( opening ) and CExtractorDeclarator._skip_balanced( scanner )

        finish = scanner.pos
      end

      return finish
    end

  end

  # An asm label, as in `int g __asm__("sym") = 1;`, which names the symbol a declaration's
  # object or function takes. A compiler applies it to the declarations it sees, so a test's own
  # declaration must carry it too. A record keeps the label apart from the name and type it
  # reads. Only a label outside brackets and ahead of any initializer counts.
  module AsmLabel

    # A run of word characters read whole, among which a label's keyword may be, or an
    # initializer token. A number is read whole too, so no keyword is found inside one.
    TOKEN = Regexp.union( INITIALIZER_TOKEN, /[\w$]+/ ) unless const_defined?(:TOKEN, false)

    # The keywords that open a label
    KEYWORDS = %w[asm __asm __asm__].freeze unless const_defined?(:KEYWORDS, false)

    # What follows a label's keyword, up to the '(' of its string
    OPEN = /#{GAP}\(/ unless const_defined?(:OPEN, false)

    # The first label as written, such as `__asm__("sym")`, or nil
    def self.of(text)
      range = _ranges( text ).first
      return range && text.byteslice( range.begin, range.size )
    end

    # The declaration without its labels ahead of any initializer. A compound declaration may hold
    # one per declarator. The space around a label collapses to one, or to none ahead of a
    # semicolon or comma.
    def self.without(text)
      ranges = _ranges( text )
      return text if ranges.empty?

      cuts = [0, *ranges.flat_map { |range| [range.begin, range.end] }, text.bytesize]
      return cuts.each_slice( 2 ).map { |from, to| text.byteslice( from, to - from ) }.reduce { |kept, piece| _joined( kept, piece ) }
    end

    # Two pieces of text a label sat between, with the space between them collapsed
    def self._joined(before, after)
      before = before.rstrip
      after  = after.lstrip
      return (after.empty? or after.start_with?( ';', ',' )) ? "#{before}#{after}" : "#{before} #{after}"
    end

    # Where each label sits, from its keyword through its ')'. The walk stops at an initializer.
    def self._ranges(text)
      scanner = StringScanner.new( text )
      depth   = 0
      ranges  = []
      while scanner.skip_until( TOKEN ) and !(scanner.matched == '=' and depth.zero?)
        token  = scanner.matched
        depth += DEPTH_CHANGE.fetch( token, 0 )
        from   = scanner.pos - token.bytesize
        ranges << (from...scanner.pos) if _opens?( scanner, token, depth )
      end

      return ranges
    end

    # Whether the token just read opens a label outside brackets. On true, the scanner has passed
    # the label's ')'.
    def self._opens?(scanner, token, depth)
      return false unless depth.zero? and KEYWORDS.include?( token ) and scanner.match?( OPEN )

      scanner.skip( GAP )
      return CExtractorDeclarator._skip_balanced( scanner )
    end

  end

end
