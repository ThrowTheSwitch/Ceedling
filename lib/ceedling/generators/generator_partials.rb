# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'set'
require 'ceedling/filesystem/file_wrapper'
require 'ceedling/partials/partials'
require 'ceedling/c_extractor/c_extractor_types'
require 'ceedling/c_extractor/c_extractor_constants'
require 'ceedling/generators/partial_source_writer'
require 'ceedling/generators/partial_header_writer'

class GeneratorPartials

  constructor :file_wrapper, :file_path_utils, :loginator

  # A module named by directory produces a nested filename, and nothing upstream creates
  # that directory. The file write itself does not create one either.
  def _prepare(filepath)
    @file_wrapper.mkdir( File.dirname( filepath ) )
    return filepath
  end

  def generate_implementation(
      name:,
      function_definitions:,
      source_includes:,
      header_includes:,
      c_module:,
      output_path:,
      header_following_includes: [],
      include_guard: nil,
      carry: Partials::CarryPlan.new,
      suppress_redundant_decls: true,
      extern_variables: :weak
    )
    header = @file_path_utils.form_partial_implementation_header_filename(name)
    source = File.join(output_path, @file_path_utils.form_partial_implementation_source_filename(name))

    _write( File.join(output_path, header) ) do |file|
      generate_header(file, header, header_includes, function_definitions, c_module,
                      include_variables: true, include_guard: include_guard, following_includes: header_following_includes)
    end

    return _write( source ) do |file|
      generate_source(file, source_includes, function_definitions, c_module, carry: carry,
                      suppress_redundant_decls: suppress_redundant_decls, extern_variables: extern_variables, filepath: source)
    end
  end

  def generate_interface(name:, function_declarations:, includes:, c_module:, output_path:, following_includes: [], include_guard: nil)
    header = @file_path_utils.form_partial_interface_header_filename(name)

    return _write( File.join(output_path, header) ) do |file|
      generate_header(file, header, includes, function_declarations, c_module,
                      include_variables: false, include_guard: include_guard, following_includes: following_includes)
    end
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
  # @param includes [Array] Includes ahead of the module's types
  # @param following_includes [Array] The source's includes after the module header, written where
  #   the header's items end (see PartialHeaderWriter#following_includes)
  # @return [String, nil] The bare filename (for use as a sibling #include), or nil if nothing was generated
  def generate_types(name:, c_module:, output_path:, includes: [], following_includes: [], include_guard: nil)
    return nil unless c_module.types?

    header = @file_path_utils.form_partial_types_header_filename(name)
    _write( File.join(output_path, header) ) do |file|
      writer = PartialHeaderWriter.new( io: file, name: header )
      writer.preamble( include_guard, includes )
      write_types( writer, c_module, following_includes.dup )
      writer.finish
    end

    return header
  end

  private

  # The statement kinds that establish a type. C treats a second definition of the same type in
  # one translation unit as a redefinition even when the two are textually identical, unlike an
  # identical #define, which may legally repeat. So these live in the shared types header alone.
  TYPE_KINDS = [:typedef, :aggregate].freeze unless const_defined?(:TYPE_KINDS, false)

  # Writes a generated file, creating the directory a module named by directory needs. Binary
  # mode: the function bodies written may already contain their own line endings verbatim.
  # Windows text mode rewrites every "\n" on write, which would alter any line ending already
  # present in that content instead of passing it through unchanged. Returns the file's path.
  def _write(filepath, &block)
    @file_wrapper.open( _prepare( filepath ), 'wb', &block )
    return filepath
  end

  # The types header's content: each type in element_sequence order, any macro ahead of it,
  # and the source's later includes where the header's items end. `following` is consumed.
  #
  # A type moved here may depend on a macro, such as an array-size constant, that preceded it in
  # the original source. This header is included before any macro generate_header writes inline,
  # so such a macro is carried just ahead of the type that follows it. An identical #define may
  # legally repeat, so generate_header's own copy causes no redefinition.
  def write_types(writer, c_module, following)
    held = []
    c_module.element_sequence.each do |item|
      writer.following_includes( following, macros: held ) if item.origin == :source
      _write_type_item( writer, item, held )
    end

    writer.following_includes( following, macros: held )
  end

  # A macro is held until a type follows it. A type is written after the macros held for it.
  def _write_type_item(writer, item, held)
    return unless item.is_a?( CExtractorTypes::CStatement )
    return held << item if item.kind == :macro
    return unless TYPE_KINDS.include?( item.kind )

    held.each { |macro| writer.line( macro.text ) }.clear
    writer.line( _type_text( item ) )
  end

  # A type statement as the types header writes it. A type a declaration defines, as
  # `struct { int count; }` in `static struct { int count; } s_ctx;`, is written once here, as a
  # typedef naming it for its variables (see Partials.type_name). That keeps an anonymous type
  # one type, and gives a tagged one a name a test can write too.
  def _type_text(item)
    return item.text unless item.kind == :aggregate and item.type_name

    return "typedef #{item.text.chomp( ';' ).rstrip} #{item.type_name};"
  end

  # The type a variable is declared with, and its declaration's text from there on. A type the
  # declaration defines is written once in the types header, so the variable names it.
  def _declared_type(var)
    return var.defined_type ? "#{var.defined_type.type_name} #{var.type}".rstrip : var.type
  end

  # A variable's definition as the implementation source writes it, less any storage class.
  #
  # A `CVariableDeclaration`'s `decorators` mixes storage-class specifiers (`static`, `extern`)
  # with base-type qualifiers (`const`, `volatile`, `restrict`) in their original source order,
  # since both kinds of keyword lead a declaration the same way. The extern and the definition
  # both need the qualifiers -- omitting them gives a type that disagrees with the variable's
  # other declarations -- and neither may carry a storage class: `static` would contradict the
  # external linkage the Partial establishes, and an extern supplies `extern` itself.
  def _definition(var)
    text = var.defined_type ? "#{var.defined_type.type_name} #{var.text}" : var.text
    return "#{qualifier_prefix( var )}#{text}"
  end

  # @param decl [CExtractorTypes::CVariableDeclaration]
  # @return [String] e.g. "volatile " / "const volatile " / "" (trailing space when non-empty)
  def qualifier_prefix(decl)
    quals = decl.decorators.select { |kw| CExtractorConstants::TYPE_QUALIFIER_KEYWORDS.include?(kw) }
    quals.empty? ? '' : "#{quals.join(' ')} "
  end

  # A definition for a variable the module only declares `extern`. Weak, it satisfies the link
  # when nothing else defines the variable and yields to a real definition without a duplicate
  # symbol. A compiler without GCC's weak attribute gets a plain definition.
  def weak_definition(decl)
    text = _definition( decl )
    return "#if defined(__GNUC__)\n__attribute__((weak)) #{text}\n#else\n#{text}\n#endif\n"
  end

  # What generation consults about a module's variables: each variable's defining declaration,
  # which knows its full type, such as an array's size, and each one's asm label, which any of
  # its declarations may hold
  Variables = Struct.new( :defining, :labels, keyword_init: true ) unless const_defined?(:Variables, false)

  def _variables(c_module)
    return Variables.new(
      defining: c_module.variable_declarations.reject( &:extern? ).group_by( &:name ).transform_values( &:first ),
      labels:   c_module.variable_declarations.select( &:asm_label ).to_h { |v| [v.name, v.asm_label] }
    )
  end

  # Emit a partial header file.
  #
  # Iterates c_module.element_sequence to emit non-function items (macros, and optionally
  # variable extern declarations) in their original extraction order. Function items in
  # element_sequence are matched by name against function_list (pre-filtered
  # Partials::FunctionDeclaration or Partials::FunctionDefinition objects) and emitted at their
  # natural position. An entry element_sequence never names is not written.
  #
  # Types live in the shared types header generated by generate_types, so a type is defined
  # exactly once no matter how many of a module's generated headers one test file includes. A
  # bare macro invocation expands to real code, typically a function definition, once compiled.
  # Each generated header is included by several separately compiled sources of one test build,
  # so the invocation belongs only in the implementation source (see generate_source).
  #
  # @param io              [IO]     Output file handle
  # @param name            [String] Header filename (used for include guard)
  # @param includes        [Array]  Include directives
  # @param function_list   [Array]  Pre-filtered Partials function objects (respond to :name and :signature)
  # @param c_module        [CExtractorTypes::CModule] Merged module with element_sequence
  # @param include_variables [Boolean] True for implementation header (emits extern vars); false for interface
  # @param include_guard [String, nil] The real module header's own guard, spoofed so a transitive
  #   reach at that header finds it already satisfied. nil when the header has no guard.
  # @param following_includes [Array] The source's includes after the module header, written where
  #   the header's items end (see PartialHeaderWriter#following_includes)
  def generate_header(io, name, includes, function_list, c_module, include_variables:, include_guard: nil, following_includes: [])
    context   = _header_context( io, name, function_list, include_variables ? _variables( c_module ) : nil )
    following = following_includes.dup

    context.writer.preamble( include_guard, includes )
    c_module.element_sequence.each do |item|
      context.writer.following_includes( following ) if item.origin == :source
      _write_header_item( item, context )
    end
    context.writer.following_includes( following )
    context.writer.finish
  end

  # What header generation consults about the module as it writes each item. A function leaves
  # `functions` once written, so a later declaration or definition of it writes nothing.
  HeaderContext = Struct.new( :writer, :variables, :emitted, :functions, keyword_init: true ) unless const_defined?(:HeaderContext, false)

  def _header_context(io, name, function_list, variables)
    return HeaderContext.new(
      writer: PartialHeaderWriter.new( io: io, name: name ), variables: variables, emitted: Set.new,
      functions: function_list.to_h { |f| [f.name, f] }
    )
  end

  def _write_header_item(item, context)
    case item
    when CExtractorTypes::CStatement
      context.writer.line( item.text ) if item.kind == :macro
    when CExtractorTypes::CVariableDeclaration
      _write_extern( item, context )
    when CExtractorTypes::CFunctionDefinition, CExtractorTypes::CFunctionDeclaration
      func = context.functions.delete( item.name )
      context.writer.function( func.signature ) if func
    end
  end

  # An interface header writes no variables, so its context holds none
  def _write_extern(item, context)
    extern = context.variables && _header_extern( item, context )
    context.writer.line( extern ) if extern
  end

  # The extern a header writes for a variable, or nil when it writes none.
  # - A variable the extractor read no name from, such as one a macro declares, has no extern.
  # - A header's extern and the source's definition name one variable, so it gets one line.
  # - The definition knows the full type, such as an array's size, so the extern comes from there.
  # - A leading const, volatile or restrict is part of the type (see _definition), so the
  #   extern agrees with every other declaration of the variable.
  # - A function pointer or a pointer to an array has its name inside a parenthesized
  #   declarator, which the extern writes whole.
  # - An asm label names the variable's symbol, so the extern carries it to reach that symbol.
  #   Any of the variable's declarations may hold it. The implementation source includes the
  #   extern ahead of the definition, so the Partial's symbol takes the label too.
  def _header_extern(item, context)
    name = item.name
    return nil unless name and context.emitted.add?( name )

    var      = context.variables.defining[name] || item
    declared = [var.declarator || "#{name}#{var.array_suffix}", context.variables.labels[name]].compact
    return "extern #{qualifier_prefix( var )}#{_declared_type( var )} #{declared.join( ' ' )};"
  end

  # Emit a partial source file.
  #
  # Iterates c_module.element_sequence and writes, in their original extraction order:
  #   - the selected functions, matched by name against function_definitions;
  #   - the header helpers and prototypes the carry plan carries;
  #   - variable definitions, and for a variable the module only declares `extern`, what
  #     `extern_variables` asks for;
  #   - bare macro invocations, the one CStatement category that belongs here. A real function
  #     definition, once such a macro is applied, would violate the one-definition rule the
  #     moment more than one compiled object contains it. This is the one file that compiles to
  #     the one object the real definition can safely live in.
  # Every other CStatement category belongs in a header.
  #
  # @param io                       [IO]      Output file handle
  # @param includes                 [Array]   Include directives
  # @param function_definitions     [Array]   Pre-filtered Partials::FunctionDefinition objects
  # @param c_module                 [CExtractorTypes::CModule] Merged module with element_sequence
  # @param carry                    [Partials::CarryPlan] What the source carries beyond the selection
  # @param suppress_redundant_decls [Boolean] Whether carried prototypes sit inside GCC pragmas
  # @param extern_variables         [Symbol]  :weak or :test, for variables the module only declares
  # @param filepath                 [String, nil] This file's own path, for handing #line attribution back
  def generate_source(io, includes, function_definitions, c_module, carry: Partials::CarryPlan.new,
                      suppress_redundant_decls: true, extern_variables: :weak, filepath: nil)
    writer  = PartialSourceWriter.new( io: io, filepath: filepath, suppress_redundant_decls: suppress_redundant_decls )
    context = SourceContext.new(
      carry: carry, extern_variables: extern_variables, weak: Set.new, variables: _variables( c_module ),
      selected: function_definitions.to_h { |f| [f.name, f] }
    )

    writer.preamble( includes )
    c_module.element_sequence.each { |item| _write_source_item( writer, item, context ) }
    writer.finish
  end

  # What source generation consults about the module as it writes each item
  SourceContext = Struct.new( :carry, :extern_variables, :selected, :variables, :weak, keyword_init: true ) unless const_defined?(:SourceContext, false)

  def _write_source_item(writer, item, context)
    case item
    when CExtractorTypes::CStatement
      writer.text( "#{item.text}\n" ) if item.kind == :invocation
    when CExtractorTypes::CVariableDeclaration
      _write_variable( writer, item, context )
    when CExtractorTypes::CFunctionDefinition
      writer.function( _selected_or_carried( item, context ) )
    when CExtractorTypes::CFunctionDeclaration
      writer.prototype( item ) if context.carry.prototype?( item )
    end
  end

  def _write_variable(writer, var, context)
    text = _source_variable( var, context )
    writer.text( text ) if text
  end

  # A function's selected definition, or the helper the carry plan carries by its name, or nil
  def _selected_or_carried(func, context)
    return context.selected[func.name] || context.carry.helper( func.name )
  end

  # A variable's definition, or nil. A variable the module defines is written where it does.
  # One it only declares `extern` gets a weak definition, once, unless `extern_variables` leaves
  # it to the test or its type is never completed, which no definition could compile with.
  def _source_variable(var, context)
    return "#{_definition( var )}\n" unless var.extern?
    return nil if context.extern_variables != :weak
    return nil if context.variables.defining.key?( var.name ) or context.carry.incomplete?( var.name )
    return nil unless context.weak.add?( var.name )

    return weak_definition( var )
  end

end
