# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/file_wrapper'
require 'ceedling/partials/partials'
require 'ceedling/c_extractor/c_extractor_types'

class GeneratorPartials

  constructor :file_wrapper, :file_path_utils, :loginator

  def generate_implementation(
      test:,
      name:,
      function_definitions:,
      source_includes:,
      header_includes:,
      c_statements:,
      output_path:
    )
    source = @file_path_utils.form_partial_implementation_source_filename(name)
    header = @file_path_utils.form_partial_implementation_header_filename(name)

    header_filepath = File.join(output_path, header)
    source_filepath = File.join(output_path, source)

    @file_wrapper.open(header_filepath, 'w') do |file|
      generate_header(file, header, header_includes, function_definitions, c_statements)
    end

    @file_wrapper.open(source_filepath, 'w') do |file|
      generate_source(file, source_includes, function_definitions, c_statements)
    end

    return source_filepath
  end

  def generate_interface(test:, name:, function_declarations:, includes:, c_statements:, output_path:)
    header = @file_path_utils.form_partial_interface_header_filename(name)
    filepath = File.join(output_path, header)

    @file_wrapper.open(filepath, 'w') do |file|
      generate_header(file, header, includes, function_declarations, c_statements)
    end

    return filepath
  end

  private

  def generate_header(io, name, includes, function_declarations, c_statements)
    guard = FileWrapper.generate_include_guard( name )

    io << "// Ceeding generated file\n"
    io << "#ifndef #{guard}\n"
    io << "#define #{guard}\n\n"

    includes.each do |include|
      io << "#{include}\n"
    end

    io << "\n" if !includes.empty?

    sorted = sort_by_line_num(c_statements)
    sorted.each do |item|
      if item.is_a?(CExtractorTypes::CStatement)
        # Macro, typedef, or aggregate definition — emit text as-is
        io << item.text.chomp
        io << "\n"
      else
        # CVariableDeclaration — emit extern declaration
        io << "extern #{item.type} #{item.name};\n"
      end
    end

    io << "\n" if !c_statements.empty?

    function_declarations.each do |decl|
      io << decl.signature
      io << ";\n\n"
    end

    io << "#endif // #{guard}\n\n"
  end

  def generate_source(io, includes, function_definitions, c_statements)
    io << "// Ceeding generated file\n"
    includes.each do |include|
      io << "#{include}\n"
    end

    io << "\n"

    # Only CVariableDeclaration items belong in the source file
    var_decls = c_statements.select { |item| item.is_a?(CExtractorTypes::CVariableDeclaration) }
    var_decls.each do |var|
      io << "#{var.text}\n"
    end

    io << "\n" if !var_decls.empty?

    function_definitions.each do |defn|
      if defn.line_num and defn.source_filepath
        io << "#line #{defn.line_num} \"#{defn.source_filepath}\"\n"
      end

      io << cleanup_function( defn.code_block )
      io << "\n\n"
    end
  end

  def sort_by_line_num(collection)
    with_num    = collection.select { |item| item.line_num }
    without_num = collection.reject { |item| item.line_num }
    with_num.sort_by { |item| item.line_num } + without_num
  end

  def cleanup_function(code_block)
    # Collapse any unnecessary newlines between closing paren and opening function bracket
    _code_block = code_block.gsub( /\)(\n){2,}\{/, ")\n{" )
    # Collapse any unnecessary newlines between opening function bracket and code
    _code_block.gsub!( /\{(\n){2,}/, "{\n" )
    # Collapse any unnecessary newlines between code and closing function bracket
    _code_block.gsub!( /(\n){2,}\}/, "\n}" )
    # Collapse repeated blank lines
    _code_block.gsub!( /(\h*\n){3,}/, "\n\n" )

    return _code_block
  end

end
