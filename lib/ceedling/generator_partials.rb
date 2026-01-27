# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/file_wrapper'
require 'ceedling/partials'

class GeneratorPartials

  constructor :file_wrapper, :file_path_utils

  def generate_implementation(definitions:, name:, includes:, output_path:)
    source = @file_path_utils.form_partial_implementation_source_filename(name)
    header = @file_path_utils.form_partial_implementation_header_filename(name)

    header_filepath = File.join(output_path, header)
    source_filepath = File.join(output_path, source)

    # Ensure no include of the original module header
    includes.delete_if { |include| include.ext() == name }

    @file_wrapper.open(header_filepath, 'w') do |file|
      generate_header(file, header, [], definitions)
    end

    @file_wrapper.open(source_filepath, 'w') do |file|
      generate_source(file, includes, definitions)
    end

    return source_filepath
  end

  def generate_interface(declarations:, name:, includes:, output_path:)
    header = @file_path_utils.form_partial_interface_header_filename(name)
    filepath = File.join(output_path, header)

    puts(includes)

    # Ensure no include of the header we're generating
    includes.delete_if { |include| include == header }

    @file_wrapper.open(filepath, 'w') do |file|
      generate_header(file, header, includes, declarations)
    end

    return filepath
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