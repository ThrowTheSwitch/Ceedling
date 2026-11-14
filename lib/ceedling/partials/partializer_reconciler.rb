# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Pairs what a Partial extracts from a file's written text with its twin in the file's full
# expansion, where no macro hides anything.
#
# Extraction reads the directives-only copy, so a Partial writes code as its user spelled
# it. That copy keeps every macro, so a macro can hide a storage class, an inline specifier
# or a call. The full expansion shows them. Each written item takes from its twin what a
# macro can hide, and keeps its code as written, so line mapping still holds.
#
# Definitions pair by name. Declarations pair by name and then by order, since a name may be
# declared more than once.
class PartializerReconciler

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
    entries  = _reconcile_definitions( c_module.function_definitions, expanded ) +
               _reconcile_declarations( c_module.function_declarations, expanded )

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

end
