# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'set'
require 'ceedling/constants'

# Pairs what a Partial extracts from a file's written text with its twin in the file's full
# expansion, where no macro hides anything.
#
# Extraction reads the directives-only copy, so a Partial writes code as its user spelled
# it. That copy keeps every macro, so a macro can hide a storage class, an inline specifier
# or a call. The full expansion shows them. A function or a declaration takes from its twin
# what a macro can hide, and keeps its code as written, so line mapping still holds. A
# variable whose storage class a macro supplies takes its whole declaration from its twin. A
# type regains a macro after its closing brace that the written text read as a variable.
#
# Definitions pair by name. Declarations and file-scope variables pair by name and then by
# order, since a name may be declared more than once.
class PartializerReconciler

  # A variable takes these from its twin when a macro supplies its storage class
  VARIABLE_FIELDS = %i[decorators type array_suffix text declarator asm_label].freeze

  STORAGE_CLASSES = %w[static extern].freeze

  constructor :c_extractor, :loginator

  # Reconciles one file's extracted module with that file's expanded code, in place
  #
  # @param c_module           [CExtractorTypes::CModule] One file's module, as extracted from its written text
  # @param expansion_filepath [String] The file's own lines from its full expansion, written by
  #   Preprocessinator#generate_partial_expansion
  # @param name               [String] Test name, used in log messages
  # @param module_name        [String] Partial module name, used in log messages
  # @param file_type          [String] "source" or "header", used in log messages
  def reconcile(c_module:, expansion_filepath:, name:, module_name:, file_type:)
    expanded = @c_extractor.from_file( expansion_filepath )
    _rejoin_trailing_macros( c_module, expanded )
    entries  = _reconcile_definitions( c_module.function_definitions, expanded ) +
               _reconcile_declarations( c_module.function_declarations, expanded ) +
               _reconcile_variables( c_module, expanded )

    @loginator.log_list(
      entries,
      "Updated signatures from full expansion for Partial #{name}::#{module_name} #{file_type}:",
      Verbosity::DEBUG
    ) unless entries.empty?
  end

  private

  # Updates each definition from the expanded definition of the same name. Returns log entries
  # for those it found.
  def _reconcile_definitions(funcs, expanded_module)
    expanded_by_name = expanded_module.function_definitions.each_with_object({}) { |f, h| h[f.name] = f }

    return funcs.filter_map do |func|
      expanded = expanded_by_name[func.name]
      next unless expanded

      _take_expanded( func, expanded )
      "`#{func.name}`"
    end
  end

  # Everything about a definition that a macro can hide. Its code block stays as written, so
  # line mapping still holds. The decorators its written head doesn't spell are noted, since
  # that head can't be stripped of them.
  def _take_expanded(func, expanded)
    func.hidden_decorators  = expanded.decorators - func.decorators
    func.signature          = expanded.signature
    func.decorators         = expanded.decorators
    func.signature_stripped = expanded.signature_stripped
    func.expanded_body      = expanded.body
  end

  # Matches each declaration to the expanded declaration of the same name, in order. Returns log
  # entries for those whose decorators changed.
  def _reconcile_declarations(decls, expanded_module)
    expanded_by_name = expanded_module.function_declarations.group_by( &:name )

    return decls.group_by( &:name ).flat_map do |decl_name, same_name|
      same_name.zip( expanded_by_name.fetch( decl_name, [] ) ).filter_map { |decl, expanded| _reconcile_declaration( decl, expanded ) }
    end
  end

  # Updates one declaration from its expanded counterpart. Its written signature stays as the
  # user spelled it, since a carried prototype is written word for word. Returns a log entry
  # when its decorators changed.
  def _reconcile_declaration(decl, expanded)
    return nil if expanded.nil?

    changed = decl.decorators != expanded.decorators
    decl.decorators         = expanded.decorators
    decl.signature_stripped = expanded.signature_stripped
    return changed ? "`#{decl.name}` (declaration)" : nil
  end

  # Gives a type back the macro after its closing brace, as `PACKED` in `struct pk { … } PACKED;`.
  # The written text reads that macro as a variable the type defines. The expansion shows the
  # macro belongs to the type. It holds no variable of that name, and it defines the tag on its
  # own. A type with no tag, or with more than one variable, is left alone, since its expansion
  # can't be matched.
  def _rejoin_trailing_macros(c_module, expanded_module)
    names   = Set.new( expanded_module.variable_declarations.filter_map( &:name ) )
    tags    = _standalone_tags( expanded_module )
    misread = c_module.variable_declarations.select { |var| _misread?( c_module, var, names, tags ) }

    misread.each { |var| var.defined_type.text = "#{var.defined_type.text.chomp( ';' )} #{var.text}" }
    c_module.remove!( misread )
  end

  # Whether a written variable is a macro that ends its type
  def _misread?(c_module, var, names, tags)
    tag = var.defined_type&.tag
    return false if tag.nil? or names.include?( var.name ) or !tags.include?( tag )

    return c_module.variable_declarations.none? { |other| !other.equal?( var ) and other.defined_type.equal?( var.defined_type ) }
  end

  # The tags of the types a module defines with a body, apart from any named variable. A
  # forward declaration defines nothing. A declaration with no variable name, as
  # `static struct pk { … } __attribute__((packed));` expands, still defines its type alone.
  def _standalone_tags(c_module)
    named   = c_module.variable_declarations.select( &:name ).filter_map( &:defined_type )
    defined = Set.new.compare_by_identity.merge( named )
    bodied  = c_module.aggregate_definitions.select { |type| type.text.include?( '{' ) and !defined.include?( type ) }
    return Set.new( bodied.filter_map( &:tag ) )
  end

  # Pairs each file-scope variable with its twin by name, then order. A name pairs only where it
  # appears as often in both copies, since fallback can keep both branches of a conditional. A
  # variable with no name it can be read by never pairs. Returns log entries for those reconciled.
  def _reconcile_variables(c_module, expanded_module)
    expanded_by_name = expanded_module.variable_declarations.group_by( &:name )

    return c_module.variable_declarations.group_by( &:name ).flat_map do |var_name, same_name|
      twins = expanded_by_name.fetch( var_name, [] )
      next [] if var_name.nil? or twins.size != same_name.size

      same_name.zip( twins ).filter_map { |var, twin| _reconcile_variable( c_module, var, twin ) }
    end
  end

  # A variable whose storage class a macro supplies takes every parsed field from its twin. Its
  # fields depend on each other, so a mix of written and expanded ones could read `extern static`.
  # A macro that supplies only a qualifier, as `#define ROM const`, compiles as written.
  def _reconcile_variable(c_module, var, twin)
    return nil if (var.decorators & STORAGE_CLASSES) == (twin.decorators & STORAGE_CLASSES)

    VARIABLE_FIELDS.each { |field| var[field] = twin[field] }
    _adopt_defined_type( c_module, var, twin )
    return "`#{var.name}` (variable)"
  end

  # Places ahead of the variable the type its twin defines, which a macro ahead of it hid from
  # the written declaration. Once per type, however many variables share it.
  def _adopt_defined_type(c_module, var, twin)
    type = twin.defined_type
    return if type.nil? or var.defined_type

    c_module.insert_before!( var, [type] ) unless c_module.aggregate_definitions.any? { |held| held.equal?( type ) }
    var.defined_type = type
  end

end
