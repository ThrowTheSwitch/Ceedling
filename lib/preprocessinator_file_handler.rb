

class PreprocessinatorFileHandler
  
  constructor :configurator, :tool_executor, :file_path_utils, :file_wrapper

  
  def preprocess_file(filepath, includes)
    preprocessed_filepath = @file_path_utils.form_preprocessed_file_path(filepath)
        
    command_line = @tool_executor.build_command_line(@configurator.tools_file_preprocessor, filepath, preprocessed_filepath)
    @tool_executor.exec(command_line)
    
    # extract from cpp-processed file only content of file we care about
    contents = []
    extract = false
    @file_wrapper.readlines(preprocessed_filepath).each do |line|
      if (extract)
        if (line =~ /^#/)
          extract = false
        else
          contents << line
        end
      end
      extract = true if (line =~ /^#.*#{Regexp.escape(File.basename(filepath))}/)
    end

    includes.each{|include| contents.unshift("#include \"#{include}\"")}

    @file_wrapper.write(preprocessed_filepath, contents.join("\n"))    
  end

end
