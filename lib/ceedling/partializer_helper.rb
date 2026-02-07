# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/c_extractinator'
require 'ceedling/array_patches' # Redundant `require` to ensure patching in test cases

class PartializerHelper

  constructor :partializer_parser, :partializer_utils, :file_finder

  def setup()
    # Aliases
    @utils = @partializer_utils
    @parser = @partializer_parser
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
      
      # Only test partial types involve processing source files
      if config.types.intersect?([Partials::TEST_PUBLIC, Partials::TEST_PRIVATE])
        config.source.filepath = @file_finder.find_source_file(_module, :ignore)
      end
    end
  end

  def extract_module_functions(header_filepath:, source_filepath:)
    header_funcs = []
    source_funcs = []

    if header_filepath
      header_funcs = CExtractinator.from_file(header_filepath).extract_contents()
    end

    if source_filepath
      source_funcs = CExtractinator.from_file(source_filepath).extract_contents()
    end    

    return header_funcs + source_funcs
  end

  # 1. Filter functions by visibility (:private | :public)
  # 2. Transform functions to appropriate container (:impl | :interface) → `FunctionDefinition[]` or `FunctionDeclaration[]`
  def filter_and_transform(funcs, visibility, output_type)
    funcs.filter_map do |func|
      # List of decorators seperated from signature (begining with return type)
      decorators, signature = @parser.parse_signature_decorators(func.signature, func.name)
      
      next unless @utils.matches_visibility?(decorators, visibility)
      
      @utils.transform_function(func, signature, output_type)
    end
  end

end