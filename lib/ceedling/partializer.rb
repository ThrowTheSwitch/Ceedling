# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/c_extractinator'

class Partializer

  def test_partial?(type)
    return !(type.to_s.include?('mock'))
  end

  def extract_functions(header_filepath:, source_filepath:, **types)
    extractinator = CExtractinator.from_file(header_filepath)
    header_funcs = extractinator.extract_functions()

    extractinator = CExtractinator.from_file(source_filepath)
    source_funcs = extractinator.extract_functions()
    
    impl = []
    interface = []

    types.each do |type|
      case type
      when :test_public
        impl += filter_public_funcs(header_funcs)
        impl += filter_public_funcs(source_funcs)
      when :test_private
        impl += filter_private_funcs(header_funcs)
        impl += filter_private_funcs(source_funcs)
      when :mock_public
        interface += filter_public_funcs(source_funcs)
      when :mock_private
        interface += filter_private_funcs(source_funcs)
      end
    end

    return impl, interface
  end


end