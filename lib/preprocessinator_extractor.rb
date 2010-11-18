

class PreprocessinatorExtractor
  
  constructor :file_wrapper

  # extract from cpp-processed file only content of file we care about
  def extract_base_file_from_preprocessed_expansion(filepath)
    contents = []
    extract = false

    @file_wrapper.readlines(filepath).each do |line|
      if (extract)
        if (line =~ /^#/)
          extract = false
        else
          contents << line
        end
      end
      # extract = true if (line =~ /^#.*#{Regexp.escape(File.basename(filepath))}/)
      extract = true if (line =~ /^#.*(\s|\/|\\|\")#{Regexp.escape(File.basename(filepath))}/)
    end

    return contents
  end

end
