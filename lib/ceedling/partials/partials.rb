# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/c_extractor/c_extractor_constants'
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

  # How a rename reads text, one token at a time. Only an identifier is renamed, so first come
  # the tokens that hold one without naming a variable. A member after '.' or '->' and a tag
  # after struct, union or enum live apart from variables. A number is read whole, since a C23
  # digit separator, as in `1'000`, would otherwise open a character literal.
  RENAME_TOKEN = Regexp.union(
    /(?:\.|->)\s*[A-Za-z_$][\w$]*|(?<![\w$])(?:struct|union|enum)\s+[A-Za-z_$][\w$]*/,
    /(?<![\w$])\.?\d(?:[\w$.]|[eEpP][+-]|'(?=[\w$]))*/,
    LITERAL_OR_COMMENT,
    /[A-Za-z_$][\w$]*/
  ) unless const_defined?(:RENAME_TOKEN)

  # An asm template's reference to a named operand, as in `%[count]` or `%w[count]`
  ASM_OPERAND_REFERENCE = /%[A-Za-z]*\[\K[A-Za-z_$][\w$]*(?=\])/ unless const_defined?(:ASM_OPERAND_REFERENCE)

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

  # A `static` function is private to its file
  # The text with each identifier `renames` maps replaced, in one pass whatever the number of
  # names. Literals and comments stay as written. The exception is an asm template's operand
  # references, which must follow the operand names they refer to.
  def self.rename_identifiers(text, renames)
    return text.gsub( RENAME_TOKEN ) do |token|
      next renames.fetch( token, token ) unless token.start_with?( '"' )

      token.gsub( ASM_OPERAND_REFERENCE ) { |name| renames.fetch( name, name ) }
    end
  end

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
end