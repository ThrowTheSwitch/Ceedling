# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/file_wrapper'
require 'ceedling/partials/partials'
require 'ceedling/c_extractor/c_extractor_types'
require 'ceedling/c_extractor/c_extractor_constants'

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

    # Binary mode: the function bodies written below may already contain their
    # own line endings verbatim. Windows text mode rewrites every "\n" on
    # write, which would alter any line ending already present in that
    # content instead of passing it through unchanged.
    @file_wrapper.open(header_filepath, 'wb') do |file|
      generate_header(file, header, header_includes, function_definitions, c_module, true)
    end

    @file_wrapper.open(source_filepath, 'wb') do |file|
      generate_source(file, source_includes, function_definitions, c_module)
    end

    return source_filepath
  end

  def generate_interface(test:, name:, function_declarations:, includes:, c_module:, output_path:)
    header = @file_path_utils.form_partial_interface_header_filename(name)
    filepath = File.join(output_path, header)

    # Binary mode: see generate_implementation above.
    @file_wrapper.open(filepath, 'wb') do |file|
      generate_header(file, header, includes, function_declarations, c_module, false)
    end

    return filepath
  end

  # A module's typedefs and aggregate (struct/enum/union) definitions are the same
  # regardless of which functions a given test file chooses to test versus mock, so they're
  # generated once here into their own header rather than by generate_header itself. Both
  # the implementation and interface headers then simply #include this file, which means a
  # module tested and mocked in the same test file -- each side producing its own generated
  # header -- never ends up with two separate C definitions of the same type in one
  # translation unit. Nothing is written and nil is returned when a module has no such
  # content, since there's then nothing to share.
  #
  # @param name     [String] Partial module name (used to form the filename and include guard)
  # @param c_module [CExtractorTypes::CModule] Merged module with type_definitions/aggregate_definitions
  # @param output_path [String] Directory shared with the implementation and interface headers
  # @return [String, nil] The bare filename (for use as a sibling #include), or nil if nothing was generated
  def generate_types(name:, c_module:, output_path:)
    return nil if c_module.type_definitions.empty? && c_module.aggregate_definitions.empty?

    header = @file_path_utils.form_partial_types_header_filename(name)
    filepath = File.join(output_path, header)

    # Binary mode: see generate_implementation above.
    @file_wrapper.open(filepath, 'wb') do |file|
      guard = FileWrapper.generate_include_guard(header)
      file << "#ifndef #{guard}\n"
      file << "#define #{guard}\n\n"

      anything_emitted = false
      c_module.element_sequence.each do |item|
        next unless item.is_a?(CExtractorTypes::CStatement) && type_defining?(item, c_module)
        file << item.text << "\n"
        anything_emitted = true
      end

      file << "\n" if anything_emitted
      file << "#endif // #{guard}\n\n"
    end

    return header
  end

  private

  # A typedef or a non-typedef struct/enum/union tag definition establishes a type; C treats
  # a second definition of the same type in one translation unit as a redefinition error even
  # when the two definitions are textually identical. A macro statement carries no such
  # restriction -- an identical #define may legally repeat -- so only membership in
  # type_definitions or aggregate_definitions marks a CStatement as type-defining content
  # that belongs in the shared types header instead of being emitted inline.
  def type_defining?(item, c_module)
    c_module.type_definitions.include?(item) || c_module.aggregate_definitions.include?(item)
  end

  # A `CVariableDeclaration`'s `decorators` mixes storage-class specifiers (`static`,
  # `extern`) with base-type qualifiers (`const`, `volatile`, `restrict`) in their
  # original source order, since both kinds of keyword lead a declaration the same
  # way. An `extern` declaration and the variable's own definition both need the
  # qualifiers reasserted -- omitting them produces a type that disagrees with any
  # other declaration of the same variable elsewhere in the same translation unit --
  # but neither may carry a storage-class specifier: `static` would contradict the
  # external linkage the Partial is establishing, and `extern` is supplied literally
  # by the caller. Filtering to TYPE_QUALIFIER_KEYWORDS keeps only what belongs on
  # both forms.
  #
  # @param decl [CExtractorTypes::CVariableDeclaration]
  # @return [String] e.g. "volatile " / "const volatile " / "" (trailing space when non-empty)
  def qualifier_prefix(decl)
    quals = decl.decorators.select { |kw| CExtractorConstants::TYPE_QUALIFIER_KEYWORDS.include?(kw) }
    quals.empty? ? '' : "#{quals.join(' ')} "
  end

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
        # Typedefs and aggregate definitions live in the shared types header generated by
        # generate_types instead of here, so that content defines a type exactly once no
        # matter how many of a module's generated headers end up in the same test file.
        next if type_defining?(item, c_module)
        io << item.text << "\n"
        last_was_func = false
        anything_emitted = true
      when CExtractorTypes::CVariableDeclaration
        next unless include_variables
        # If there is no array involved, array_suffix collapses to an empty string.
        # A leading const/volatile/restrict on the original declaration (see
        # qualifier_prefix) is part of the variable's type and belongs here too,
        # so this extern agrees with the definition and any other declaration of
        # the same variable elsewhere in the translation unit.
        io << "extern #{qualifier_prefix(item)}#{item.type} #{item.name}#{item.array_suffix};\n"
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
        # #line ties this generated file's code back to its original source
        # location -- debuggers, error messages, and gcov coverage attribution
        # all point at the real file/line instead of this generated stand-in.
        # That mapping only holds if this file's line count matches what
        # #line promises, which is why it's opened in binary mode above.
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
        # `item.text` is the declaration with its leading decorator run removed (see
        # CExtractorDeclarations#extract_decorators), so a const/volatile/restrict
        # qualifier on the base type is reapplied here via qualifier_prefix -- this
        # definition's type must match the extern declaration emitted for the same
        # variable in generate_header.
        io << "#{qualifier_prefix(item)}#{item.text}\n"
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
