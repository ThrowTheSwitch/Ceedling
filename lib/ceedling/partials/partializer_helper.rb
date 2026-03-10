# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/exceptions'
require 'ceedling/array_patches' # Redundant `require` to ensure patching in test cases

class PartializerHelper

  constructor :partializer_parser, :partializer_utils, :file_finder, :preprocessinator_code_finder, :file_path_utils

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

  # 1. Filter functions by visibility (:private | :public)
  # 2. Transform functions to appropriate container (:impl | :interface) → `FunctionDefinition[]` or `FunctionDeclaration[]`
  def filter_and_transform_funcs(funcs, visibility, output_type)
    funcs.filter_map do |func|
      # List of decorators separated from signature (begining with return type)
      decorators, signature = @parser.parse_signature_decorators(func.signature, func.name)
      
      next unless @utils.matches_visibility?(decorators, visibility)
      
      @utils.transform_function(func, signature, output_type)
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
  def associate_function_line_numbers(name:, funcs:, filepath:)
    # File path of fully expanded preprocessor output
    _filepath = @file_path_utils.form_preprocessed_file_full_expansion_filepath( filepath, name )

    funcs.each do |func|
      line_num = @preprocessinator_code_finder.find_in_file( _filepath, func.code_block )
      # Set line number conditionally
      func.line_num = line_num unless line_num.nil?
      # Always set filepath
      func.source_filepath = filepath
    end
  end

  def tidy_functions(funcs)
    funcs.each do |func|
      code_block = func.code_block

      # Collapse any unnecessary newlines between closing paren and opening function bracket      
      code_block.gsub!( /\)(\n){2,}\{/, ")\n{" )
      # Collapse any unnecessary newlines between opening function bracket and code
      code_block.gsub!( /\{(\n){2,}/, "{\n" )
      # Collapse any unnecessary newlines between code and closing function bracket
      code_block.gsub!( /(\n){2,}\}/, "\n}" )
      # Collapse repeated blank lines
      code_block.gsub!( /(\h*\n){3,}/, "\n\n" )
    end
  end

end