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

  constructor :partializer_helper, :file_path_utils

  def setup()
    # Alias
    @helper = @partializer_helper
  end

  # Ensure no original headers for the module being paritalized
  def sanitize_includes(name:, includes:)    
    _includes = includes.reject {|include| include.ext() == name}
    return _includes.uniq()
  end

  def remap_implementation_header_includes(name:, includes:, partials:)
    _includes = includes.clone()

    partials.each do |_, details|
      details.each do |_module, config|
        if includes.any? { |include| include.ext() == _module }
          if config[:type].intersect?([:mock_public, :mock_private])
            # Remove the original module header if it will be mockable interface
            _includes.delete_if { |include| include.ext() == _module }
          end
        end
      end
    end

    # Ensure original module header is not in the list and remove any duplicates
    return sanitize_includes(name: name, includes: _includes)
  end

  def remap_implementation_source_includes(name:, includes:, partials:)
    _includes = includes.clone()

    # Add implementation header
    _includes << @file_path_utils.form_partial_implementation_header_filename(name)

    partials.each do |_, details|
      details.each do |_module, config|
        # Remap mockable interface headers for implementation
        if includes.any? { |include| include.ext() == _module }
          if config[:type].intersect?([:mock_public, :mock_private])
            # Insert mockable interface header from remapping of module name
            _includes << @file_path_utils.form_partial_interface_header_filename(_module)
            # Remove the original module header remapped to mockable interface
            _includes.delete_if { |include| include.ext() == _module }
          end
        end
      end
    end

    # Ensure original module header is not in the list and remove any duplicates
    return sanitize_includes(name: name, includes: _includes)
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