

class PreprocessinatorIncludesHandler
  
  constructor :configurator, :tool_executor, :task_invoker, :file_path_utils, :yaml_wrapper, :file_wrapper

  # shallow includes: only those headers a source file explicitly includes

  def invoke_shallow_includes_list(filepath)
    @task_invoker.invoke_shallow_include_lists( @file_path_utils.form_preprocessed_includes_list_path(filepath) )
  end

  # ask the preprocessor for a make-style dependency rule of only the headers the source file immediately includes
  def form_shallow_dependencies_rule(filepath)
    temp_filepath = @file_path_utils.form_temp_path(filepath)
    
    # read the file and replace all include statements with a decorated version
    # (decorating the names creates file names that don't exist, thus preventing the preprocessor 
    #  from snaking out and discovering the entire include path that winds through the code)
    contents = @file_wrapper.read(filepath)
    contents.gsub!( /#include\s+\"\s*(\S+)\s*\"/, "#include \"@@@@\\1\"" )
    @file_wrapper.write( temp_filepath, contents )
    
    # extract the make-style dependency rule telling the preprocessor to 
    #  ignore the fact that it can't find the included files
    command_line     = @tool_executor.build_command_line(@configurator.tools_test_includes_preprocessor, temp_filepath)
    command_response = @tool_executor.exec(command_line)
    @file_wrapper.rm_f(temp_filepath)
    return command_response
  end
  
  # headers only; ignore any crazy .c includes
  def extract_shallow_includes(make_rule)
    header_extension = @configurator.extension_header
    return make_rule.scan(/#{'@@@@(\S+\\'}#{header_extension + ')'}/).flatten
  end
  
  def write_shallow_includes_list(filepath, list)
    @yaml_wrapper.dump(filepath, list)
  end

end
