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

  CALLING_CONVENTION = /(?:#{CExtractorConstants::MSVC_CALLING_CONVENTIONS.join( '|' )})\b/ unless const_defined?(:CALLING_CONVENTION, false)

  # A '(' opening a declarator, perhaps through redundant parentheses and a calling convention
  POINTER_GROUP = /\([\s(]*(?:#{CALLING_CONVENTION}\s*)*\*/ unless const_defined?(:POINTER_GROUP, false)

  # A '(' after a word that opens a nested pointer group rather than a parameter list
  NESTED_GROUP = /\(\s*(?:#{CALLING_CONVENTION}\s*)*\*/ unless const_defined?(:NESTED_GROUP, false)

  # Words that qualify a pointer ahead of the name, including ones a compiler adds. A '(' after
  # one of these still opens a redundant group, as in `(* const (name))`.
  QUALIFIERS = (
    CExtractorConstants::TYPE_QUALIFIER_KEYWORDS + CExtractorConstants::MSVC_CALLING_CONVENTIONS +
    %w[__restrict __restrict__ _Nullable _Nonnull _Null_unspecified __far __near __huge __ptr32 __ptr64 __unaligned]
  ).freeze unless const_defined?(:QUALIFIERS, false)

  # An identifier, which GCC lets hold '$'
  WORD = /[A-Za-z_$][\w$]*/ unless const_defined?(:WORD, false)

  # Space between a group's tokens. Fallback preprocessing leaves comments in place.
  GAP = %r{(?:\s|/\*.*?\*/|//[^\n]*)*}m unless const_defined?(:GAP, false)

  # An asm label after a declarator, which names the symbol and so must match the definition's
  ASM_LABEL = /\s*(?:__asm__|__asm|asm)\s*(?=\()/ unless const_defined?(:ASM_LABEL, false)

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

    return Parenthesized.new(
      name: name, follows: (ending == ')' ? nil : ending),
      base_type: text.byteslice( 0, start ).strip, declarator: _declarator_text( text, start )
    )
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

  # Moves the scanner past the group, bracket or brace it sits at. False when the text ends first.
  def self._skip_balanced(scanner)
    depth = 0
    while scanner.skip_until( /[()\[\]{}]/ )
      depth += DEPTH_CHANGE[scanner.matched]
      return true if depth.zero?
    end

    return false
  end

  # The name inside the group at `start`, with the character that ends it. The name is the last
  # word ahead of that end that isn't a qualifier. A star or '(' ahead of the name clears any word
  # read so far, since a qualifier the list lacks may come before the name. After the name, a '('
  # opens a parameter list unless a nested pointer group starts there.
  def self._name_in(text, start)
    scanner = StringScanner.new( text )
    scanner.pos = start + 1
    name = nil

    while (step = _next_in_group( scanner, name ))
      next if QUALIFIERS.include?( step )

      name = (step == :open) ? nil : step
    end

    return [name, scanner.peek( 1 )]
  end

  # Moves the scanner past the next token in a group and says what it was. That is :open for a
  # star or a '(' passed through, or the word read. It is nil at anything else, which ends the name.
  def self._next_in_group(scanner, name)
    scanner.skip( GAP )
    return :open if scanner.skip( /\*/ )
    return scanner.scan( WORD ) unless scanner.check( /\(/ ) and (name.nil? or scanner.match?( NESTED_GROUP ))

    scanner.pos += 1
    return :open
  end

  # The declarator's text, from its group's '(' through its last parameter list or array size,
  # with any asm label after it. An extern repeats this text. An attribute after it is left out,
  # since an extern needs none and some draw a warning there.
  def self._declarator_text(text, start)
    scanner = StringScanner.new( text )
    scanner.pos = start
    while scanner.match?( /\s*[(\[]/ )
      scanner.skip( /\s*/ )
      return text.byteslice( start, text.bytesize - start ).strip unless _skip_balanced( scanner )
    end

    finish = scanner.pos
    finish = scanner.pos if scanner.skip( ASM_LABEL ) and _skip_balanced( scanner )
    return text.byteslice( start, finish - start ).strip
  end

end
