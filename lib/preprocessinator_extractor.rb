

class PreprocessinatorExtractor
  
  constructor :file_wrapper

  # extract from cpp-processed file only content of file we care about
  def extract_base_file_from_preprocessed_expansion(filepath)
    contents = []
    extract = false

    # preprocessing by way of toolchain preprocessor expands macros, eliminates comments, strips out #ifdef code, etc.
    # however, it also expands in place each #include'd file.
    # so, we must extract only the lines of the file that belong to the file originally preprocessed

    # iterate through all lines and alternate between extract and ignore modes
    # all lines between a '#'line containing file name of our filepath and the next '#'line should be extracted

    @file_wrapper.readlines(filepath).each do |line|
      if (extract)
        # flip to ignore mode if line begins with '#' except if it's a #pragma line
        if ((line =~ /^#/) and not (line =~ /#\s*pragma/))
          extract = false
        # otherwise, extract the line
        else
          contents << line
        end
      end
      # enable extract mode if line matches preprocessor expression for our original file name
      extract = true if (line =~ /^#.*(\s|\/|\\|\")#{Regexp.escape(File.basename(filepath))}/)
    end

    return contents
  end

end
