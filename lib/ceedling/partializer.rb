# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/c_extractinator'
require 'ceedling/partials'
require 'ceedling/constants'

class Partializer

  PRIVATE_KEYWORDS = ['static', 'inline', '__inline', '__inline__']

  constructor :partializer_helper

  def setup()
    # Alias
    @helper = @partializer_helper
  end

  def remap_includes(includes:, remapping:)
    _includes = []

    includes.each do |include|
      _include = include.ext('')
      # Look up the include as a module name in the mapping
      if remapping[_include]
        # Replace the include with the generated partial header
        _includes << remapping[_include] + EXTENSION_CORE_HEADER
      else
        _includes << include
      end
    end

    return _includes
  end

  # Returns FunctionDefinition[], FunctionDeclaration[] for consumption by `GeneratorPartials`
  # TODO: Refactor for unit testing
  # TODO: Handle source paths and line numbers for coverage reporting
  def extract_functions(header_filepath:, source_filepath:, types:)
    header_funcs = []
    source_funcs = []

    if header_filepath
      # ExtractedFunction[]
      header_funcs = CExtractinator.from_file(header_filepath).extract_functions()
    end

    if source_filepath
      # ExtractedFunction[]
      source_funcs = CExtractinator.from_file(source_filepath).extract_functions()
    end
    
    impl = []
    interface = []

    types.each do |type|
      case type
      when :test_public
        impl += filter_public_funcs_impl(header_funcs)
        impl += filter_public_funcs_impl(source_funcs)
      when :test_private
        impl += filter_private_funcs_impl(header_funcs)
        impl += filter_private_funcs_impl(source_funcs)
      when :mock_public
        interface += filter_public_funcs_interface(header_funcs)
        interface += filter_public_funcs_interface(source_funcs)
      when :mock_private
        interface += filter_private_funcs_interface(header_funcs)
        interface += filter_private_funcs_interface(source_funcs)
      end
    end

    return impl, interface
  end

  # TODO: Refactor for common code
  def filter_public_funcs_impl(funcs)
    _funcs = []

    funcs.each do |func|
      decorators, signature = @helper.parse_signature_decorators(func.signature, func.name)
      if @helper.is_function_public?(decorators)
        _funcs << Partials.manufacture_function_definition_struct(
          signature: signature,
          # TODO: Handle preserving whitespace between signature and body
          code_block: signature + "\n" + func.body
        )
      end
    end

    return _funcs
  end

  def filter_private_funcs_impl(funcs)
    _funcs = []

    funcs.each do |func|
      decorators, signature = @helper.parse_signature_decorators(func.signature, func.name)
      if @helper.is_function_private?(decorators)
        _funcs << Partials.manufacture_function_definition_struct(
          signature: signature,
          # TODO: Handle preserving whitespace between signature and body
          code_block: signature + "\n" + func.body
        )
      end
    end
    
    return _funcs    
  end

  def filter_public_funcs_interface(funcs)
    _funcs = []

    funcs.each do |func|
      decorators, signature = @helper.parse_signature_decorators(func.signature, func.name)
      if @helper.is_function_public?(decorators)
        _funcs << Partials.manufacture_function_declaration_struct(
          signature: signature,
        )
      end
    end

    return _funcs
  end

  def filter_private_funcs_interface(funcs)
    _funcs = []

    funcs.each do |func|
      decorators, signature = @helper.parse_signature_decorators(func.signature, func.name)
      if @helper.is_function_private?(decorators)
        _funcs << Partials.manufacture_function_declaration_struct(
          signature: signature,
        )
      end
    end

    return _funcs
  end

end