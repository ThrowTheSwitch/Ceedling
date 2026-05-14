# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'set'
require 'rake' # .ext()
require 'ceedling/includes/includes'
require 'ceedling/partials/partials'
require 'ceedling/partials/partializer_runtime'
require 'ceedling/c_extractor/c_extractor'
require 'ceedling/c_extractor/c_extractor_constants'
require 'ceedling/c_extractor/c_extractor_types'
require 'ceedling/constants'

class Partializer

  include Partials

  constructor :partializer_helper, :file_finder, :c_extractor, :file_path_utils, :reportinator, :loginator

  def setup()
    # Alias
    @helper = @partializer_helper
  end

  def validate_config(c_module:, config:, name:)
    msg = @reportinator.generate_progress("Validating Partial config for '#{name}'")
    @loginator.log(msg, Verbosity::DEBUG)
    @helper.validate_function_names_exist(c_module, config, name)
    @helper.validate_no_additions_subtractions_overlap(config, name)
    @helper.validate_additions_subtractions_visibility(c_module, config, name)
  end

  def validate_extracted_functions(name:, partial:, impl:, interface:)
    # Validation is only meaningful and possible if both references are non-nil.
    return if impl.nil? || interface.nil?

    # Validation is only meaningful if both lists have content.
    return if impl.empty? || interface.empty?

    impl_names      = Set.new(impl.map(&:name))
    interface_names = Set.new(interface.map(&:name))

    msg = @reportinator.generate_module_progress(
      module_name: name,
      filename: partial,
      operation: 'Validating Partial functions for'
    )
    @loginator.log(msg, Verbosity::DEBUG)

    overlap = impl_names & interface_names
    overlap.each do |func_name|
      raise CeedlingException.new(
        "#{name}: Partial '#{partial}' ⏩️ Function '#{func_name}' cannot be both testable and mockable"
      )
    end
  end

  def populate_filepaths(configs)
    configs.each do |_module, config|
      # Every partial involves processing header files
      config.header.filepath = @file_finder.find_header_file(_module, :ignore)

      # Source file not needed only when mocking public functions exclusively
      unless !config.tests.present? && config.mocks.type == PUBLIC
        config.source.filepath = @file_finder.find_source_file(_module, :ignore)
      end
    end

    return configs
  end

  # When `test:` is provided, logs the resulting includes at OBNOXIOUS.
  def remap_implementation_header_includes(name:, includes:, partials:, test: nil)
    _includes = includes.clone()

    # Get list of all partialized module names
    partialized_modules = partials.keys

    # Remove includes for all partialized modules
    # Remove our own orginal name as well
    _includes = remove_matching_includes(
      includes: _includes,
      modules: ([name] + partialized_modules)
    )

    # Remove any duplicates
    Includes.sanitize!(_includes)

    @loginator.log_list(
      _includes,
      "Header includes to inject for testable Partial #{test}::#{name}",
      Verbosity::OBNOXIOUS
    ) if test

    return _includes
  end

  # When `test:` is provided, logs the resulting includes at OBNOXIOUS.
  def remap_implementation_source_includes(name:, includes:, partials:, test: nil)
    _includes = includes.clone()

    # Add implementation header
    _includes << UserInclude.new(
      @file_path_utils.form_partial_implementation_header_filename(name)
    )

    mockable_modules = []

    partials.each do |_module, config|
      # Remap mockable interface headers that will be injected into generated partial implementation
      if includes.any? { |include| include.filename.ext().downcase() == _module.downcase() }
        if [PUBLIC, PRIVATE].include?( config.mocks.type )
          # Insert mockable interface header from remapping of module name
          _includes << UserInclude.new(
            @file_path_utils.form_partial_interface_header_filename(_module)
          )
          # Remember the module for later removal of original header
          mockable_modules << _module
        end
      end
    end

    # Remove the original module header now that it's remapped to mockable interface
    # Remove our own orginal name as well
    _includes = remove_matching_includes(
      includes: _includes,
      modules: ([name] + mockable_modules)
    )

    # Remove any duplicates
    Includes.sanitize!(_includes)

    @loginator.log_list(
      _includes,
      "Source includes to inject for testable Partial #{test}::#{name}",
      Verbosity::OBNOXIOUS
    ) if test

    return _includes
  end

  # When `test:` is provided, logs the resulting includes at OBNOXIOUS.
  def remap_interface_header_includes(name:, includes:, partials:, test: nil)
    _includes = includes.clone()

    # Get list of all partialized module names
    partialized_modules = partials.keys

    # Remove includes for all partialized modules
    # Remove our own orginal name as well
    _includes = remove_matching_includes(
      includes: _includes,
      modules: ([name] + partialized_modules)
    )

    # Remove any duplicates
    Includes.sanitize!(_includes)

    @loginator.log_list(
      _includes,
      "Header includes to inject for mockable Partial #{test}::#{name}",
      Verbosity::OBNOXIOUS
    ) if test

    return _includes
  end

  # Extracts and combines C code contents from header and source files
  #
  # This method uses CExtractor to parse C files and extract their contents including
  # function definitions, function declarations, and variable declarations. If both
  # header and source files are provided, their contents are merged into a single
  # CModule structure.
  #
  # @param header_filepath [String, nil] Path to the header file to extract from.
  #   If nil, no header content is extracted.
  # @param source_filepath [String, nil] Path to the source file to extract from.
  #   If nil, no source content is extracted.
  #
  # @return [CExtractorTypes::CModule] A merged CModule containing all extracted contents
  #   from both files. The structure includes:
  #   - function_definitions: Array of function definitions with full implementations
  #   - function_declarations: Array of function declarations (prototypes)
  #   - variable_declarations: Array of variable declarations
  #
  # @note The method always starts with an empty CModule and merges in contents
  #   from any provided files using the CModule's + operator for combining structures.
  def extract_module_contents(name, config, fallback)
    # Array for CModule structs
    contents = [CExtractorTypes::CModule.new()]

    # Process the C module source and/or header associated with the Partial config
    [config.header, config.source].zip(['header', 'source']).each do |c_file, file_type|
      # Do nothing if there's no preprocessed filepath (e.g. no source only header for a Partial mock)
      next unless c_file.preprocessed_filepath

      c_module = @c_extractor.from_file( c_file.preprocessed_filepath )

      _log_module_contents(name, config.module, file_type, c_module)

      # Align extracted function definitions with line markers in preprocessor output.
      # This perfectly remaps functions found in expanded preprocessor output with 
      # original source location.
      # This routine depends on original, unaltered function definitions.
      @helper.associate_function_line_numbers(
        name: name,
        funcs: c_module.function_definitions,
        filepath: c_file.filepath,
        fallback: fallback
      )

      # 1. Find any function-scope static variable declarations.
      # 2. Replace them in function definitions with no-ops (for proper coverage reporting).
      # 3. Promote the function-scoped variables to be module-level variables.
      decls = @helper.extract_function_scope_static_vars(
        c_module.function_definitions,
        name: name, module_name: config.module, file_type: file_type
      )
      c_module.variable_declarations.concat(decls)
      c_module.element_sequence.concat(decls) unless decls.empty?

      contents << c_module
    end

    # Use `+` operator for CModule to merge everything
    contents = contents.reduce(&:+)

    return contents
  end

  # Returns Array<Partials::FunctionDefinition> for the testable partial implementation.
  #
  # Processes the `tests` PartialFunctions config against extracted C function definitions:
  #   PUBLIC     -- initial list is all non-private functions; additions inject named private functions
  #   PRIVATE    -- initial list is all private functions; additions inject named public functions
  #   ACCUMULATE -- initial list is empty; additions fill it entirely
  #   nil        -- returns nil
  # Subtractions remove named functions from the assembled list.
  # Any functions in mocks.additions are also removed from the final result.
  # Parameters are expected to be pre-validated (no unknown names, no overlap, etc.).
  #
  # @param test        [String] Test file name (for log messages)
  # @param partial     [String] Partial module name (for log messages)
  # @param definitions [Array<CFunctionDefinition>] Extracted function definitions
  # @param config      [PartializerConfig::Config] Full partial config for the module
  # @return [Array<Partials::FunctionDefinition>]
  def extract_implementation_functions(test:, partial:, definitions:, config:)
    pf = config.tests
    return nil if pf.type.nil?

    @loginator.log(
      "Extracting testable Partial functions for #{test}::#{partial}: " \
      "type=#{pf.type} additions=#{pf.additions} subtractions=#{pf.subtractions}",
      Verbosity::DEBUG
    )

    # Build initial list by visibility; ACCUMULATE yields []
    funcs = @helper.filter_and_transform_funcs(definitions, pf.type, :impl)

    # Additions: only search definitions — code_block required for impl transform
    pf.additions.each do |name|
      next if funcs.any? { |f| f.name == name }
      func = @helper.find_and_transform_func(
        name:            name,
        primary_funcs:   definitions,
        secondary_funcs: [],
        output_type:     :impl
      )
      funcs << func if func
    end

    # Subtractions: remove named functions from list
    result = @helper.subtract_funcs(funcs: funcs, names: pf.subtractions)
    if !funcs.empty? && result.empty?
      @loginator.log(
        "Partial #{test}::#{partial} ⏩️ Subtractions left no testable functions",
        Verbosity::COMPLAIN,
        LogLabels::NOTICE
      )
    end

    # Remove any functions explicitly claimed by the mock side
    result = @helper.subtract_funcs(funcs: result, names: config.mocks.additions)

    _log_impl_functions(test, partial, result)

    return result
  end

  # Returns Array<Partials::FunctionDeclaration> for the mockable partial interface.
  #
  # Processes the `mocks` PartialFunctions config against extracted C functions:
  #   PUBLIC     -- initial list is all non-private functions; additions inject named private functions
  #   PRIVATE    -- initial list is all private functions; additions inject named public functions
  #   ACCUMULATE -- initial list is empty; additions fill it entirely
  #   nil        -- returns nil
  # Subtractions remove named functions from the assembled list.
  # Any functions in tests.additions are also removed from the final result.
  # Parameters are expected to be pre-validated (no unknown names, no overlap, etc.).
  # Additions search definitions first, then declarations; only the first match is used.
  #
  # @param test         [String] Test file name (for log messages)
  # @param partial      [String] Partial module name (for log messages)
  # @param definitions  [Array<CFunctionDefinition>] Extracted function definitions
  # @param declarations [Array<CFunctionDeclaration>] Extracted function declarations
  # @param config       [PartializerConfig::Config] Full partial config for the module
  # @return [Array<Partials::FunctionDeclaration>]
  def extract_interface_functions(test:, partial:, definitions:, declarations:, config:)
    pf = config.mocks
    return nil if pf.type.nil?

    @loginator.log(
      "Extracting mockable Partial functions for #{test}::#{partial}: " \
      "type=#{pf.type} additions=#{pf.additions} subtractions=#{pf.subtractions}",
      Verbosity::DEBUG
    )

    # Build initial list by visibility; ACCUMULATE yields []
    funcs = @helper.filter_and_transform_funcs(definitions, pf.type, :interface)

    # Additions: search definitions first, then declarations
    pf.additions.each do |name|
      next if funcs.any? { |f| f.name == name }
      func = @helper.find_and_transform_func(
        name:            name,
        primary_funcs:   definitions,
        secondary_funcs: declarations,
        output_type:     :interface
      )
      funcs << func if func
    end

    # Subtractions: remove named functions from list
    result = @helper.subtract_funcs(funcs: funcs, names: pf.subtractions)
    if !funcs.empty? && result.empty?
      @loginator.log(
        "Partial #{test}::#{partial} ⏩️ Subtractions left no mockable signatures",
        Verbosity::COMPLAIN,
        LogLabels::NOTICE
      )
    end

    # Remove any functions explicitly claimed by the test side
    result = @helper.subtract_funcs(funcs: result, names: config.tests.additions)

    _log_interface_functions(test, partial, result)

    return result
  end

  private

  # Log all user-defined (non-function) C content extracted from a module's source/header at OBNOXIOUS level.
  # Covers the four categories that are injected into generated Partial files:
  # variable declarations, type definitions, macro definitions, and aggregate definitions
  # (structs, unions, enums not wrapped in a typedef).
  def _log_module_contents(name, module_name, source, contents)
    _vars = contents.variable_declarations.map { |v| "`#{v.text}`" }
    @loginator.log_list(
      _vars,
      "Variable declarations for Partial #{name}::#{module_name} from #{source}",
      Verbosity::OBNOXIOUS
    )

    _types = contents.type_definitions.map { |t| "`#{t.text}`" }
    @loginator.log_list(
      _types,
      "Type definitions for Partial #{name}::#{module_name} from #{source}",
      Verbosity::OBNOXIOUS
    )

    _macros = contents.macro_definitions.map { |m| "`#{m.text}`" }
    @loginator.log_list(
      _macros,
      "Macro definitions for Partial #{name}::#{module_name} from #{source}",
      Verbosity::OBNOXIOUS
    )

    _aggregates = contents.aggregate_definitions.map { |a| "`#{a.text}`" }
    @loginator.log_list(
      _aggregates,
      "Aggregate definitions (structs/unions/enums) for Partial #{name}::#{module_name} from #{source}",
      Verbosity::OBNOXIOUS
    )
  end

  # Log testable (implementation) functions at OBNOXIOUS level.
  def _log_impl_functions(test, partial, funcs)
    _funcs = funcs.nil? ? [] : funcs.map { |f| "`#{f.signature}`" }
    @loginator.log_list(
      _funcs,
      "Testable functions for Partial #{test}::#{partial}",
      Verbosity::OBNOXIOUS
    )
  end

  # Log mockable (interface) functions at OBNOXIOUS level.
  def _log_interface_functions(test, partial, funcs)
    _funcs = funcs.nil? ? [] : funcs.map { |f| "`#{f.signature}`" }
    @loginator.log_list(
      _funcs,
      "Mockable functions for Partial #{test}::#{partial}",
      Verbosity::OBNOXIOUS
    )
  end

  # Remove includes that match the given module names (case-insensitive)
  # Returns a new array with matching includes removed
  def remove_matching_includes(includes:, modules:)
    # Normalize module names to lowercase for comparison
    normalized_modules = modules.map(&:downcase)
    
    # Filter out includes (minus extension) that match any module name
    return includes.reject do |include|
      normalized_modules.include?(include.filename.ext().downcase())
    end
  end  
end