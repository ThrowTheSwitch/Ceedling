# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

module CExtractorTypes

  # Pairs a raw C statement string with its 1-based source line number.
  # Used for macro_definitions, type_definitions, and aggregate_definitions in CModule.
  CStatement = Struct.new(
    :text,     # String  — raw extracted statement text (comments replaced with spaces)
    :line_num, # Integer — 1-based line number where the statement begins in the source file
    keyword_init: true
  ) do
    def initialize(text: nil, line_num: nil)
      super
    end
  end

  # Data class representing all extracted content of C module
  CModule = Struct.new(
    :variable_declarations, # Array of CVariableDeclaration structs (each with :line_num)
    :function_definitions,  # Array of CFunctionDefinition structs (each with :line_num)
    :function_declarations, # Array of CFunctionDeclaration structs (each with :line_num)
    :macro_definitions,     # Array of CStatement — raw #define text with source line number
    :type_definitions,      # Array of CStatement — raw typedef text with source line number
    :aggregate_definitions, # Array of CStatement — raw non-typedef struct/enum/union text with source line number
    :element_sequence,      # Array of references to all items above in extraction order (cross-type ordering index)
    keyword_init: true
  ) do
    # Constructor to set unassigned fields to empty arrays for convenience
    def initialize(
        variable_declarations: [],
        function_definitions: [],
        function_declarations: [],
        macro_definitions: [],
        type_definitions: [],
        aggregate_definitions: [],
        element_sequence: []
      )
      super
    end

    # Concatenate two CModule instances.
    # element_sequence preserves first operand's items before second operand's items,
    # maintaining source-before-header ordering regardless of line numbers.
    def +(other)
      CModule.new(
        variable_declarations: (self.variable_declarations + other.variable_declarations),
        function_definitions:  (self.function_definitions  + other.function_definitions),
        function_declarations: (self.function_declarations + other.function_declarations),
        macro_definitions:     (self.macro_definitions     + other.macro_definitions),
        type_definitions:      (self.type_definitions      + other.type_definitions),
        aggregate_definitions: (self.aggregate_definitions + other.aggregate_definitions),
        element_sequence:      (self.element_sequence      + other.element_sequence)
      )
    end
  end

  # Data class representing an extracted C function declaration
  CFunctionDeclaration = Struct.new(
    :name,               # Function name (e.g., "foo")
    :signature,          # Full signature with decorators (e.g., "static int foo(void);")
    :decorators,         # Array of decorator strings (e.g., ["static"])
    :signature_stripped, # Signature without decorators (e.g., "int foo(void);")
    :line_num,           # Integer — 1-based line number in source file where declaration begins
    keyword_init: true
  ) do
    def initialize(name: nil, signature: nil, decorators: [], signature_stripped: nil, line_num: nil)
      super
    end
  end

  # Data class representing an extracted C function definition
  CFunctionDefinition = Struct.new(
    :name,               # Function name only (e.g., "foo")
    :signature,          # Function signature (e.g., "int foo(void)")
    :body,               # Function body including containing braces
    :code_block,         # Complete function text (signature + body)
    :line_count,         # Total number of lines in code_block
    :source_filepath,    # Source C filepath
    :line_num,           # Line number in source C file
    :decorators,         # Array of decorator strings (e.g., ["static"])
    :signature_stripped, # Signature without decorators (e.g., "int foo(void)")
    keyword_init: true
  ) do
    # Constructor to set unassigned fields to nil for convenience
    def initialize(
      name: nil,
      signature: nil,
      body: nil,
      code_block: nil,
      line_count: 0,
      source_filepath: nil,
      line_num: nil,
      decorators: [],
      signature_stripped: nil
      )
      super
    end
  end

  # Struct representing a single parsed C variable declaration
  CVariableDeclaration = Struct.new(
    :original,      # Full original C text (e.g., "static int x, y;") -- shared by all Structs
                    # created from a single compound declaration.
    :name,          # Variable name (e.g., "x") -- array subscripts stripped
    :type,          # Type without decorator keywords (e.g., "int", "char*") -- array subscripts stripped
    :array_suffix,  # Array subscript string (e.g., "[8]", "[M][N]", "" for scalars)
    :decorators,    # Array of decorator keyword strings (e.g., ["static", "const"])
    :text,          # Cleaned declaration without decorators, whitespace normalized (e.g., "int x;")
    :line_num,      # Integer — 1-based line number in source file where declaration begins
    keyword_init: true
  ) do
    def initialize(original: nil, name: nil, type: nil, array_suffix: '', decorators: [], text: nil, line_num: nil)
      super
    end
  end

end
