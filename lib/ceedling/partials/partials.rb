# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'set'
require 'strscan'
require 'ceedling/c_extractor/c_extractor_constants'
require 'ceedling/c_extractor/c_extractor_declarator'
require 'ceedling/partials/carry_plan'

module Partials
  # Constants
  PUBLIC     = :public     unless const_defined?(:PUBLIC)
  PRIVATE    = :private    unless const_defined?(:PRIVATE)
  ACCUMULATE = :accumulate unless const_defined?(:ACCUMULATE)
  DEDUCT     = :deduct     unless const_defined?(:DEDUCT)

  TEST_PUBLIC  = :test_public   unless const_defined?(:TEST_PUBLIC)
  TEST_PRIVATE = :test_private  unless const_defined?(:TEST_PRIVATE)
  MOCK_PUBLIC  = :mock_public   unless const_defined?(:MOCK_PUBLIC)
  MOCK_PRIVATE = :mock_private  unless const_defined?(:MOCK_PRIVATE)

  # A string or character literal, or a comment. One pattern finds both, so whichever starts
  # first wins, as it does for the compiler.
  LITERAL_OR_COMMENT = %r{"(?:\\.|[^"\\\n])*"|'(?:\\.|[^'\\\n])*'|/\*.*?\*/|//[^\n]*}m unless const_defined?(:LITERAL_OR_COMMENT)

  # Space between a statement's tokens in a function's code block. Under fallback preprocessing
  # it may hold a comment where the function's comment-blanked body holds a space.
  STATEMENT_GAP = %r{(?:\s|/\*.*?\*/|//[^\n]*)+}m unless const_defined?(:STATEMENT_GAP)

  # Data class representing a source or header file to be partialized
  ConfigFileInfo = Struct.new(:filepath, :directives_only_filepath, :full_expansion_filepath, :includes, keyword_init: true) do
    def initialize(filepath: nil, directives_only_filepath: nil, full_expansion_filepath: nil, includes: [])
      super
    end
  end unless const_defined?(:ConfigFileInfo, false)

  # Data class representing a C function signature
  FunctionDeclaration = Struct.new(
    :name,            # Function name (e.g., "foo")
    :return_type,     # Return type (e.g., "int")
    :signature,       # FunctionDefinition signature (e.g., "int foo(void)")
    :source_filepath, # Path to source file
    :line_num,        # Line number in source file
    keyword_init: true
  ) do
    # Constructor to set unassigned fields to nil for convenience
    def initialize(name: nil, signature: nil, source_filepath: nil, line_num: nil)
      super
    end
  end unless const_defined?(:FunctionDeclaration, false)

  # Data class representing a C function with intentionally duplicated fields
  FunctionDefinition = Struct.new(
    :name,            # Function name (e.g., "foo")
    :signature,       # FunctionDefinition signature (e.g., "int foo(void)")
    :code_block,      # Complete function text (signature + body)
    :source_filepath, # Path to source file
    :line_num,        # Line number in source file
    keyword_init: true
  ) do
    # Constructor to set unassigned fields to nil for convenience
    def initialize(name: nil, signature: nil, code_block: nil, source_filepath: nil, line_num: nil)
      super
    end
  end unless const_defined?(:FunctionDefinition, false)

  # The text with its first copy of `statement` replaced by what the block returns, or the text
  # as it was. The statement is read from a function's body, whose comments are blanked to
  # spaces. The text usually holds it exactly, and a plain search finds that copy fastest. Under
  # fallback preprocessing the text may keep a comment inside the statement, so then each gap
  # between its tokens matches whitespace and comments alike.
  def self.replace_statement(text, statement, &replacement)
    return text.sub( statement, &replacement ) if text.include?( statement )

    found = _statement_pattern( statement ).match( text )
    return found ? found.pre_match + yield + found.post_match : text
  end

  # The statement with any whitespace or comments between its tokens
  def self._statement_pattern(statement)
    tokens = statement.strip.split( /\s+/ ).map { |part| Regexp.escape( part ) }
    return Regexp.new( tokens.join( STATEMENT_GAP.source ), Regexp::MULTILINE )
  end

  # The type a variable holds by value, less a keyword ahead of it that changes only how it's
  # stored or accessed, as `_Thread_local` and `_Atomic` do
  def self.named_type(var)
    return var.type.to_s.sub( /\A(?:(?:_Thread_local|thread_local|__thread|_Atomic)\s+)+/, '' )
  end

  # A `static` function is private to its file
  def self.static?(decorators)
    return decorators.include?( 'static' )
  end

  # Any inline specifier. `static` only narrows linkage, so it doesn't count.
  def self.inline?(decorators)
    return decorators.any? { |d| d != 'static' and CExtractorConstants::PRIVATE_KEYWORDS.include?( d ) }
  end

  # A declaration of an inline function whose body another header holds. Under C99 a file
  # declaring such a function `extern`, or without `inline`, holds its external definition.
  # A declaration marked `inline` counts too, the body being nowhere else.
  def self.foreign_inline?(decl)
    return (inline?( decl.decorators ) or decl.inline_elsewhere) ? true : false
  end

  def self.manufacture_function_declaration(line_num: nil, source_filepath: nil, name:, signature:)
    return FunctionDeclaration.new(
      name: name,
      signature: signature,
      source_filepath: source_filepath,
      line_num: line_num
    )
  end

  def self.manufacture_function_definition(line_num: nil, source_filepath: nil, name:, signature:, code_block:)
    return FunctionDefinition.new(
      name: name,
      signature: signature,
      code_block: code_block,
      source_filepath: source_filepath,
      line_num: line_num
    )
  end
  # How promotion renames a function's statics in C text. A rename reads the text one token at a
  # time, so literals, comments, member access and tags keep their spelling.
  module Rename

    # An asm statement up through its template strings, whose operand references such as
    # `%[count]` must follow the operand names they refer to
    ASM_TEMPLATE = /(?<![\w$])(?:__asm__|__asm|asm)(?:\s+(?:volatile|__volatile__|__volatile|inline|__inline__|goto))*\s*\(\s*"(?:\\.|[^"\\\n])*"(?:\s*"(?:\\.|[^"\\\n])*")*/ unless const_defined?(:ASM_TEMPLATE)

    # The keyword that opens an asm statement
    ASM_START = /\A(?:__asm__|__asm|asm)(?![\w$])/ unless const_defined?(:ASM_START)

    # A struct or union keyword, any tag and attributes, and the '{' that opens its body. Each word
    # is read whole and nothing is read twice, so the match takes linear time.
    BODY_HEAD = /(?<![\w$])(?:struct|union)(?![\w$])\s*(?:(?>(?:__attribute__|__attribute|__declspec)\s*(?<group>\((?>[^()]+|\g<group>)*\))|[A-Za-z_$][\w$]*+)\s*)*+\{/ unless const_defined?(:BODY_HEAD)

    # A member after '.' or '->', or a tag after struct, union or enum. Each lives apart from
    # variables.
    MEMBER_OR_TAG = /(?:\.|->)\s*[A-Za-z_$][\w$]*|(?<![\w$])(?:struct|union|enum)\s+[A-Za-z_$][\w$]*/ unless const_defined?(:MEMBER_OR_TAG)

    # The start of a member or tag token
    MEMBER_OR_TAG_START = /\A(?:(?:\.|->)\s*[A-Za-z_$]|(?:struct|union|enum)\s)/ unless const_defined?(:MEMBER_OR_TAG_START)

    # A number, read whole, since a C23 digit separator, as in `1'000`, would otherwise open a
    # character literal
    NUMBER = /(?<![\w$])\.?\d(?:[\w$.]|[eEpP][+-]|'(?=[\w$]))*/ unless const_defined?(:NUMBER)

    # How a rename reads text, one token at a time. Only an identifier is renamed, so first come
    # the tokens that hold one without naming a variable.
    TOKEN = Regexp.union( ASM_TEMPLATE, MEMBER_OR_TAG, NUMBER, LITERAL_OR_COMMENT, CExtractorConstants::IDENTIFIER ) unless const_defined?(:TOKEN)

    # An asm template's reference to a named operand, as in `%[count]` or `%w[count]`
    ASM_OPERAND_REFERENCE = /%[A-Za-z]*\[\K[A-Za-z_$][\w$]*(?=\])/ unless const_defined?(:ASM_OPERAND_REFERENCE)

    # The text with each identifier `renames` maps replaced, in one pass whatever the number of
    # names. Literals and comments stay as written, and so do member access and tags. A name a
    # local struct or union body holds is renamed in member access and tags too (see
    # _names_in_bodies). The exception is an asm template's operand references, which must follow
    # the operand names they refer to.
    def self.identifiers(text, renames)
      shared = _names_in_bodies( text, renames )
      return text.gsub( TOKEN ) do |token|
        next token.sub( /[A-Za-z_$][\w$]*\z/ ) { |name| shared.include?( name ) ? renames[name] : name } if token.match?( MEMBER_OR_TAG_START )
        next renames.fetch( token, token ) unless token.end_with?( '"' )
        next token unless token.match?( ASM_START )

        token.gsub( ASM_OPERAND_REFERENCE ) { |name| renames.fetch( name, name ) }
      end
    end

    # The names `renames` maps that a struct or union body in the text holds, as a member or in
    # use. Such a body is local to the function, so its members and their uses take the new name
    # alike, wherever they sit.
    def self._names_in_bodies(text, renames)
      names = Set.new
      text.scan( BODY_HEAD ) do
        body = _body_after( text, Regexp.last_match )
        body&.gsub( LITERAL_OR_COMMENT, ' ' )&.scan( CExtractorConstants::IDENTIFIER ) { |name| names << name if renames.key?( name ) }
      end
      return names
    end

    # The body whose '{' ends the match, or nil when its braces don't balance
    def self._body_after(text, match)
      scanner = StringScanner.new( text )
      scanner.pos = match.pre_match.bytesize + match[0].bytesize - 1
      start = scanner.pos
      return CExtractorDeclarator._skip_balanced( scanner ) ? text.byteslice( start, scanner.pos - start ) : nil
    end

  end

end