# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'strscan'
require 'ceedling/c_extractor/c_extractor_constants'
require 'ceedling/c_extractor/c_extractor_declarator'

# Reads a struct, union or enum that a declaration defines ahead of its declarators, as in
# `static struct pair { int a; } g_p1, g_p2;`. Such a statement holds two things. The type is
# defined once, and each variable names it. Separating them lets every variable be read like
# any other, and lets a type be written once wherever a module's types go.
#
# Every scan here is a single forward pass over text whose comments are already blanked.
module CExtractorDefinedType

  # A declaration split at the type it defines. `type` runs from the keyword through the body's
  # '}' and any extensions after it, which belong to the type. `tag` is the type's tag, or nil.
  # `declarators` is the declaration with the type taken out.
  Split = Struct.new( :type, :tag, :declarators, keyword_init: true ) unless const_defined?(:Split, false)

  KEYWORD = /(?:struct|union|enum)(?![\w$])/ unless const_defined?(:KEYWORD, false)

  # A token in a type's head. A group or a bracket is passed whole. A '{' opens the body, and any
  # other token here means the declaration names a type without defining one.
  HEAD_TOKEN = Regexp.union( /[{(\[;=*,]/, CExtractorDeclarator::LITERAL_OR_COMMENT ) unless const_defined?(:HEAD_TOKEN, false)

  # A head's words once its groups are gone, the tag last. A word C reserves for the
  # implementation is an extension, and an enum's `: type` names no tag.
  TAG = /\A(?:\s*__[\w$]*)*\s*(?<tag>#{CExtractorConstants::IDENTIFIER.source})?(?:\s*__[\w$]*)*\s*(?::.*)?\z/m unless const_defined?(:TAG, false)

  # A typedef's one name, once its type is taken out
  TYPEDEF_NAME = /\Atypedef\s+(?<name>#{CExtractorConstants::IDENTIFIER.source})\s*;\s*\z/ unless const_defined?(:TYPEDEF_NAME, false)

  # A statement naming a tag without a body, perhaps giving it one typedef name
  BODILESS = /\A(?:typedef\s+)?(?:struct|union|enum)\s+(?<tag>#{CExtractorConstants::IDENTIFIER.source})(?:\s+(?<name>#{CExtractorConstants::IDENTIFIER.source}))?\s*;\s*\z/ unless const_defined?(:BODILESS, false)

  # The tag a type statement names and the one name a typedef gives it, each nil where absent.
  # A typedef declaring several names, or a pointer, gives the type no one name.
  #   struct node { int v; };                  tag node
  #   typedef struct node { int v; } node_t;   tag node, type_name node_t
  #   typedef struct node node_t;              tag node, type_name node_t
  def self.names(text)
    split = split( text, text[/\Atypedef\s+/].to_s.bytesize )
    return { tag: split.tag, type_name: split.declarators[TYPEDEF_NAME, :name] } if split

    found = text.match( BODILESS )
    return { tag: found && found[:tag], type_name: found && found[:name] }
  end

  # The declaration split at the type it defines, or nil when it defines none. `from` is where
  # the type's keyword may start, past the declaration's leading run of decorators and attributes.
  def self.split(text, from)
    scanner = StringScanner.new( text )
    scanner.pos = from
    return nil unless scanner.skip( KEYWORD )

    head = _head( scanner )
    return nil unless head and CExtractorDeclarator._skip_balanced( scanner )

    _skip_extensions( scanner )
    return Split.new(
      type: text.byteslice( from, scanner.pos - from ).strip, tag: head[TAG, :tag],
      declarators: "#{text.byteslice( 0, from )}#{scanner.rest}"
    )
  end

  # The type's head between its keyword and its body, with each group taken out, or nil when
  # no body follows. The scanner stops at the body's '{'. A group straight after a word means a
  # macro spells the tag, as in `struct FOO_TYPE(bar) {`, so the head names no tag of its own.
  def self._head(scanner)
    head = +''
    while (before = scanner.scan_until( HEAD_TOKEN ))
      head << before.delete_suffix( scanner.matched )
      return _body_at( scanner, head ) if scanner.matched == '{'
      return nil unless scanner.matched.start_with?( '(', '[' )

      head = +'(' if head.match?( /[A-Za-z0-9_$]\s*\z/ ) and !head.match?( /(?<![\w$])__[\w$]*\s*\z/ )
      return nil unless _skip_group( scanner )
    end

    return nil
  end

  # The head, with the scanner moved back onto the body's '{'
  def self._body_at(scanner, head)
    scanner.pos -= 1
    return head
  end

  # Moves the scanner, just past a group's opening, past its close. False when it never closes.
  def self._skip_group(scanner)
    scanner.pos -= 1
    return CExtractorDeclarator._skip_balanced( scanner )
  end

  # Moves the scanner past the extensions after a type's body, such as `__attribute__((packed))`
  # or `__packed`, and the space around them. A group that never closes ends the extensions.
  def self._skip_extensions(scanner)
    loop do
      scanner.skip( /\s*/ )
      next if scanner.skip( CExtractorConstants::BARE_EXTENSION )
      break unless scanner.skip( CExtractorConstants::ATTRIBUTE_CALL ) or scanner.check( /\[\s*\[/ )
      break unless CExtractorDeclarator._skip_balanced( scanner )
    end
  end

end
