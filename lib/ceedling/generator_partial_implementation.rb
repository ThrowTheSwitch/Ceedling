# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'

class GeneratorPartialImplementation

  # Data class representing a C function
  Function = Struct.new(
    :signature,       # Function signature (e.g., "int foo(void)")
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

  constructor :file_wrapper

  def manufacture_function_struct(line_num:, source_filepath:, signature:, code_block:)
    return Function.new(
      signature: signature,
      code_block: code_block,
      source_filepath: source_filepath,
      line_num: line_num
    )
  end

  def generate(functions:, name:, includes:, path:)
    _module = PARTIAL_FILENAME_PREFIX + name + "_impl"
    header = _module + EXTENSION_CORE_HEADER

    header_filepath = File.join(path, header)
    source_filepath = File.join(path, _module + EXTENSION_CORE_SOURCE)

    @file_wrapper.open(header_filepath, 'w') do |file|
      generate_header(file, _module, functions)
    end

    @file_wrapper.open(source_filepath, 'w') do |file|
      generate_source(file, ([header] + includes), functions)
    end
  end

  def generate_source(io, headers, functions)
    io << "// Ceeding generated file\n\n"
    headers.each do |header|
      io << "#include \"#{header}\"\n"  
    end

    io << "\n"

    functions.each do |function|
      if function.line_num
        io << "#line #{function.line_num} \"#{function.source_filepath}\"\n"
      end

      io << function.code_block
      io << "\n\n"
    end
  end

end