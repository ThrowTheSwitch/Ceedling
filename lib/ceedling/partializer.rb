# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'rake' # .ext()
require 'ceedling/array_patches' # Redundant `require` to ensure patching in test cases
require 'ceedling/partials'
require 'ceedling/constants'

class Partializer

  PRIVATE_KEYWORDS = ['static', 'inline', '__inline', '__inline__']

  constructor :partializer_helper, :file_path_utils, :file_finder

  def setup()
    # Alias
    @helper = @partializer_helper
  end

  def assemble_configs(test_context_configs:)
    configs = {}
    return {} if test_context_configs.empty?

    # Each entry in `test_context_configs` is a single key/value pair of module name and partial type

    # Create data structures for each module
    test_context_configs.each do |context_config|
      # Get the partial module name (no filename extension)
      _module = context_config.values.first

      # Instantiate the partial configuration if it doesn't exist yet
      unless configs.has_key?(_module)
        configs[_module] = Partials.manufacture_config(module_name: _module)
      end
    end

    # Collect from test context the partial types associated with each module to be partialized
    test_context_configs.each do |context_config|
      _module = context_config.values.first
      type = context_config.keys.first

      # Gather all the types associated with a module.
      # Sanitization happens in a later step.
      case type
      # Private test partials logically necessitate a configuration to public as well.
      # Add public test partials to ensure proper processing later.
      when Partials::TEST_PRIVATE
        configs[_module].types += [type, Partials::TEST_PUBLIC]
      # For all other partial types, simply add to the list
      else
        configs[_module].types << type
      end
    end

    # Housekeeping and validation of the final set of partial configurations we are building up
    configs.each do |_module, config|
      # Ensure no duplicate partial types for a given module
      config.types.uniq!

      # Basic collision validation
      if config.types.overlap?([Partials::TEST_PUBLIC, Partials::MOCK_PUBLIC])
        raise CeedlingException.new("Partial for module '#{_module}' cannot both test and mock public functions")
      end

      # Basic collision validation
      if config.types.overlap?([Partials::TEST_PRIVATE, Partials::MOCK_PRIVATE])
        raise CeedlingException.new("Partial for module '#{_module}' cannot both test and mock private functions")
      end
    end

    # Collect header and source files needed for each partial configuration
    configs.each do |_module, config|
      # Every partial type involves processing header files
      config.header.filepath = @file_finder.find_header_file(_module, :ignore)

      # Test partial types involve processing source files
      if config.types.intersect?([Partials::TEST_PUBLIC, Partials::TEST_PRIVATE])
        config.source.filepath = @file_finder.find_source_file(_module, :ignore)
      end
    end

    return configs
  end

  # Ensure no original headers for the module being paritalized
  def sanitize_includes(name:, includes:)    
    _includes = includes.reject {|include| include.ext() == name}
    return _includes.uniq()
  end

  def remap_implementation_header_includes(name:, includes:, partials:)
    _includes = includes.clone()

    partials.each do |_module, _|
      # Remove any includes for modules that are being paritalized
      _includes.delete_if { |include| include.ext() == _module }
    end

    # Ensure original module header is not in the list and remove any duplicates
    return sanitize_includes(name: name, includes: _includes)
  end

  def remap_implementation_source_includes(name:, includes:, partials:)
    _includes = includes.clone()

    # Add implementation header
    _includes << @file_path_utils.form_partial_implementation_header_filename(name)

    partials.each do |_module, config|
      # Remap mockable interface headers that will be injected into generated partial implementation
      if includes.any? { |include| include.ext() == _module }
        if config.types.intersect?([Partials::MOCK_PUBLIC, Partials::MOCK_PRIVATE])
          # Insert mockable interface header from remapping of module name
          _includes << @file_path_utils.form_partial_interface_header_filename(_module)
          # Remove the original module header now that it's remapped to mockable interface
          _includes.delete_if { |include| include.ext() == _module }
        end
      end
    end

    # Ensure original module header is not in the list and remove any duplicates
    return sanitize_includes(name: name, includes: _includes)
  end

  # Returns FunctionDefinition[], FunctionDeclaration[] for consumption by `GeneratorPartials`
  # TODO: Handle source paths and line numbers for coverage reporting
  def extract_functions(header_filepath:, source_filepath:, types:)    
    impl = []
    interface = []

    funcs = @helper.extract_module_functions(
      header_filepath: header_filepath,
      source_filepath: source_filepath
    )

    types.each do |type|
      case type
      when Partials::TEST_PUBLIC
        impl += filter_and_transform(funcs, :public, :impl)
      when Partials::TEST_PRIVATE
        impl += filter_and_transform(funcs, :private, :impl)
      when Partials::MOCK_PUBLIC
        interface += filter_and_transform(funcs, :public, :interface)
      when Partials::MOCK_PRIVATE
        interface += filter_and_transform(funcs, :private, :interface)
      else
        raise ArgumentError, "Invalid Partial type `:#{type}`"
      end
    end

    return impl, interface
  end

  private

  # Filter functions by visibility and transform to appropriate output type
  def filter_and_transform(funcs, visibility, output_type)
    funcs.filter_map do |func|
      decorators, signature = @helper.parse_signature_decorators(func.signature, func.name)
      
      next unless @helper.matches_visibility?(decorators, visibility)
      
      transform_function(func, signature, output_type)
    end
  end

  # Transform function to appropriate output format
  def transform_function(func, signature, output_type)
    case output_type
    when :impl
      Partials.manufacture_function_definition(
        signature: signature,
        # TODO: Handle preserving whitespace between signature and body
        code_block: signature + "\n" + func.body
      )
    when :interface
      Partials.manufacture_function_declaration(
        signature: signature
      )
    else
      raise ArgumentError, "Invalid output_type: #{output_type}"
    end
  end

end