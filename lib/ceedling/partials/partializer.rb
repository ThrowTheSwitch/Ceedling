# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'rake' # .ext()
require 'ceedling/includes/includes'
require 'ceedling/partials/partials'
require 'ceedling/partials/partializer_runtime'
require 'ceedling/c_extractor/c_extractor'
require 'ceedling/c_extractor/c_extractor_constants'
require 'ceedling/constants'

class Partializer

  include Partials

  constructor :partializer_helper, :file_finder, :c_extractor, :file_path_utils, :loginator

  def setup()
    # Alias
    @helper = @partializer_helper
  end

  def populate_filepaths(configs)
    configs.each do |_module, config|
      # Every partial involves processing header files
      config.header.filepath = @file_finder.find_header_file(_module, :ignore)

      # Source file not needed only when mocking public functions exclusively
      unless !config.tests.present? && config.mocks.types == [PUBLIC]
        config.source.filepath = @file_finder.find_source_file(_module, :ignore)
      end
    end

    return configs
  end

  # Ensure no original headers for the module being partialized
  def sanitize_includes(name:, includes:)    
    _includes = remove_matching_includes(includes: includes, modules: [name])
    Includes.sanitize!(_includes)
    return _includes
  end

  def remap_implementation_header_includes(name:, includes:, partials:)
    _includes = includes.clone()

    # Get list of all partialized module names
    partialized_modules = partials.keys
    
    # Remove includes for all partialized modules
    _includes = remove_matching_includes(includes: _includes, modules: partialized_modules)

    # Ensure original module header is not in the list and also remove any duplicate includes
    return sanitize_includes(name: name, includes: _includes)
  end

  def remap_implementation_source_includes(name:, includes:, partials:)
    _includes = includes.clone()

    # Add implementation header
    _includes << UserInclude.new(
      @file_path_utils.form_partial_implementation_header_filename(name)
    )

    mockable_modules = []

    partials.each do |_module, config|
      # Remap mockable interface headers that will be injected into generated partial implementation
      if includes.any? { |include| include.filename.ext().downcase() == _module.downcase() }
        if config.mocks.types.intersect?([PUBLIC, PRIVATE])
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
    _includes = remove_matching_includes(includes: _includes, modules: mockable_modules)

    # Ensure original module header is not in the list and remove any duplicates
    return sanitize_includes(name: name, includes: _includes)
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
  # @return [CExtractor::CModule] A merged CModule containing all extracted contents
  #   from both files. The structure includes:
  #   - function_definitions: Array of function definitions with full implementations
  #   - function_declarations: Array of function declarations (prototypes)
  #   - variable_declarations: Array of variable declarations
  #
  # @note The method always starts with an empty CModule and merges in contents
  #   from any provided files using the CModule's + operator for combining structures.
  def extract_module_contents(name, config, fallback)
    # Array for CModule structs
    contents = [CExtractor::CModule.new()]

    # Process the C module source and/or header associated with the Partial config
    [config.source, config.header].each do |c_file|
      # Do nothing if there's no preprocessed filepath (e.g. no source for Partial mock, only header)
      next unless c_file.preprocessed_filepath

      c_module = @c_extractor.from_file( c_file.preprocessed_filepath )

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
      decls = @helper.extract_function_scope_static_vars( c_module.function_definitions )
      @helper.collect_module_variables(c_module.variables, decls)

      contents << c_module
    end

    # Use `+` operator for CModule to merge everything
    return contents.reduce(&:+)
  end

  # Reconstructs function lists for partial implementation and interface generation
  #
  # This method processes extracted C module contents and separates functions into
  # two categories based on the partial configuration:
  # 1. Implementation functions - for testable partial implementations
  # 2. Interface functions - for mockable partial interfaces
  #
  # The method filters functions by visibility (public/private) and transforms them
  # into the appropriate format for code generation.
  #
  # @param contents [CExtractor::CModule] The extracted C module contents containing
  #   function definitions, declarations, and other code elements
  # @param config [PartialConfig] Configuration object specifying which partial types
  #   to generate. The config.types array may contain:
  #   - Partials::TEST_PUBLIC - Include public functions in implementation
  #   - Partials::TEST_PRIVATE - Include private functions in implementation
  #   - Partials::MOCK_PUBLIC - Include public functions in interface
  #   - Partials::MOCK_PRIVATE - Include private functions in interface
  #
  # @return [Array<(Array<FunctionDefinition>, Array<FunctionDeclaration>)>] for 
  #   consumption by `GeneratorPartials`.
  #   A two-element array containing:
  #   - impl: Array of FunctionDefinition objects for the partial implementation
  #   - interface: Array of FunctionDeclaration objects for the partial interface
  #
  # @raise [RuntimeError] If an unknown partial type is encountered in config.types
  #
  # @note The helper methods filter_and_transform_funcs handle the actual filtering
  #   by visibility and transformation between definition and declaration formats
  def reconstruct_functions(contents:, config:)    
    impl = []
    interface = []

    config.tests.types.each do |type|
      impl += @helper.filter_and_transform_funcs(contents.function_definitions, type, :impl)
    end

    config.mocks.types.each do |type|
      interface += @helper.filter_and_transform_funcs(contents.function_definitions, type, :interface)
    end
    
    # PartializerRuntime.raise_on_option(type)
 
    return impl, interface
  end

  def log_extracted_functions(test:, module_name:, impl:, interface:)
    # Get function signatures
    _impl = impl.map { |func| "`#{func.signature}`" }
    _interface = interface.map { |func| "`#{func.signature}`" }
    
    @loginator.log_list(
      _interface,
      "Mockable functions for Partial #{test}::#{module_name}",
      Verbosity::OBNOXIOUS
    )
    
    @loginator.log_list(
      _impl,
      "Testable functions for Partial #{test}::#{module_name}",
      Verbosity::OBNOXIOUS
    )
  end

  def log_extracted_variable_decls(test:, module_name:, decls:)
    _decls = decls.map { |v| "`#{v.declaration}`" }
    @loginator.log_list(
      _decls,
      "Variable declarations for Partial #{test}::#{module_name}",
      Verbosity::OBNOXIOUS
    )
  end

  def log_implementation_includes(test:, module_name:, label:, includes:)    
    @loginator.log_list(
      includes,
      "#{label} includes to inject for testable Partial #{test}::#{module_name}",
      Verbosity::OBNOXIOUS
    )
  end

  def log_interface_includes(test:, module_name:, includes:)    
    @loginator.log_list(
      includes,
      "Includes to inject for mockable Partial #{test}::#{module_name}",
      Verbosity::OBNOXIOUS
    )
  end
 
  private

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