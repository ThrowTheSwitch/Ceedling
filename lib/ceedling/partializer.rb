# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'rake' # .ext()
require 'ceedling/array_patches' # Redundant `require` to ensure patching in test cases
require 'ceedling/partials'
require 'ceedling/partializer_runtime'
require 'ceedling/constants'

class Partializer

  constructor :partializer_helper, :file_path_utils, :file_finder

  def setup()
    # Alias
    @helper = @partializer_helper
  end

  def assemble_configs(test_context_configs:)
    return {} if test_context_configs.empty?

    # Delegate config creation to helper
    configs = @helper.manufacture_partial_configs(test_context_configs)
    
    # Delegate type collection and processing to helper
    @helper.config_collect_partial_types(test_context_configs, configs)
    
    # Delegate validation to helper
    @helper.validate_partial_configs(configs)
    
    # Delegate file finding to helper
    @helper.config_populate_filepaths(configs, @file_finder)
    
    return configs
  end

  # Ensure no original headers for the module being paritalized
  def sanitize_includes(name:, includes:)    
    _includes = includes.reject {|include| include.ext().downcase() == name.downcase()}
    return _includes.uniq()
  end

  def remap_implementation_header_includes(name:, includes:, partials:)
    _includes = includes.clone()

    partials.each do |_module, _|
      # Remove any includes for modules that are being paritalized
      _includes.delete_if { |include| include.ext().downcase() == _module.downcase() }
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
      if includes.any? { |include| include.ext().downcase() == _module.downcase() }
        if config.types.intersect?([Partials::MOCK_PUBLIC, Partials::MOCK_PRIVATE])
          # Insert mockable interface header from remapping of module name
          _includes << @file_path_utils.form_partial_interface_header_filename(_module)
          # Remove the original module header now that it's remapped to mockable interface
          _includes.delete_if { |include| include.ext().downcase() == _module.downcase() }
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
        impl += @helper.filter_and_transform(funcs, :public, :impl)
      when Partials::TEST_PRIVATE
        impl += @helper.filter_and_transform(funcs, :private, :impl)
      when Partials::MOCK_PUBLIC
        interface += @helper.filter_and_transform(funcs, :public, :interface)
      when Partials::MOCK_PRIVATE
        interface += @helper.filter_and_transform(funcs, :private, :interface)
      else
        PartializerRuntime.raise_on_option(type)
      end
    end

    return impl, interface
  end

end