# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================


module Partials
  # Constants
  TEST_PUBLIC  = :test_public   unless const_defined?(:TEST_PUBLIC)
  TEST_PRIVATE = :test_private  unless const_defined?(:TEST_PRIVATE)
  MOCK_PUBLIC  = :mock_public   unless const_defined?(:MOCK_PUBLIC)
  MOCK_PRIVATE = :mock_private  unless const_defined?(:MOCK_PRIVATE)

  # Data class representing a source or header file to be partialized
  ConfigFileInfo = Struct.new(:filepath, :preprocessed_filepath, :includes, keyword_init: true) do
    def initialize(filepath: nil, preprocessed_filepath: nil, includes: [])
      super
    end
  end

  # Data class representing a C partial to be generated
  Config = Struct.new(:module, :types, :header, :source, keyword_init: true) do
    def initialize(module:, types: [], header: ConfigFileInfo.new, source: ConfigFileInfo.new)
      super
    end
  end

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
  end

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
  end

  def self.manufacture_config(module_name:)
    return Config.new(module: module_name)
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