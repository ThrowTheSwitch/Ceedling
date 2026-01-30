# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

module Partials
  # Data class representing a C function signature
  FunctionDeclaration = Struct.new(
    :signature,       # FunctionDefinition signature (e.g., "int foo(void)")
    :source_filepath, # Path to source file
    :line_num,        # Line number in source file
    keyword_init: true
  ) do
    # Constructor to set unassigned fields to nil for convenience
    def initialize(signature: nil, source_filepath: nil, line_num: nil)
      super
    end
  end

  # Data class representing a C function with intentionally duplicated fields
  FunctionDefinition = Struct.new(
    :signature,       # FunctionDefinition signature (e.g., "int foo(void)")
    :code_block,      # Complete function text (signature + body)
    :source_filepath, # Path to source file
    :line_num,        # Line number in source file
    keyword_init: true
  ) do
    # Constructor to set unassigned fields to nil for convenience
    def initialize(signature: nil, code_block: nil, source_filepath: nil, line_num: nil)
      super
    end
  end

  def self.manufacture_function_declaration_struct(line_num: nil, source_filepath: nil, signature:)
    return FunctionDeclaration.new(
      signature: signature,
      source_filepath: source_filepath,
      line_num: line_num
    )
  end

  def self.manufacture_function_definition_struct(line_num: nil, source_filepath: nil, signature:, code_block:)
    return FunctionDefinition.new(
      signature: signature,
      code_block: code_block,
      source_filepath: source_filepath,
      line_num: line_num
    )
  end
end