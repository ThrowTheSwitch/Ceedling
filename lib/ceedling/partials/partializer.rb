# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'rake' # .ext()
require 'ceedling/partials/partials'
require 'ceedling/partials/partializer_runtime'
require 'ceedling/partials/partializer_constants'
require 'ceedling/c_extractor/c_extractor'
require 'ceedling/constants'

class Partializer
  include PartializerConstants

  constructor :partializer_helper, :file_path_utils, :loginator

  def setup()
    # Alias
    @helper = @partializer_helper
  end

  def assemble_configs(test_context_configs:)
    # A list of single entry hashes associating a module name with a Partial type
    return {} if test_context_configs.empty?

    # Delegate config creation to helper
    configs = @helper.manufacture_partial_configs(test_context_configs)
    
    # Delegate type collection and processing to helper
    @helper.config_collect_partial_types(test_context_configs, configs)
    
    # Delegate validation to helper
    @helper.validate_partial_configs(configs)
    
    # Delegate file finding to helper
    @helper.config_populate_filepaths(configs)
    
    return configs
  end

  # Ensure no original headers for the module being paritalized
  def sanitize_includes(name:, includes:)    
    _includes = remove_matching_includes(includes: includes, modules: [name])
    return _includes.uniq()
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
    _includes << @file_path_utils.form_partial_implementation_header_filename(name)

    mockable_modules = []

    partials.each do |_module, config|
      # Remap mockable interface headers that will be injected into generated partial implementation
      if includes.any? { |include| include.ext().downcase() == _module.downcase() }
        if config.types.intersect?([Partials::MOCK_PUBLIC, Partials::MOCK_PRIVATE])
          # Insert mockable interface header from remapping of module name
          _includes << @file_path_utils.form_partial_interface_header_filename(_module)
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

  def extract_module_contents(header_filepath:, source_filepath:)
    # Array for CModule structs
    contents = [CExtractor::CModule.new()]

    if header_filepath
      contents << CExtractor.from_file(header_filepath).extract_contents()
    end

    if source_filepath
      contents << CExtractor.from_file(source_filepath).extract_contents()
    end    

    return contents.reduce(&:+)
  end

  # Returns FunctionDefinition[], FunctionDeclaration[] for consumption by `GeneratorPartials`
  # TODO: Handle source paths and line numbers for coverage reporting
  def reconstruct_functions(contents:, types:)    
    impl = []
    interface = []

    types.each do |type|
      case type
      when Partials::TEST_PUBLIC
        impl += @helper.filter_and_transform_funcs(contents.function_definitions, :public, :impl)
      when Partials::TEST_PRIVATE
        impl += @helper.filter_and_transform_funcs(contents.function_definitions, :private, :impl)
      when Partials::MOCK_PUBLIC
        interface += @helper.filter_and_transform_funcs(contents.function_definitions, :public, :interface)
      when Partials::MOCK_PRIVATE
        interface += @helper.filter_and_transform_funcs(contents.function_definitions, :private, :interface)
      else
        PartializerRuntime.raise_on_option(type)
      end
    end

    return impl, interface
  end

  def reconstruct_variables(variables:)
    # Remove all keywords from type contained in PRIVATE_KEYWORDS and TYPE_QUALIFIER_KEYWORDS
    return variables.map do |declaration|
      # Skip empty string
      next declaration if declaration.empty?

      # Split on assignment operator to preserve keywords in initialization values
      parts = declaration.split('=', 2)
      
      # Remove keywords only from the declaration part (before '=')
      cleaned_declaration = parts[0].dup
      (PRIVATE_KEYWORDS + TYPE_QUALIFIER_KEYWORDS).each do |keyword|
        cleaned_declaration.gsub!(/\b#{Regexp.escape(keyword)}\b/, '')
      end
      cleaned_declaration = cleaned_declaration.strip.squeeze(' ')
      
      # Rejoin with initialization value if it exists
      if parts.length > 1
        cleaned_declaration += (' = ' + parts[1].strip.squeeze(' '))
      end

      cleaned_declaration
    end     
  end

  def log_extracted_functions(test:, module_name:, impl:, interface:)
    # Get function signatures
    _impl = impl.map { |func| "`#{func.signature}`" }
    _interface = interface.map { |func| "`#{func.signature}`" }
    
    @loginator.log_list(
      _impl,
      "Mockable functions for Partial #{test}::#{module_name}",
      Verbosity::OBNOXIOUS
    )
    
    @loginator.log_list(
      _interface,
      "Testable functions for Partial #{test}::#{module_name}",
      Verbosity::OBNOXIOUS
    )
  end

  def log_extracted_variable_decls(test:, module_name:, decls:)
    @loginator.log_list(
      decls,
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
    
    # Filter out includes whose extension (without dot) matches any module name
    return includes.reject do |include|
      normalized_modules.include?(include.ext().downcase())
    end
  end  
end