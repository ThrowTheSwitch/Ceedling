# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/exceptions'
require 'ceedling/array_patches' # Redundant `require` to ensure patching in test cases
require 'ceedling/c_extractor/c_extractor_declarations'
require 'ceedling/c_extractor/c_extractor_constants'
require 'strscan'

class PartializerHelper

  constructor(
    :partializer_utils,
    :file_finder,
    :c_extractor_declarations,
    :file_path_utils,
    :loginator
  )

  def setup()
    # Aliases
    @utils = @partializer_utils
    @declaration_extractor = @c_extractor_declarations
  end

  def manufacture_partial_configs(test_context_configs)
    configs = {}
    
    test_context_configs.each do |context_config|
      _module = context_config.values.first
      
      # Build up a hash that contains a complete list of all modules to be partialized
      # Skip unnecessary duplication
      unless configs.has_key?(_module)
        configs[_module] = Partials.manufacture_config(module_name: _module)
      end
    end
    
    return configs
  end

  def config_collect_partial_types(test_context_configs, configs)
    test_context_configs.each do |context_config|
      _module = context_config.values.first
      type = context_config.keys.first
      
      case type
      # To support simplicity of partials generation, enforce the logical coherence of public and private tests.
      # If private functions are to be exposed for test cases, they are merely added to public functions to be tested.
      when Partials::TEST_PRIVATE
        configs[_module].types += [type, Partials::TEST_PUBLIC]
      else
        configs[_module].types << type
      end
    end
    
    # Remove duplicates
    configs.each { |_, config| config.types.uniq! }
  end

  def validate_partial_configs(configs)
    configs.each do |_module, config|
      if config.types.overlap?([Partials::TEST_PUBLIC, Partials::MOCK_PUBLIC])
        raise CeedlingException.new("Partial for module '#{_module}' cannot both test and mock public functions")
      end
      
      if config.types.overlap?([Partials::TEST_PRIVATE, Partials::MOCK_PRIVATE])
        raise CeedlingException.new("Partial for module '#{_module}' cannot both test and mock private functions")
      end
    end
  end

  def config_populate_filepaths(configs)
    configs.each do |_module, config|
      # Every partial type involves processing header files
      config.header.filepath = @file_finder.find_header_file(_module, :ignore)
      
      # Only these partial types involve processing source files
      if config.types.intersect?([Partials::TEST_PUBLIC, Partials::TEST_PRIVATE, Partials::MOCK_PRIVATE])
        config.source.filepath = @file_finder.find_source_file(_module, :ignore)
      end
    end
  end

  # 1. Filter functions by visibility (:private | :public)
  # 2. Transform functions to appropriate container (:impl | :interface) → `FunctionDefinition[]` or `FunctionDeclaration[]`
  def filter_and_transform_funcs(funcs, visibility, output_type)
    funcs.filter_map do |func|
      next unless @utils.matches_visibility?(func.decorators, visibility)

      @utils.transform_function(func, func.signature_stripped, output_type)
    end
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
    preprocessed_filepath = @file_path_utils.form_preprocessed_file_directives_only_filepath( filepath, name )

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

    header = "Found functions at line numbers in #{filepath}"
    @loginator.log_list( @utils.format_line_number_list( funcs ), header, Verbosity::DEBUG )
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
  # @param funcs [Array<CFunctionDefinition>] Function definitions to scan. Each matched
  #   function's `code_block` and `body` fields are mutated in place.
  #
  # @return [Array<CVariableDeclaration>] All function-scoped static variable declarations
  #   found across all supplied functions, suitable for emission at module scope.
  def extract_function_scope_static_vars(funcs)
    decls = []

    # Process each function definition looking for function-scoped static variables.
    # If found, collect them and remove from function `body` and `code_block`.
    funcs.each do |func|
      # Remove containing brackets of function body
      func_body = func.body.dup
      func_body.delete_prefix!( '{' )
      func_body.delete_prefix!( '}' )

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
      # Simple declarations (one var per unique original) and compound declarations
      # (multiple vars sharing the same original, e.g. `static int a, b;`) require
      # different strategies to prevent the restored comment text from being found and
      # corrupted by a subsequent replace call.
      groups = _decls.group_by { |var| var.original.strip }

      groups.each do |_original, vars|
        # Pre-compute old names, new names, and unique placeholders before any mutation of var.name
        old_names    = vars.map(&:name)
        new_names    = old_names.map { |n| "partial_#{func.name}_#{n}" }
        placeholders = old_names.map { |n| "__CEEDLING_NOOP_#{func.name.upcase}_#{n.upcase}__" }

        if vars.size > 1
          # Compound statement: replace original ONCE with one no-op per variable.
          # Defer ALL placeholder restoration until after ALL renames are complete so that
          # restored comment text cannot be found and re-processed by a subsequent replace.
          func.code_block = @utils.replace_compound_declaration_with_noops( func.code_block, _original, placeholders )
          func.body       = @utils.replace_compound_declaration_with_noops( func.body,       _original, placeholders )

          vars.zip( old_names, new_names ).each do |var, old_name, new_name|
            var.declaration = @utils.rename_c_identifier( var.declaration, old_name, new_name )
            var.name        = new_name
            func.code_block = @utils.rename_c_identifier( func.code_block, old_name, new_name )
            func.body       = @utils.rename_c_identifier( func.body,       old_name, new_name )
          end

          placeholders.each do |ph|
            func.code_block = func.code_block.sub(ph) { _original }
            func.body       = func.body.sub(ph)       { _original }
          end

        else
          # Simple single-variable declaration: original interleaved approach is safe
          # because no other var shares this original statement.
          var         = vars.first
          old_name    = old_names.first
          new_name    = new_names.first
          placeholder = placeholders.first

          func.code_block = @utils.replace_declaration_with_noop( func.code_block, _original, placeholder )
          func.body       = @utils.replace_declaration_with_noop( func.body,       _original, placeholder )

          var.declaration = @utils.rename_c_identifier( var.declaration, old_name, new_name )
          var.name        = new_name

          func.code_block = @utils.rename_c_identifier( func.code_block, old_name, new_name )
          func.body       = @utils.rename_c_identifier( func.body,       old_name, new_name )

          func.code_block = func.code_block.sub(placeholder) { _original }
          func.body       = func.body.sub(placeholder)       { _original }
        end
      end

      decls += _decls
    end

    return decls
  end

  def collect_module_variables(existing, new)
    existing.concat( new )
  end

end