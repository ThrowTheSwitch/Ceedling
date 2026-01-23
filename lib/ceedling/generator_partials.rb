# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/file_wrapper'

class GeneratorPartials

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

  constructor :file_wrapper, :file_path_utils

  def manufacture_function_declaration_struct(line_num: nil, source_filepath: nil, signature:)
    return FunctionDeclaration.new(
      signature: signature,
      source_filepath: source_filepath,
      line_num: line_num
    )
  end

  def manufacture_function_definition_struct(line_num: nil, source_filepath: nil, signature:, code_block:)
    return FunctionDefinition.new(
      signature: signature,
      code_block: code_block,
      source_filepath: source_filepath,
      line_num: line_num
    )
  end

  def generate_implementation(definitions:, name:, includes:, output_path:)
    source = @file_path_utils.form_partial_implementation_source_filename(name)
    header = @file_path_utils.form_partial_implementation_header_filename(name)

    header_filepath = File.join(output_path, header)
    source_filepath = File.join(output_path, source)

    @file_wrapper.open(header_filepath, 'w') do |file|
      generate_header(file, header, includes, definitions)
    end

    @file_wrapper.open(source_filepath, 'w') do |file|
      generate_source(file, ([header] + includes), definitions)
    end
  end

  def generate_interface(declarations:, name:, includes:, output_path:)
    header = @file_path_utils.form_partial_interface_header_filename(name)
    filepath = File.join(output_path, header)

    @file_wrapper.open(filepath, 'w') do |file|
      generate_header(file, header, includes, declarations)
    end
  end

  # Publicly exposed for testing
  def generate_header(io, name, headers, declarations)
    guard = FileWrapper.generate_include_guard( name )

    io << "// Ceeding generated file\n"
    io << "#ifndef #{guard}\n"
    io << "#define #{guard}\n\n"

    headers.each do |header|
      io << "#include \"#{header}\"\n"  
    end

    io << "\n"

    declarations.each do |decl|
      io << decl.signature
      io << ";\n\n"
    end

    io << "#endif // #{guard}\n\n"
  end

  # Publicly exposed for testing
  def generate_source(io, headers, definitions)
    io << "// Ceeding generated file\n\n"
    headers.each do |header|
      io << "#include \"#{header}\"\n"  
    end

    io << "\n"

    definitions.each do |defn|
      if defn.line_num and defn.source_filepath
        io << "#line #{defn.line_num} \"#{defn.source_filepath}\"\n"
      end

      io << defn.code_block
      io << "\n\n"
    end
  end

end