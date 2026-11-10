# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
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
  end unless const_defined?(:CStatement, false)

  # Data class representing all extracted content of C module
  CModule = Struct.new(
    :variable_declarations, # Array of CVariableDeclaration structs (each with :line_num)
    :function_definitions,  # Array of CFunctionDefinition structs (each with :line_num)
    :function_declarations, # Array of CFunctionDeclaration structs (each with :line_num)
    :macro_definitions,     # Array of CStatement — raw #define text with source line number
    :type_definitions,      # Array of CStatement — raw typedef text with source line number
    :aggregate_definitions, # Array of CStatement — raw non-typedef struct/enum/union text with source line number
    :macro_invocations,     # Array of CStatement — raw bare, top-level, semicolon-less macro-invocation text (e.g. an x-macro call) with source line number
    :element_sequence,      # Array of references to all items above in extraction order (cross-type ordering index)
    keyword_init: true
  ) do
    # Constructor to set unassigned fields to empty arrays for convenience
    def initialize(variable_declarations: [], function_definitions: [], function_declarations: [], macro_definitions: [],
                   type_definitions: [], aggregate_definitions: [], macro_invocations: [], element_sequence: [])
      super
    end

    # Concatenate two CModule instances.
    # element_sequence keeps the first operand's items ahead of the second operand's items.
    # Partials merges a header and then its source, so header items come first.
    def +(other)
      CModule.new(
        variable_declarations: (self.variable_declarations + other.variable_declarations),
        function_definitions:  (self.function_definitions  + other.function_definitions),
        function_declarations: (self.function_declarations + other.function_declarations),
        macro_definitions:     (self.macro_definitions     + other.macro_definitions),
        type_definitions:      (self.type_definitions      + other.type_definitions),
        aggregate_definitions: (self.aggregate_definitions + other.aggregate_definitions),
        macro_invocations:     (self.macro_invocations     + other.macro_invocations),
        element_sequence:      (self.element_sequence      + other.element_sequence)
      )
    end

    # Records which file of a module each function came from.
    # CExtractor reads text alone and cannot know a file's role, so the caller stamps it.
    # element_sequence references these same objects and so reflects the stamp too.
    def stamp_origin!(origin)
      (function_definitions + function_declarations).each { |item| item.origin = origin }
      return self
    end
  end unless const_defined?(:CModule, false)

  # Data class representing an extracted C function declaration
  CFunctionDeclaration = Struct.new(
    :name,               # Function name (e.g., "foo")
    :signature,          # Full signature with decorators (e.g., "static int foo(void);")
    :decorators,         # Array of decorator strings (e.g., ["static"])
    :signature_stripped, # Signature without decorators (e.g., "int foo(void);")
    :line_num,           # Integer — 1-based line number in source file where declaration begins
    :source_filepath,    # Original file the declaration was located in, when a caller locates it
    :origin,             # :header or :source when the caller knows the file's role, otherwise nil
    :inline_elsewhere,   # True when the module never defines the function and a header the declaring file includes defines it inline
    keyword_init: true
  ) do
    def initialize(name: nil, signature: nil, decorators: [], signature_stripped: nil, line_num: nil, source_filepath: nil, origin: nil, inline_elsewhere: false)
      super
    end
  end unless const_defined?(:CFunctionDeclaration, false)

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
    :origin,             # :header or :source when the caller knows the file's role, otherwise nil
    :expanded_body,      # Body with every macro expanded, taken from the full expansion copy when one exists
    keyword_init: true
  ) do
    # Constructor to set unassigned fields to nil for convenience
    def initialize(name: nil, signature: nil, body: nil, code_block: nil, line_count: 0, source_filepath: nil,
                   line_num: nil, decorators: [], signature_stripped: nil, origin: nil, expanded_body: nil)
      super
    end
  end unless const_defined?(:CFunctionDefinition, false)

  # Struct representing a single parsed C variable declaration
  CVariableDeclaration = Struct.new(
    :original,      # Full original C text (e.g., "static int x, y;") -- shared by all Structs
                    # created from a single compound declaration.
    :name,          # Variable name (e.g., "x") -- array subscripts stripped
    :type,          # Type without decorator keywords (e.g., "int", "char*") -- array subscripts stripped.
                    # With a declarator, only the text ahead of it (e.g., "int" for "int (*hook)(int)").
    :array_suffix,  # Array subscript string (e.g., "[8]", "[M][N]", "" for scalars). "" with a
                    # declarator, which keeps any subscripts itself.
    :decorators,    # Array of decorator keyword strings (e.g., ["static", "const"])
    :text,          # Cleaned declaration without decorators, whitespace normalized (e.g., "int x;")
    :line_num,      # Integer — 1-based line number in source file where declaration begins
    :declarator,    # A parenthesized declarator from its '(' onward (e.g., "(*hook)(int)" after type "int"), or nil
    :asm_label,     # An asm label naming the symbol (e.g., '__asm__("g_symbol")'), or nil. :text and :original hold it too.
                    # A file-scope basic asm statement, such as `asm(".globl x");`, has no name and holds itself here.
    keyword_init: true
  ) do
    def initialize(original: nil, name: nil, type: nil, array_suffix: '', decorators: [], text: nil, line_num: nil, declarator: nil,
                   asm_label: nil)
      super
    end

    # A variable declared `extern` lives in another file, which holds its definition
    def extern?
      return decorators.include?( 'extern' )
    end
  end unless const_defined?(:CVariableDeclaration, false)

end
