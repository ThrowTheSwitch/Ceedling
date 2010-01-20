

class PreprocessinatorIncludesHandler
  
  constructor :configurator, :tool_executor, :task_invoker, :file_path_utils, :yaml_wrapper, :file_wrapper


  def invoke_shallow_includes_list(filepath)
    @task_invoker.invoke_shallow_include_lists( @file_path_utils.form_preprocessed_includes_list_path(filepath) )
  end

  def form_shallow_dependencies_rule(filepath)
    temp_filepath = @file_path_utils.form_temp_path(filepath)
    
    contents = @file_wrapper.read(filepath)
    contents.gsub!(/#include\s+\"\s*(\S+)\s*\"/, "#include \"@@@@\\1\"")
    @file_wrapper.write( temp_filepath, contents )
    
    command_line     = @tool_executor.build_command_line(@configurator.tools_includes_preprocessor, temp_filepath)
    command_response = @tool_executor.exec(command_line)
    @file_wrapper.rm_f(temp_filepath)
    return command_response
  end
  
  # headers only; ignore any crazy .c includes
  def extract_shallow_includes(output)
    return output.scan(/#{'@@@@(\S+\\'}#{@configurator.extension_header + ')'}/).flatten
  end
  
  def write_shallow_includes_list(filepath, list)
    @yaml_wrapper.dump(filepath, list)
  end
  
  def process_file(filepath, includes)
    preprocessed_filepath = @file_path_utils.form_preprocessed_file_path(filepath)
        
    command_line = @tool_executor.build_command_line(@configurator.tools_file_preprocessor, filepath, preprocessed_filepath)
    @tool_executor.exec(command_line)
    
    # extract from cpp-processed file only content of file
    contents = []
    extract = false
    @file_wrapper.readlines(preprocessed_filepath).each do |line|
      if extract
        if line =~ /^#/
          extract = false
        else
          contents << line
        end
      end
      extract = true if line =~ /^#.*#{Regexp.escape(File.basename(filepath))}/
    end

    includes.each{|include| contents.unshift("#include \"#{include}\"")}

    @file_wrapper.write(preprocessed_filepath, contents.join("\n"))    
  end

end
