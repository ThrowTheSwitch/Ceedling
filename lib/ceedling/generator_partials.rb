# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/file_wrapper'
require 'ceedling/partials/partials'

class GeneratorPartials

  constructor :file_wrapper, :file_path_utils

  def generate_implementation(
      name:, 
      definitions:,
      source_includes:,
      header_includes:,
      header_variables:,
      source_variables:,
      output_path:
    )
    source = @file_path_utils.form_partial_implementation_source_filename(name)
    header = @file_path_utils.form_partial_implementation_header_filename(name)

    header_filepath = File.join(output_path, header)
    source_filepath = File.join(output_path, source)

    @file_wrapper.open(header_filepath, 'w') do |file|
      generate_header(file, header, header_includes, definitions, header_variables)
    end

    @file_wrapper.open(source_filepath, 'w') do |file|
      generate_source(file, source_includes, definitions, source_variables)
    end

    return source_filepath
  end

  def generate_interface(declarations:, name:, includes:, output_path:)
    header = @file_path_utils.form_partial_interface_header_filename(name)
    filepath = File.join(output_path, header)

    @file_wrapper.open(filepath, 'w') do |file|
      generate_header(file, header, includes, declarations, [])
    end

    return filepath
  end

  private

  def generate_header(io, name, includes, declarations, variable_declarations)
    guard = FileWrapper.generate_include_guard( name )

    io << "// Ceeding generated file\n"
    io << "#ifndef #{guard}\n"
    io << "#define #{guard}\n\n"

    includes.each do |include|
      io << "#{include}\n"  
    end

    io << "\n" if !includes.empty?

    variable_declarations.each do |line|
      io << "#{line}\n"
    end

    io << "\n" if !variable_declarations.empty?

    declarations.each do |decl|
      io << decl.signature
      io << ";\n\n"
    end

    io << "#endif // #{guard}\n\n"
  end

  def generate_source(io, includes, definitions, variable_declarations)
    io << "// Ceeding generated file\n"
    includes.each do |include|
      io << "#{include}\n"
    end

    io << "\n"

    variable_declarations.each do |decl|
      io << decl + "\n"
    end

    io << "\n" if !variable_declarations.empty?

    definitions.each do |defn|
      if defn.line_num and defn.source_filepath
        io << "#line #{defn.line_num} \"#{defn.source_filepath}\"\n"
      end

      io << cleanup_function( defn.code_block )
      io << "\n\n"
    end
  end

  private

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