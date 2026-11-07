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

  # A string or character literal, which can't reference a function however it reads
  C_LITERAL = /"(?:\\.|[^"\\\n])*"|'(?:\\.|[^'\\\n])*'/ unless const_defined?(:C_LITERAL, false)

  # The ways code names a function. A call, an address taken, and any identifier at all, which
  # a variable initializer or macro invocation may use to name a function it doesn't call.
  C_CALL       = /(?<!\w)([A-Za-z_]\w*)\s*\(/ unless const_defined?(:C_CALL, false)
  C_ADDRESS_OF = /(?<!&)&(?!&)\s*([A-Za-z_]\w*)/ unless const_defined?(:C_ADDRESS_OF, false)
  C_IDENTIFIER = /(?<!\w)[A-Za-z_]\w*/ unless const_defined?(:C_IDENTIFIER, false)

  # A struct or union member, which only shares a name with any function
  C_MEMBER_ACCESS = /(?:\.|->)\s*[A-Za-z_]\w*/ unless const_defined?(:C_MEMBER_ACCESS, false)

  # The names a carry plan decides by, grouped once per module
  CarryFacts = Struct.new( :selected, :defined, :declared, keyword_init: true ) unless const_defined?(:CarryFacts, false)

  # What the helper scan shares while it walks: the plan it fills and the facts that gate it
  CarryScan = Struct.new( :plan, :declared, :fallback, :header_guarded, keyword_init: true ) unless const_defined?(:CarryScan, false)


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
  # `FunctionDefinition` entries whose `code_block` cannot be located in the
  # preprocessor output are skipped -- `line_num` fields remain unset.
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

    if fallback
      msg = "Using fallback C function location search for #{filepath}"
      @loginator.log( msg, Verbosity::OBNOXIOUS, LogLabels::WARNING )

      funcs.each do |func|
        func.line_num = @utils.locate_function_in_source(
          code_block:  func.code_block,
          filepath:    filepath
        )
      end

    else
      funcs.each do |func|
        # Uses `locate_function_in_source` as an automatic fallback
        func.line_num = @utils.locate_function_via_preprocessed(
          code_block:            func.code_block,
          filepath:              filepath,
          preprocessed_filepath: preprocessed_filepath
        )
      end
    end

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
  # points at the user's own declaration. Callers pass the file's text, read once per file.
  # A declaration that can't be found keeps no line and is written without a #line.
  #
  # @param decls    [Array<CFunctionDeclaration>] Declarations extracted from one file, updated in place
  # @param filepath [String] Path of the original header or source file
  # @param text     [String] That file's full text
  def associate_declaration_line_numbers(decls:, filepath:, text:)
    decls.each do |decl|
      decl.source_filepath = filepath
      decl.line_num        = @utils.locate_declaration_in_text( signature: decl.signature, text: text )
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
        var_decls.each do |var|
          if var.decorators.any? { |d| CExtractorConstants::PRIVATE_KEYWORDS.include?(d) }
            _decls << var
          end
        end
      end

      # Group declarations by original statement.
      # Simple declarations (one var per unique original) and 
      # compound declarations (multiple vars sharing the same original, e.g. `static int a, b;`)
      # require different strategies to prevent the restored comment text from being found and
      # corrupted by a subsequent replace call.
      groups = _decls.group_by { |var| var.original.strip }

      groups.each do |_original, vars|
        # Pre-compute old/new names before any mutation of var.name
        old_names   = vars.map(&:name)
        new_names   = old_names.map { |n| "partial_#{func.name}_#{n}" }

        # Single placeholder per group — keyed on the first variable's name
        placeholder = "__CEEDLING_NOOP_#{func.name.upcase}_#{old_names.first.upcase}__"

        # Replace original declaration: one no-op per variable, single comment with placeholder.
        # Defer placeholder restoration until after ALL renames are complete so that
        # restored comment text cannot be found and re-processed by a subsequent replace.
        if vars.size > 1
          func.code_block = @utils.replace_compound_declaration_with_noops( func.code_block, _original, placeholder, vars.size )
          func.body       = @utils.replace_compound_declaration_with_noops( func.body,       _original, placeholder, vars.size )
        else
          func.code_block = @utils.replace_declaration_with_noop( func.code_block, _original, placeholder )
          func.body       = @utils.replace_declaration_with_noop( func.body,       _original, placeholder )
        end

        # Rename all variables' token-bounded references (shared logic for both cases)
        vars.zip( old_names, new_names ).each do |var, old_name, new_name|
          var.text        = @utils.rename_c_identifier( var.text,        old_name, new_name )
          var.name        = new_name
          func.code_block = @utils.rename_c_identifier( func.code_block, old_name, new_name )
          func.body       = @utils.rename_c_identifier( func.body,       old_name, new_name )
        end

        # Restore original declaration text in the single placeholder comment
        func.code_block = func.code_block.sub(placeholder) { _original }
        func.body       = func.body.sub(placeholder)       { _original }
      end

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
    expanded_module  = @c_extractor.from_file( full_expansion_filepath )
    expanded_by_name = expanded_module.function_definitions.each_with_object({}) { |f, h| h[f.name] = f }

    updated = []
    funcs.each do |func|
      expanded = expanded_by_name[func.name]
      next unless expanded

      func.signature          = expanded.signature
      func.decorators         = expanded.decorators
      func.signature_stripped = expanded.signature_stripped
      func.expanded_body      = expanded.body
      updated << func.name
    end

    entries = updated.map { |n| "`#{n}`" } + _reconcile_declarations( decls, expanded_module )

    @loginator.log_list(
      entries,
      "Updated signatures from full expansion for Partial #{name}::#{module_name} #{file_type}:",
      Verbosity::DEBUG
    ) unless entries.empty?
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

  # Decide what a Partial's implementation source carries beyond its selected functions.
  #
  # A module's code relied on more than the functions a test selects. It called functions
  # defined elsewhere through prototypes, and it called small static or inline helpers its
  # header defines. Each function name falls into one category:
  #   - selected to test or to mock: handled as before, nothing carried;
  #   - external, declared but defined nowhere in the module: every non-static prototype;
  #   - a header helper, a static or inline body in the header: the body and its prototypes,
  #     but only when kept code references it;
  #   - left out, any other unselected body: prototypes that are neither static nor inline.
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

    helpers    = facts.defined.select { |name, defs| !facts.selected.include?( name ) and _helper?( defs ) }
    scan       = CarryScan.new( plan: plan, declared: facts.declared, fallback: fallback, header_guarded: header_guarded )
    references = _plan_helpers( scan, c_module, impl, helpers )

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

  # The names a plan decides by: which the test selected, which have bodies, which have prototypes
  def _carry_facts(c_module, impl, interface)
    return CarryFacts.new(
      selected: Set.new( Array( impl ).map( &:name ) + Array( interface ).map( &:name ) ),
      defined:  c_module.function_definitions.group_by( &:name ),
      declared: c_module.function_declarations.group_by( &:name )
    )
  end

  # A selected name is written as before, and a helper's prototypes travel with its body
  def _prototype_candidate?(facts, name)
    return false if facts.selected.include?( name )

    return !(facts.defined.key?( name ) and _helper?( facts.defined[name] ))
  end

  def _plan_prototypes(plan, name, decls, has_body:, fallback:, referenced:)
    keep = _carryable_prototypes( decls, has_body, referenced )
    return if keep.empty?

    # Fallback may keep both sides of a conditional, and two different types for one name won't compile
    if fallback and _conflicting?( keep.map( &:signature_stripped ) )
      plan.skip( name, 'conflicting declarations under fallback preprocessing', :prototype_conflict )
      return
    end

    reason = has_body ? 'left out: body not selected' : 'external: no body in module'
    keep.each { |d| plan.add_prototype( d, reason ) }
  end

  # Never a static prototype. An inline prototype promises an inline body, and a left-out body
  # isn't there. A prototype comes along when kept code uses the name, except an inline one for a
  # body elsewhere: that prototype is what makes this file hold the external definition, used or not.
  def _carryable_prototypes(decls, has_body, referenced)
    keep = decls.reject { |d| _static?( d.decorators ) or (has_body and _inline?( d.decorators )) }
    keep = keep.select { |d| _inline?( d.decorators ) } unless referenced
    return keep.uniq { |d| _normalized( d.signature ) }
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
      [name, _body_references( _scan_text( carried ) )] if carried
    end
  end

  # Carries one referenced helper, or records why it can't be. Returns the carried definition.
  def _carry_helper(scan, name, defs, referrer)
    return nil if _helper_blocked?( scan, name, defs )

    helper = defs.first
    scan.plan.add_helper( _as_written( helper ), "helper: referenced by `#{referrer}`" )
    scan.declared.fetch( name, [] ).uniq { |d| _normalized( d.signature ) }.each do |d|
      scan.plan.add_prototype( d, "prototype of helper `#{name}`" )
    end

    return helper
  end

  # A helper stays behind when its header can't be stood in for, or when fallback left two bodies
  def _helper_blocked?(scan, name, defs)
    # Without a guard the real header may arrive through another include, and its copy would collide
    unless scan.header_guarded
      scan.plan.skip( name, 'module header has no include guard', :unguarded_helper )
      return true
    end
    return false unless scan.fallback and _conflicting?( defs.map( &:code_block ) )

    scan.plan.skip( name, 'more than one definition under fallback preprocessing', :helper_conflict )
    return true
  end

  # Built from the original text. Transforming it would strip `static inline` and give the
  # helper external linkage it never had.
  def _as_written(helper)
    return Partials.manufacture_function_definition(
      name: helper.name, signature: helper.signature, code_block: helper.code_block,
      source_filepath: helper.source_filepath, line_num: helper.line_num
    )
  end

  # Everything the implementation source compiles that could use a function, as
  # [referrer, Set of referenced names] pairs
  def _kept_code(c_module, impl, fallback)
    statements = _kept_statements( c_module, fallback ).map { |referrer, text| [referrer, _statement_references( text.to_s )] }
    return _kept_bodies( c_module, impl ) + statements
  end

  def _kept_bodies(c_module, impl)
    defined = c_module.function_definitions.to_h { |f| [f.name, f] }
    return Array( impl ).map { |f| [f.name, _body_references( defined[f.name] ? _scan_text( defined[f.name] ) : f.code_block.to_s )] }
  end

  # Variables and macro invocations the implementation source writes. Fallback can't expand
  # macros reliably, so there a macro definition's text counts too.
  def _kept_statements(c_module, fallback)
    variables = c_module.variable_declarations.reject { |v| v.decorators.include?( 'extern' ) }
    macros    = c_module.macro_invocations + (fallback ? c_module.macro_definitions : [])

    return variables.map { |v| [v.name, v.text] } + macros.map { |m| [m.text.strip, m.text] }
  end

  # The functions a body uses: every name it calls or takes the address of. A member access or a
  # local variable that merely shares a function's name doesn't count.
  def _body_references(text)
    code = _without_members( _blank_literals( text ) )
    return Set.new( code.scan( C_CALL ).flatten + code.scan( C_ADDRESS_OF ).flatten )
  end

  # A variable initializer or macro invocation names a function without calling it, as in a table
  # of handlers, so any identifier there counts
  def _statement_references(text)
    return Set.new( _without_members( _blank_literals( text ) ).scan( C_IDENTIFIER ) )
  end

  def _without_members(code)
    return code.gsub( C_MEMBER_ACCESS, ' ' )
  end

  def _conflicting?(texts)
    return texts.map { |t| _normalized( t ) }.uniq.size > 1
  end

  # A body as the compiler sees it when the expanded copy has one
  def _scan_text(definition)
    return (definition.expanded_body || definition.body || definition.code_block).to_s
  end

  def _blank_literals(text)
    return text.gsub( C_LITERAL ) { |literal| ' ' * literal.length }
  end

  def _helper?(definitions)
    return definitions.all? do |f|
      f.origin == :header and (_static?( f.decorators ) or _inline?( f.decorators ))
    end
  end

  def _static?(decorators)
    return decorators.include?( 'static' )
  end

  def _inline?(decorators)
    return decorators.any? { |d| d != 'static' and CExtractorConstants::PRIVATE_KEYWORDS.include?( d ) }
  end

  def _normalized(text)
    return text.to_s.gsub( /\s+/, ' ' ).strip
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