# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
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
      c_module:,
      output_path:
    )
    source = @file_path_utils.form_partial_implementation_source_filename(name)
    header = @file_path_utils.form_partial_implementation_header_filename(name)

    header_filepath = File.join(output_path, header)
    source_filepath = File.join(output_path, source)

    @file_wrapper.open(header_filepath, 'w') do |file|
      generate_header(file, header, header_includes, function_definitions, c_module, true)
    end

    @file_wrapper.open(source_filepath, 'w') do |file|
      generate_source(file, source_includes, function_definitions, c_module)
    end

    return source_filepath
  end

  def generate_interface(test:, name:, function_declarations:, includes:, c_module:, output_path:)
    header = @file_path_utils.form_partial_interface_header_filename(name)
    filepath = File.join(output_path, header)

    @file_wrapper.open(filepath, 'w') do |file|
      generate_header(file, header, includes, function_declarations, c_module, false)
    end

    return filepath
  end

  private

  # Emit a partial header file.
  #
  # Iterates c_module.element_sequence to emit non-function items (macros, typedefs,
  # aggregates, and optionally variable extern declarations) in their original extraction
  # order. Function items in element_sequence are matched by name against function_list
  # (pre-filtered Partials::FunctionDeclaration or Partials::FunctionDefinition objects)
  # and emitted at their natural position. Any function_list entries not found in
  # element_sequence (e.g., added from a different module) are emitted afterward.
  #
  # @param io              [IO]     Output file handle
  # @param name            [String] Header filename (used for include guard)
  # @param includes        [Array]  Include directives
  # @param function_list   [Array]  Pre-filtered Partials function objects (respond to :name and :signature)
  # @param c_module        [CExtractorTypes::CModule] Merged module with element_sequence
  # @param include_variables [Boolean] True for implementation header (emits extern vars); false for interface
  def generate_header(io, name, includes, function_list, c_module, include_variables)
    guard = FileWrapper.generate_include_guard( name )

    io << "#ifndef #{guard}\n"
    io << "#define #{guard}\n\n"

    includes.each do |include|
      io << "#{include}\n"
    end

    io << "\n" if !includes.empty?

    func_by_name = function_list.to_h { |f| [f.name, f] }
    emitted_funcs = {}
    last_was_func = false
    anything_emitted = false

    emit_func = lambda do |func|
      # Blank line before a function when preceded by a non-function item
      io << "\n" if anything_emitted && !last_was_func
      io << func.signature << ";\n\n"
      emitted_funcs[func.name] = true
      last_was_func = true
      anything_emitted = true
    end

    c_module.element_sequence.each do |item|
      case item
      when CExtractorTypes::CStatement
        io << item.text << "\n"
        last_was_func = false
        anything_emitted = true
      when CExtractorTypes::CVariableDeclaration
        next unless include_variables
        # If there is no array involved, array_suffix collapses to an empty string
        io << "extern #{item.type} #{item.name}#{item.array_suffix};\n"
        last_was_func = false
        anything_emitted = true
      when CExtractorTypes::CFunctionDefinition, CExtractorTypes::CFunctionDeclaration
        func = func_by_name[item.name]
        next unless func && !emitted_funcs[item.name]
        emit_func.call(func)
      end
    end

    # Non-function items end with \n; add one more for a blank line before #endif.
    # Function items already end with \n\n, so no extra newline needed.
    io << "\n" if anything_emitted && !last_was_func

    io << "#endif // #{guard}\n\n"
  end

  # Emit a partial source file.
  #
  # Iterates c_module.element_sequence to emit CVariableDeclaration and
  # CFunctionDefinition items in their original extraction order. CStatement and
  # CFunctionDeclaration items are skipped (they belong in headers). Function items
  # are matched by name against function_definitions (pre-filtered
  # Partials::FunctionDefinition objects). Any entries not found in element_sequence
  # are emitted afterward.
  #
  # @param io                   [IO]     Output file handle
  # @param includes             [Array]  Include directives
  # @param function_definitions [Array]  Pre-filtered Partials::FunctionDefinition objects
  # @param c_module             [CExtractorTypes::CModule] Merged module with element_sequence
  def generate_source(io, includes, function_definitions, c_module)
    io << "// Ceeding generated file\n"
    includes.each do |include|
      io << "#{include}\n"
    end

    io << "\n"

    func_by_name = function_definitions.to_h { |f| [f.name, f] }
    emitted_funcs = {}
    last_was_func = false
    anything_emitted = false

    emit_func = lambda do |func|
      # Blank line before a function when preceded by a non-function item
      io << "\n" if anything_emitted && !last_was_func
      if func.line_num and func.source_filepath
        io << "#line #{func.line_num} \"#{func.source_filepath}\"\n"
      end
      io << func.code_block << "\n\n"
      emitted_funcs[func.name] = true
      last_was_func = true
      anything_emitted = true
    end

    c_module.element_sequence.each do |item|
      case item
      when CExtractorTypes::CVariableDeclaration
        io << "#{item.text}\n"
        last_was_func = false
        anything_emitted = true
      when CExtractorTypes::CFunctionDefinition
        func = func_by_name[item.name]
        next unless func && !emitted_funcs[item.name]
        emit_func.call(func)
      end
      # CStatement and CFunctionDeclaration items are skipped in source
    end

  end


end
