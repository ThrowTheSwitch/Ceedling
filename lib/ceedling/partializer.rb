require 'ceedling/c_extractinator'

class Partializer

  def test_partial?(type)
    return !(type.to_s.include?('mock'))
  end

  def extract_public_functions(header_filepath:, source_filepath:)
    extractinator = CExtractinator.from_file(header_filepath)
    funcs = extractinator.extract_functions()

    extractinator = CExtractinator.from_file(source_filepath)
    funcs += extractinator.extract_functions()

    return funcs
  end

end