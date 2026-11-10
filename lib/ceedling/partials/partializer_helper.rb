# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'set'
require 'ceedling/exceptions'
require 'ceedling/array_patches' # Redundant `require` to ensure patching in test cases
require 'ceedling/partials/partials'
require 'ceedling/c_extractor/c_extractor_declarations'
require 'ceedling/c_extractor/c_extractor_functions'
require 'ceedling/c_extractor/c_extractor_constants'
require 'strscan'
require 'ceedling/constants'
require 'ceedling/parsing_parcels'
require 'ceedling/preprocess/c_preprocessor_conditionals'

class PartializerHelper

  # Content Partials relocates out of a module, so a conditional deciding whether it exists has
  # to be decided rather than assumed.
  #
  # Deliberately narrow: a leading type-definition keyword, which is how a file-scope type
  # definition opens. It does not reach an aggregate written directly on a variable
  # (`static struct { int a; } slot;`) nor a declaration behind a storage class. Widening it far
  # enough to catch those would also match an ordinary local declaration inside a function body,
  # turning a resolvable module into a refused one -- and telling the two apart needs brace
  # tracking this check does not do. Under-reaching leaves a shape unrefused; over-reaching
  # breaks a working build.
  RELOCATED_CONTENT = /^\s*(?:typedef|struct|union|enum)\b/ unless const_defined?(:RELOCATED_CONTENT, false)

  # Any #include, however its target is spelled. Paired with the two PATTERNS filename forms, it
  # isolates the computed case: a directive whose target matches neither a quoted nor an angled
  # filename is naming a macro. PreprocessinatorIncludesHandler draws the same distinction for
  # the same reason, against its own copy of this pattern.
  ANY_INCLUDE_DIRECTIVE = /^\s*#\s*include\s+\S/ unless const_defined?(:ANY_INCLUDE_DIRECTIVE, false)

  # Code uses a function wherever it names one. A call counts, and so do an address taken, a
  # callback passed by name and an entry in a table of handlers.
  C_IDENTIFIER = /(?<![\w$])[A-Za-z_$][\w$]*/ unless const_defined?(:C_IDENTIFIER, false)

  # A struct or union member, or a struct, union or enum tag, which only shares a name with any function
  C_MEMBER_ACCESS = /(?:\.|->)\s*[A-Za-z_$][\w$]*/ unless const_defined?(:C_MEMBER_ACCESS, false)
  C_TAG           = /(?<![\w$])(?:struct|union|enum)\s+[A-Za-z_$][\w$]*/ unless const_defined?(:C_TAG, false)

  # A local variable declared at the start of a statement. Any qualifiers come first, then a
  # type name, any pointer stars, and the variable's name ahead of `=`, `;`, `,` or `[`. A
  # keyword that starts a statement is no type, so `return x;` declares nothing.
  C_LOCAL_DECLARATION = /(?:\A|[;{}(])\s*(?:(?:const|volatile|static|register|auto|signed|unsigned|struct|union|enum|long|short)\s+)*([A-Za-z_$][\w$]*)(?:\s*\*[\s*]*|\s+)(?:const\s+)?([A-Za-z_$][\w$]*)\s*(?=[=;,\[])/ unless const_defined?(:C_LOCAL_DECLARATION, false)
  C_STATEMENT_KEYWORDS = %w[return goto case default else do sizeof typedef break continue].freeze unless const_defined?(:C_STATEMENT_KEYWORDS, false)

  # A preprocessor directive line, matched from the line's start past any leading whitespace
  DIRECTIVE_START = /[\t\v\f\r ]*#/ unless const_defined?(:DIRECTIVE_START, false)

  # What one walk of a run has seen so far. Words on a directive line never set a specifier.
  DefinitionWalk = Struct.new( :directive, :inline, :static, keyword_init: true ) unless const_defined?(:DefinitionWalk, false)
  OPEN_BRACE      = '{'.ord unless const_defined?(:OPEN_BRACE, false)

  # The names a carry plan decides by, grouped once per module
  CarryFacts = Struct.new( :selected, :defined, :declared, :helpers, keyword_init: true ) unless const_defined?(:CarryFacts, false)

  # What the helper scan shares while it walks. That is the plan it fills and the facts that gate it.
  CarryScan = Struct.new( :plan, :declared, :fallback, :header_guarded, keyword_init: true ) unless const_defined?(:CarryScan, false)

  # Names a definition the extractor read no function name from, and how to spell it plainly
  UNREADABLE_NAME_ERROR = <<~ERROR.chomp unless const_defined?(:UNREADABLE_NAME_ERROR, false)
    Partial %<partial>s ⏩️ Cannot read the name of the function declared by `%<declaration>s`.

    OPTIONS:
      1. If it returns or takes a function pointer, give that type a name with a typedef and use the name in this declaration.
      2. If a macro generates the declaration, declare the function directly.
  ERROR


  include Partials

  constructor(
    :partializer_utils,
    :c_extractor,
    :c_extractor_declarations,
    :file_path_utils,
    :parsing_parcels,
    :loginator
  )

  def setup()
    # Aliases
    @utils = @partializer_utils
    @declaration_extractor = @c_extractor_declarations
  end

  # 1. Filter functions by visibility (:private | :public | :deduct) or seed an empty list (:accumulate)
  # 2. Transform functions to appropriate container (:impl | :interface) → `FunctionDefinition[]` or `FunctionDeclaration[]`
  def filter_and_transform_funcs(funcs, visibility, output_type)
    # DEDUCT starts with all functions regardless of visibility; subtractions are applied later by the caller
    if visibility == DEDUCT
      return funcs.filter_map { |func| @utils.transform_function(func, func.signature_stripped, output_type) }
    end

    # ACCUMULATE starts with an empty list; the caller then injects explicitly named additions
    return [] unless [PRIVATE, PUBLIC].include?(visibility)

    # PUBLIC or PRIVATE: filter to matching visibility, then transform
    funcs.filter_map do |func|
      next unless @utils.matches_visibility?(func.decorators, visibility)

      @utils.transform_function(func, func.signature_stripped, output_type)
    end
  end

  # Find a function by name, searching primary_funcs first then secondary_funcs.
  # Returns the first match transformed for the given output_type, or nil if not found.
  # For :impl output_type, pass secondary_funcs: [] — declarations have no code_block.
  def find_and_transform_func(name:, primary_funcs:, secondary_funcs:, output_type:)
    func = primary_funcs.find { |f| f.name == name }
    return @utils.transform_function(func, func.signature_stripped, output_type) if func

    func = secondary_funcs.find { |f| f.name == name }
    return @utils.transform_function(func, func.signature_stripped, output_type) if func

    nil
  end

  # Return funcs with any function whose name is in names removed.
  def subtract_funcs(funcs:, names:)
    return funcs if names.empty?
    name_set = Set.new(names)
    funcs.reject { |f| name_set.include?(f.name) }
  end

  # Associate each FunctionDefinition with its line number in the original source file.
  #
  # C source files are run through the GCC preprocessor before extraction. The
  # resulting fully expanded output file retains GCC line markers of the form:
  #   # <linenum> "<filename>" [flags]
  # These markers preserve the correspondence between preprocessed text and the
  # original source lines, even after macro expansion has altered the content.
  #
  # For each function in funcs, this method searches the preprocessor expansion
  # for an exact match of the function's `code_block`` text. When a match is
  # found, the GCC line marker immediately preceding the match is used to
  # calculate the 1-indexed source line number. This line number is then written 
  # back into the `FunctionDefinition` struct alongside the originating filepath.
  #
  # An entry whose `code_block` the preprocessor output lacks is searched for in
  # the original source. One found in neither gets a nil `line_num`.
  # 
  # `source_filepath` is always updated.
  #
  # @param name [String]Name of the containing test, used to construct the path to 
  # the preprocessor expansion file for that test context.
  # @param funcs [Array<FunctionDefinition>] Function definitions whose source 
  # locations are to be resolved. Matched entries are mutated in place.
  # @param filepath [String] Path to the original C source file that was 
  # preprocessed, written into each matched FunctionDefinition as source_filepath.
  # @param fallback [bool] Whether to immediately use simple source file scanning
  # instead of preprocessed output (because preprocessed output is not available)
  def associate_function_line_numbers(name:, funcs:, filepath:, fallback:)
    # File path of directives-only preprocessor output
    preprocessed_filepath = @file_path_utils.form_preprocessed_file_raw_directives_only_filepath( filepath, name )

    @utils.stamp_source_filepaths( funcs, filepath )

    # Every function is located with one read of each file searched
    code_blocks = funcs.map( &:code_block )
    if fallback
      msg = "Using fallback C function location search for #{filepath}"
      @loginator.log( msg, Verbosity::OBNOXIOUS, LogLabels::WARNING )

      lines = @utils.locate_functions_in_source( code_blocks: code_blocks, filepath: filepath )
    else
      # Searches the original source for any function the preprocessed copy lacks
      lines = @utils.locate_functions_via_preprocessed(
        code_blocks: code_blocks, filepath: filepath, preprocessed_filepath: preprocessed_filepath
      )
    end
    funcs.zip( lines ) { |func, line_num| func.line_num = line_num }

    funcs.each do |func|
      if func.line_num.nil?
        msg = "Could not locate function #{func.name}() in #{filepath} ➡️ Any test coverage reporting will be incomplete."
        @loginator.log( msg, Verbosity::COMPLAIN )
      end
    end

    header = "Found functions at line numbers in #{filepath}:"
    @loginator.log_list( @utils.format_line_number_list( funcs ), header, Verbosity::DEBUG )
  end

  # Record where each declaration sits in its original file.
  #
  # A carried prototype is written behind a #line naming this file and line, so a diagnostic
  # points at the user's own declaration. Callers pass the file's text, read once per file. Its
  # comments are blanked once for every declaration. A declaration that can't be found keeps no
  # line and is written without a #line.
  #
  # @param decls    [Array<CFunctionDeclaration>] Declarations extracted from one file, updated in place
  # @param filepath [String] Path of the original header or source file
  # @param text     [String] That file's full text
  def associate_declaration_line_numbers(decls:, filepath:, text:)
    lines = @utils.locate_declarations_in_text( signatures: decls.map( &:signature ), text: text )

    decls.zip( lines ) do |decl, line_num|
      decl.source_filepath = filepath
      decl.line_num        = line_num
    end
  end

  # Excise function-scoped static variable declarations from function bodies (to be
  # promoted to module-scope).
  #
  # C functions may contain local `static` variable declarations. These variables have
  # file-level storage duration but function-level scope. When generating partials, they
  # must be lifted out of function bodies and treated as module-level variables so that
  # linker and coverage tooling see them correctly.
  #
  # For each function in `funcs`, this method:
  #   1. Scans the function body for variable declarations bearing a private keyword
  #      (i.e. any keyword in `CExtractorConstants::PRIVATE_KEYWORDS`, e.g. `static`).
  #   2. Replaces each such declaration in the function's `code_block` and `body` with a
  #      no-op expression of the form `(void)0; /* <original text> */` so that coverage
  #      line mappings remain valid without re-declaring the variable inside the body.
  #   3. Renames each private function-scoped declaration to be prepended with the 
  #      containing function name to prevent name collisions at module-scope.
  #   4. Collects all promoted declarations and returns them for inclusion at module scope.
  #
  # @param funcs       [Array<CFunctionDefinition>] Function definitions to scan. Each matched
  #   function's `code_block` and `body` fields are mutated in place.
  # @param name        [String] Test name, used in log messages.
  # @param module_name [String] Module name, used in log messages.
  # @param file_type   [String] "source" or "header", used in log messages.
  #
  # @return [Array<CVariableDeclaration>] All function-scoped static variable declarations
  #   found across all supplied functions, suitable for emission at module scope.
  def extract_function_scope_static_vars(funcs, name:, module_name:, file_type:)
    decls = []

    # Process each function definition looking for function-scoped static variables.
    # If found, collect them and remove from function `body` and `code_block`.
    funcs.each do |func|
      # Remove containing brackets of function body
      func_body = func.body.dup
      func_body.delete_prefix!( '{' )
      func_body.delete_suffix!( '}' )

      scanner = StringScanner.new( func_body )
      _decls = []

      loop do
        # `try_extract_variable` returns an array of declarations.
        # A compound declaration (e.g. int x, y) yields multiple declaration Structs
        success, var_decls = @declaration_extractor.try_extract_variable( scanner )
        break unless success
        _decls.concat( var_decls.select { |var| var.decorators.any? { |d| CExtractorConstants::PRIVATE_KEYWORDS.include?( d ) } } )
      end

      # Group declarations by statement. The variables of a compound declaration, such as
      # `static int a, b;`, share one statement, which becomes one no-op per variable.
      groups = _decls.group_by { |var| var.original.strip }

      # A static the extractor read no name from, such as one a macro declares, can't be renamed.
      # Its whole statement stays in the body, still a valid local, and nothing of it is promoted.
      groups.reject! { |_original, vars| vars.any? { |var| var.name.nil? } }
      _decls = groups.values.flatten

      _promote_statements( func, groups ) unless groups.empty?

      _decls_log = _decls.map { |d| "`#{d.original.strip}`" }
      @loginator.log_list(
        _decls_log,
        "Function-scope static variables in #{func.name}() in #{file_type} to be promoted for Partial #{name}::#{module_name}:",
        Verbosity::OBNOXIOUS
      ) unless _decls_log.empty?

      decls += _decls
    end

    return decls
  end

  # Promotes a function's statics to module scope under new names. Each statement becomes one
  # no-op per variable, with its text kept in a comment behind a placeholder. Every statement is
  # replaced before any rename, since a rename would change the text a later statement is found
  # by. Each variable's text, declarator and array size then take every rename, because one
  # static's initializer may name another, as in `static int a = 1, *p = &a;`. The placeholders
  # are restored last, so no rename reaches the restored text.
  def _promote_statements(func, groups)
    vars         = groups.values.flatten
    renames      = vars.to_h { |var| [var.name, "partial_#{func.name}_#{var.name}"] }
    placeholders = groups.map { |original, group| [original, _replace_statement( func, original, group )] }

    vars.each { |var| _rename_variable( var, renames ) }
    _in_function( func ) { |text| _restored( @utils.rename_c_identifiers( text, renames ), placeholders ) }
  end

  # The text with each statement's original put back in place of its placeholder
  def _restored(text, placeholders)
    return placeholders.reduce( text ) { |restored, (original, placeholder)| restored.sub( placeholder ) { original } }
  end

  # Puts one no-op per variable where the statement stood, followed by a placeholder comment,
  # and returns the placeholder. It's keyed on the statement's first variable.
  def _replace_statement(func, original, vars)
    placeholder = "__CEEDLING_NOOP_#{func.name.upcase}_#{vars.first.name.upcase}__"
    _in_function( func ) { |text| @utils.replace_compound_declaration_with_noops( text, original, placeholder, vars.size ) }
    return placeholder
  end

  # Gives a promoted variable its new name. Its text, declarator and array size take the new
  # name of every promoted variable they mention.
  def _rename_variable(var, renames)
    var.text, var.declarator, var.array_suffix = [var.text, var.declarator, var.array_suffix].map { |text| text && @utils.rename_c_identifiers( text, renames ) }
    var.name = renames[var.name]
  end

  # Changes the function's code block and its body alike, as the block does each one. Each
  # promoted statement and each rename must reach both.
  def _in_function(func)
    func.code_block = yield( func.code_block )
    func.body       = yield( func.body )
  end

  # Refuses a module whose shape fallback preprocessing cannot resolve.
  #
  # Fallback never runs a compiler. It scans text and tracks a handful of conditional shapes
  # against a defines list, so two shapes are knowably beyond it, and generating from either
  # leaves a compiler or a linker to report something arcane several stages later. Refusing
  # here -- before anything is written -- trades a confusing failure for a specific one.
  #
  # `files` maps a filepath to that file's text, so this method reads nothing itself and a spec
  # can exercise every branch without a filesystem.
  def validate_fallback_sufficiency(name:, module_name:, files:)
    files.each do |filepath, text|
      # One tracker per file, walked alongside the lines so every line is judged in the
      # conditional state that actually encloses it.
      tracker = CPreprocessorConditionals.new( [] )

      @parsing_parcels.code_lines_with_num( text ) do |line, _line_num, end_line_num|
        tracker.process_directive( line )

        reason = _fallback_blocker( line, tracker )
        next if reason.nil?

        raise CeedlingException.new(
          "Partial #{name}::#{module_name} \u23e9\ufe0f #{filepath}:#{end_line_num} #{reason} " \
          "Partials for this module require directives-only preprocessing."
        )
      end
    end
  end

  # What puts this line beyond fallback preprocessing, or nil when fallback resolves it.
  #
  # Only an active line can matter. A directive or definition that fallback already drops with
  # the rest of an inactive block is no reason to refuse -- a real preprocessor drops it too.
  def _fallback_blocker(line, tracker)
    return nil unless tracker.active?

    # An #include naming a macro needs real expansion to resolve. Fallback has none, so the
    # include is lost outright and whatever it declared is missing from every list built from it,
    # the dependencies the shared types header carries included.
    if _computed_include?( line )
      'computes an #include target that fallback preprocessing cannot resolve.'

    # Content chosen by a condition the tracker kept without evaluating. Keeping such a block is
    # the safe default for text the Partial ignores and the wrong answer for content it
    # relocates: the types header would carry a type the build should not have, and no later
    # stage can tell it was a guess.
    elsif tracker.unevaluated? && _relocated_content?( line )
      'sits behind a conditional expression that fallback preprocessing cannot evaluate.'
    end
  end

  def _computed_include?(line)
    line.match?( ANY_INCLUDE_DIRECTIVE ) &&
      !line.match?( PATTERNS::USER_INCLUDE_DIRECTIVE_FILENAME ) &&
      !line.match?( PATTERNS::SYSTEM_INCLUDE_DIRECTIVE_FILENAME )
  end

  def _relocated_content?(line)
    line.match?( RELOCATED_CONTENT ) || line.match?( ANY_INCLUDE_DIRECTIVE )
  end


  # For each function definition in funcs, find the matching function by name in the fully
  # preprocessed expansion file and replace the three signature-related fields with their
  # macro-expanded equivalents. The expanded body is kept alongside in expanded_body, where a
  # call hidden in a macro is visible. All other fields — especially code_block — are preserved
  # from the directives-only extraction so that line number mapping stays valid.
  #
  # Declarations get their decorators and stripped signature the same way, so a macro that
  # hides `static` is seen for what it is. Their written signature stays as the user spelled
  # it, because a carried prototype is written word for word.
  #
  # @param funcs [Array<CFunctionDefinition>] Definitions to update in place.
  # @param full_expansion_filepath [String] Path to the assembled full expansion file
  #   produced by preprocess_partial_{header,source}_expand_macros().
  # @param name [String] Test name, used in log messages.
  # @param module_name [String] Partial module name, used in log messages.
  # @param file_type [String] "source" or "header", used in log messages.
  # @param decls [Array<CFunctionDeclaration>] Declarations to update in place.
  def update_signatures_from_full_expansion(funcs:, full_expansion_filepath:, name:, module_name:, file_type:, decls: [])
    expanded_module = @c_extractor.from_file( full_expansion_filepath )
    entries         = _reconcile_definitions( funcs, expanded_module ) + _reconcile_declarations( decls, expanded_module )

    @loginator.log_list(
      entries,
      "Updated signatures from full expansion for Partial #{name}::#{module_name} #{file_type}:",
      Verbosity::DEBUG
    ) unless entries.empty?
  end

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
  # line mapping still holds.
  def _take_expanded(func, expanded)
    func.signature          = expanded.signature
    func.decorators         = expanded.decorators
    func.signature_stripped = expanded.signature_stripped
    func.expanded_body      = expanded.body
  end

  # Matches each declaration to the expanded declaration of the same name, in order, since
  # a name may be declared more than once. Returns log entries for those whose decorators changed.
  def _reconcile_declarations(decls, expanded_module)
    expanded_by_name = expanded_module.function_declarations.group_by( &:name )

    return decls.group_by( &:name ).flat_map do |decl_name, same_name|
      same_name.zip( expanded_by_name.fetch( decl_name, [] ) ).filter_map { |decl, expanded| _reconcile_declaration( decl, expanded ) }
    end
  end

  # Updates one declaration from its expanded counterpart. Returns a log entry when its decorators changed.
  def _reconcile_declaration(decl, expanded)
    return nil if expanded.nil?

    changed = decl.decorators != expanded.decorators
    decl.decorators         = expanded.decorators
    decl.signature_stripped = expanded.signature_stripped
    return changed ? "`#{decl.name}` (declaration)" : nil
  end

  # Marks each declaration whose function the text defines inline with external linkage. Given
  # a file's raw directives-only copy, which holds every header the file includes, a mark means
  # the declaring file holds the function's external definition under C99.
  #
  # @param decls [Array<CExtractorTypes::CFunctionDeclaration>] The file's declarations of functions the module never defines, decorators reconciled
  # @param text  [String] The file's raw directives-only copy, read as bytes
  def mark_inline_elsewhere(decls:, text:)
    defined = _inline_definitions( text, Set.new( decls.map( &:name ) ) )

    decls.each do |decl|
      decl.inline_elsewhere = (!Partials.static?( decl.decorators ) and defined.include?( decl.name ))
    end
  end

  # Decide what a Partial's implementation source carries beyond its selected functions.
  #
  # A module's code relies on more than the functions a test selects. It uses functions defined
  # elsewhere through prototypes, and small static or inline helpers its header defines. Each
  # function name falls into one category.
  #   - Selected to test or to mock. Nothing is carried.
  #   - External, declared but defined nowhere in the module. Its prototypes that are not
  #     static, when kept code uses the name. A prototype of an inline function another header
  #     defines always, since it makes this file hold the function's external definition.
  #   - A header helper, a static or inline body in the header. The body and its prototypes,
  #     when kept code uses it.
  #   - Left out, any other unselected body. Its prototypes that are neither static nor
  #     inline, when kept code uses the name.
  #
  # The result is pure data. The generator writes it into the implementation source after
  # every include, where each carried item can see everything the module's code saw.
  #
  # @param c_module       [CExtractorTypes::CModule] Merged module with origins and reconciled decorators
  # @param impl           [Array<Partials::FunctionDefinition>] Functions selected to test
  # @param interface      [Array<Partials::FunctionDeclaration>, nil] Functions selected to mock
  # @param fallback       [Boolean] Whether fallback preprocessing produced the module's copies
  # @param header_guarded [Boolean] Whether the module header has an include guard to stand in for
  # @return [Partials::CarryPlan]
  def plan_carry(c_module:, impl:, interface:, fallback:, header_guarded:)
    facts = _carry_facts( c_module, impl, interface )
    plan  = Partials::CarryPlan.new

    scan       = CarryScan.new( plan: plan, declared: facts.declared, fallback: fallback, header_guarded: header_guarded )
    references = _plan_helpers( scan, c_module, impl, facts.helpers )

    _plan_all_prototypes( plan, facts, fallback, references )

    return plan
  end

  def _plan_all_prototypes(plan, facts, fallback, references)
    facts.declared.each do |name, decls|
      next unless _prototype_candidate?( facts, name )

      _plan_prototypes(
        plan, name, decls, has_body: facts.defined.key?( name ), fallback: fallback, referenced: references.include?( name )
      )
    end
  end

  # The names a plan decides by. They are the names the test selected, those with bodies,
  # those with prototypes, and the unselected bodies that are header helpers.
  def _carry_facts(c_module, impl, interface)
    selected = Set.new( Array( impl ).map( &:name ) + Array( interface ).map( &:name ) )
    defined  = c_module.function_definitions.group_by( &:name )

    return CarryFacts.new(
      selected: selected,
      defined:  defined,
      declared: c_module.function_declarations.group_by( &:name ),
      helpers:  defined.select { |name, defs| !selected.include?( name ) and _helper?( defs ) }
    )
  end

  # A selected function is written as selected, and a helper's prototypes travel with its body
  def _prototype_candidate?(facts, name)
    return !(facts.selected.include?( name ) or facts.helpers.key?( name ))
  end

  def _plan_prototypes(plan, name, decls, has_body:, fallback:, referenced:)
    keep = _carryable_prototypes( decls, has_body, referenced )
    return if keep.empty?

    # Fallback may keep both sides of a conditional, and two different types for one name won't compile
    if fallback and _conflicting?( keep.map( &:signature_stripped ) )
      plan.skip( name, :prototype_conflict )
      return
    end

    reason = has_body ? 'left out: body not selected' : 'external: no body in module'
    keep.each { |d| plan.add_prototype( d, reason ) }
  end

  # Never a static prototype. An inline prototype promises an inline body, and a left-out body
  # isn't there. A prototype comes along when kept code uses the name. One for an inline body in
  # another header comes along regardless, since it makes this file hold the external definition.
  def _carryable_prototypes(decls, has_body, referenced)
    keep = decls.reject { |d| Partials.static?( d.decorators ) or (has_body and Partials.inline?( d.decorators )) }
    keep = keep.select { |d| !has_body and Partials.foreign_inline?( d ) } unless referenced
    return _distinct( keep )
  end

  # Scans kept code for helper names, then each carried helper in turn, until nothing new is found.
  # Only a referenced helper is carried, so carrying never forces unused code to compile.
  # Returns every name the carried code references, which decides the prototypes it needs.
  def _plan_helpers(scan, c_module, impl, helpers)
    references = Set.new
    pending    = _kept_code( c_module, impl, scan.fallback )
    handled    = Set.new

    until pending.empty?
      referrer, names = pending.shift
      references.merge( names )
      pending.concat( _follow( scan, helpers, handled, referrer, names ) )
    end

    return references
  end

  # Carries each helper the names reach for the first time. Returns their bodies' references to scan next.
  def _follow(scan, helpers, handled, referrer, names)
    reached = helpers.select { |name, _| names.include?( name ) and !handled.include?( name ) }

    return reached.filter_map do |name, defs|
      handled << name
      carried = _carry_helper( scan, name, defs, referrer )
      [name, _body_references( carried )] if carried
    end
  end

  # Carries one referenced helper, or records why it can't be. Returns the carried definition.
  def _carry_helper(scan, name, defs, referrer)
    return nil if _helper_blocked?( scan, name, defs )

    helper = defs.first
    scan.plan.add_helper( _as_written( helper ), "helper: referenced by `#{referrer}`" )
    _distinct( scan.declared.fetch( name, [] ) ).each do |d|
      scan.plan.add_prototype( d, "prototype of helper `#{name}`" )
    end

    return helper
  end

  # A helper stays behind when its header can't be stood in for, or when fallback left two bodies
  def _helper_blocked?(scan, name, defs)
    # Without a guard the real header may arrive through another include, and its copy would collide
    unless scan.header_guarded
      scan.plan.skip( name, :unguarded_helper )
      return true
    end
    return false unless scan.fallback and _conflicting?( defs.map( &:code_block ) )

    scan.plan.skip( name, :helper_conflict )
    return true
  end

  # Built from the helper's own text, with any function-scope static promoted. Transforming it
  # would strip `static inline` and give the helper external linkage it never had.
  def _as_written(helper)
    return Partials.manufacture_function_definition(
      name: helper.name, signature: helper.signature, code_block: helper.code_block,
      source_filepath: helper.source_filepath, line_num: helper.line_num
    )
  end

  # Everything the implementation source compiles that could use a function, as
  # [referrer, Set of referenced names] pairs
  def _kept_code(c_module, impl, fallback)
    statements = _kept_statements( c_module, fallback ).map { |referrer, text| [referrer, _statement_references( text )] }
    return _kept_bodies( c_module, impl ) + statements
  end

  def _kept_bodies(c_module, impl)
    defined = c_module.function_definitions.to_h { |f| [f.name, f] }
    return Array( impl ).map { |f| [f.name, _body_references( defined.fetch( f.name ) )] }
  end

  # Variables and macro invocations the implementation source writes. Fallback can't expand
  # macros reliably, so there a macro definition's text counts too.
  def _kept_statements(c_module, fallback)
    variables = c_module.variable_declarations.reject( &:extern? )
    macros    = c_module.macro_invocations + (fallback ? c_module.macro_definitions : [])

    return variables.map { |v| [v.name, v.text] } + macros.map { |m| [m.text.strip, m.text] }
  end

  # The names a definition's body uses. Its own parameters and local variables only share a
  # name with any function, so they don't count.
  def _body_references(definition)
    code = _blank_non_code( _scan_text( definition ) )
    return _identifiers( code ) - _locals( code ) - _parameters( definition )
  end

  # The names a variable initializer or macro invocation uses
  def _statement_references(text)
    return _identifiers( _blank_non_code( text.to_s ) )
  end

  def _identifiers(code)
    return Set.new( code.gsub( C_MEMBER_ACCESS, ' ' ).gsub( C_TAG, ' ' ).scan( C_IDENTIFIER ) )
  end

  def _locals(code)
    return code.scan( C_LOCAL_DECLARATION ).filter_map { |type, name| name unless C_STATEMENT_KEYWORDS.include?( type ) }
  end

  # Every name in a definition's parameter list. Type names come along too, and those are never
  # function names, so taking them all away removes just the parameters.
  def _parameters(definition)
    signature = definition.signature.to_s
    start     = CExtractorFunctions.name_position( signature, definition.name.to_s )
    return [] if start.nil?

    return _parenthesized( signature, signature.index( '(', start ) ).scan( C_IDENTIFIER )
  end

  # The text from the parenthesis at `open` through the one that closes it
  def _parenthesized(text, open)
    steps = { '(' => 1, ')' => -1 }
    depth = 0
    close = (open...text.length).find { |i| (depth += steps.fetch( text[i], 0 )).zero? }

    return text[open..close].to_s
  end

  def _conflicting?(texts)
    return texts.map { |t| _normalized( t ) }.uniq.size > 1
  end

  # A body as the compiler sees it when the expanded copy has one
  def _scan_text(definition)
    return (definition.expanded_body || definition.body || definition.code_block).to_s
  end

  # Literals and comments become spaces, newlines kept. Neither can use a function however it reads.
  def _blank_non_code(text)
    return text.gsub( Partials::LITERAL_OR_COMMENT ) { |blanked| blanked.gsub( /[^\n]/, ' ' ) }
  end

  # The wanted names the text defines inline with external linkage, found in one pass. The text
  # breaks into runs at each `;` and brace. A run that ends in a parameter list just before a `{`
  # opens a definition. Each wanted name opening a parameter list there is judged by the words
  # ahead of it. One pass keeps the cost linear in a raw copy that holds every header the file
  # includes, however many names are wanted.
  def _inline_definitions(text, wanted)
    found   = Set.new
    scanner = StringScanner.new( text )
    start   = 0

    # Scanner positions count bytes, so each run is cut out by bytes
    while scanner.skip_until( /[;{}]/ )
      _definition_names( text.byteslice( start...(scanner.pos - 1) ), wanted, found ) if text.getbyte( scanner.pos - 1 ) == OPEN_BRACE
      start = scanner.pos
    end

    return found
  end

  # Adds each wanted name the run defines inline with external linkage. A name counts when the
  # words ahead of it in the run hold an inline specifier and no `static`. Words on a directive
  # line never count. One walk carries what the words so far have said, so a run that mentions
  # many names stays linear.
  def _definition_names(run, wanted, found)
    # Every inline specifier spells `inline`, so a run without it is passed over
    return unless run.include?( 'inline' ) and run.match?( /\)\s*\z/ )

    scanner = StringScanner.new( run )
    walk    = DefinitionWalk.new( directive: _directive_line?( scanner ), inline: false, static: false )
    _walk_word( walk, scanner, wanted, found ) while scanner.skip_until( /\n|[\w$]+/ )
  end

  # One word of a run, or the newline that starts its next line
  def _walk_word(walk, scanner, wanted, found)
    word = scanner.matched
    if word == "\n"
      walk.directive = _directive_line?( scanner )
      return
    end

    found << word if _defined_inline?( walk, scanner, wanted, word )
    return if walk.directive

    walk.inline ||= Partials.inline?( [word] )
    walk.static ||= Partials.static?( [word] )
  end

  # A wanted name opening a parameter list, after words that made the definition inline and not static
  def _defined_inline?(walk, scanner, wanted, word)
    return (walk.inline and !walk.static and wanted.include?( word ) and scanner.match?( /\s*\(/ ))
  end

  def _directive_line?(scanner)
    return !scanner.match?( DIRECTIVE_START ).nil?
  end

  def _helper?(definitions)
    return definitions.all? do |f|
      f.origin == :header and (Partials.static?( f.decorators ) or Partials.inline?( f.decorators ))
    end
  end

  # One of each prototype, comparing text with whitespace collapsed
  def _distinct(decls)
    return decls.uniq { |d| _normalized( d.signature ) }
  end

  def _normalized(text)
    return text.to_s.gsub( /\s+/, ' ' ).strip
  end

  # Stops the build on a definition the extractor read no name from. Every later step finds a
  # definition by its name. A declaration needs none, since it is written word for word and CMock
  # reads its own. Extraction reads raw bytes, so the signature is made printable first.
  def validate_function_names_readable(c_module, name, module_name)
    unnamed = c_module.function_definitions.find { |func| func.name.nil? }
    return if unnamed.nil?

    signature = _normalized( unnamed.signature ).dup.force_encoding( Encoding::UTF_8 ).scrub( '?' )
    raise CeedlingException.new( format( UNREADABLE_NAME_ERROR, partial: "#{name}::#{module_name}", declaration: signature ) )
  end

  # Validate that every function name in additions and subtractions exists in c_module.
  # Case-sensitive match; if a name matches case-insensitively but not exactly, raise
  # a specific case-mismatch exception.
  def validate_function_names_exist(c_module, config, name)
    known_exact = Set.new( c_module.function_definitions.map(&:name) )
    known_lower = Set.new( c_module.function_definitions.map { |f| f.name.downcase } )
    mod         = config.module

    {TEST: config.tests, MOCK: config.mocks}.each do |label, pf|
      (pf.additions + pf.subtractions).each do |func_name|
        next if known_exact.include?(func_name)

        if known_lower.include?(func_name.downcase)
          raise CeedlingException.new(
            "#{name}: #{label} Partial configuration for module '#{mod}' references function '#{func_name}' " \
            "which differs only by case from a real function name"
          )
        else
          raise CeedlingException.new(
            "#{name}: #{label} Partial configuration for module '#{mod}' references function '#{func_name}' which does not exist"
          )
        end
      end
    end
  end

  # Validate that no function name appears in both additions and subtractions of the
  # same tests or mocks entry.
  def validate_no_additions_subtractions_overlap(config, name)
    mod = config.module

    {TEST: config.tests, MOCK: config.mocks}.each do |label, pf|
      # Report the first overlap and abort, as above -- an `each` would imply
      # every offending function gets reported.
      overlap = Set.new(pf.additions) & Set.new(pf.subtractions)
      unless overlap.empty?
        raise CeedlingException.new(
          "#{name}: #{label} Partial configuration for module '#{mod}' ⏩️ Function '#{overlap.first}' should not be both added and subtracted"
        )
      end
    end
  end

  # Validate that subtractions match their type's own visibility classification.
  # For PUBLIC type: subtractions must be public functions.
  # For PRIVATE type: subtractions must be private functions.
  # Additions are not validated (same-visibility additions are redundant but harmless).
  # ACCUMULATE is skipped (no subtractions allowed, already enforced by extract_configs).
  def validate_additions_subtractions_visibility(c_module, config, name)
    func_map = c_module.function_definitions.each_with_object({}) { |f, h| h[f.name] = f }
    mod      = config.module

    {tests: config.tests, mocks: config.mocks}.each do |label, pf|
      next unless pf.type == PUBLIC || pf.type == PRIVATE

      subtraction_required_visibility = pf.type

      pf.subtractions.each do |func_name|
        func = func_map[func_name]
        unless @utils.matches_visibility?(func.decorators, subtraction_required_visibility)
          raise CeedlingException.new(
            "#{name}: Partial configuration for module '#{mod}': #{label} type is #{pf.type}, " \
            "so subtractions must be #{subtraction_required_visibility} functions, " \
            "but '#{func_name}' is not #{subtraction_required_visibility}"
          )
        end
      end
    end
  end

end