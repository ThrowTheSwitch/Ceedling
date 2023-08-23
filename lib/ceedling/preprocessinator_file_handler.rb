

class PreprocessinatorFileHandler

  constructor :preprocessinator_extractor, :configurator, :flaginator, :tool_executor, :file_path_utils, :file_wrapper, :streaminator


  def preprocess_file(filepath:, subdir:, includes:, flags:, include_paths:, defines:)
    preprocessed_filepath = @file_path_utils.form_preprocessed_file_filepath(filepath, subdir)

    command = 
      @tool_executor.build_command_line( @configurator.tools_test_file_preprocessor,
                                         flags,
                                         filepath,
                                         preprocessed_filepath,
                                         defines,
                                         include_paths)
    
    @tool_executor.exec( command[:line], command[:options] )

    @streaminator.stdout_puts("Command: #{command}", Verbosity::DEBUG)

    contents = @preprocessinator_extractor.extract_base_file_from_preprocessed_expansion( preprocessed_filepath )

    # Reinsert #include statements into stripped down file
    # (Preprocessing expands #includes and we strip out those expansions, leaving no #include statements that we need)
    includes.each{ |include| contents.unshift( "#include \"#{include}\"" ) }

    @file_wrapper.write( preprocessed_filepath, contents.join("\n") )

    return preprocessed_filepath
  end

  def preprocess_file_directives(filepath, includes)
    preprocessed_filepath = @file_path_utils.form_preprocessed_file_filepath(filepath)

    command = 
      @tool_executor.build_command_line( @configurator.tools_test_file_preprocessor_directives,
                                         @flaginator.flag_down( OPERATION_COMPILE_SYM, TEST_SYM, filepath ),
                                         filepath,
                                         preprocessed_filepath)

    @tool_executor.exec(command[:line], command[:options])

    contents = @preprocessinator_extractor.extract_base_file_from_preprocessed_directives(preprocessed_filepath)

    includes.each{|include| contents.unshift("#include \"#{include}\"")}

    @file_wrapper.write(preprocessed_filepath, contents.join("\n"))
  end

end
