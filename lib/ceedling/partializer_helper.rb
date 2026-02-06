# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/c_extractinator'

class PartializerHelper

  constructor :partializer_parser, :partializer_utils

  def setup()
    # Aliases
    @utils = @partializer_utils
    @parser = @partializer_parser
  end

  def extract_module_functions(header_filepath:, source_filepath:)
    header_funcs = []
    source_funcs = []

    if header_filepath
      header_funcs = CExtractinator.from_file(header_filepath).extract_functions()
    end

    if source_filepath
      source_funcs = CExtractinator.from_file(source_filepath).extract_functions()
    end    

    return header_funcs + source_funcs
  end

  # Filter functions by visibility and transform to appropriate output type (implementation or interface)
  def filter_and_transform(funcs, visibility, output_type)
    funcs.filter_map do |func|
      decorators, signature = @parser.parse_signature_decorators(func.signature, func.name)
      
      next unless @utils.matches_visibility?(decorators, visibility)
      
      @utils.transform_function(func, signature, output_type)
    end
  end

end