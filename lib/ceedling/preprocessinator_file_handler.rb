
class PreprocessinatorFileHandler

  constructor :preprocessinator_extractor, :configurator, :flaginator, :tool_executor, :file_path_utils, :file_wrapper, :streaminator

  def preprocess_header_file(filepath:, subdir:, includes:, flags:, include_paths:, defines:)
    preprocessed_filepath = @file_path_utils.form_preprocessed_file_filepath( filepath, subdir )

    filename = File.basename(filepath)

    command = @tool_executor.build_command_line(
      @configurator.tools_test_file_preprocessor,
      flags,
      filepath,
      preprocessed_filepath,
      defines,
      include_paths
      )
    
    @tool_executor.exec( command[:line], command[:options] )

    @streaminator.stdout_puts("Command: #{command}", Verbosity::DEBUG)

    contents = @preprocessinator_extractor.extract_base_file_from_preprocessed_expansion( preprocessed_filepath )

    # Reinsert #include statements into stripped down file
    # ----------------------------------------------------
    # Notes:
    #  - Preprocessing expands #includes, and we strip out those expansions.
    #  - #include order can be important. Iterating with unshift() inverts the order. So, we use revese().
    includes.reverse.each{ |include| contents.unshift( "#include \"#{include}\"" ) }

    # Add #include guards for header files
    # Note: These aren't truly needed as preprocessed header files are only ingested by CMock.
    #       They're created for sake of completeness and just in case...
    # ----------------------------------------------------
    # abc-XYZ.h --> _ABC_XYZ_H_
    guardname = '_' + filename.gsub(/\W/, '_').upcase + '_'

    forward_guards = [
      "#ifndef #{guardname} // Ceedling-generated guard",
      "#define #{guardname}",
      ''
    ]

    # Add guards to beginning of file contents
    contents =  forward_guards + contents
    contents += ["#endif // #{guardname}", '']  # Rear guard

    # Insert Ceedling notice
    # ----------------------------------------------------
    comment = "// CEEDLING NOTICE: This generated file only to be consumed by CMock"
    contents = [comment, ''] + contents

    # Write file, collapsing any repeated blank lines
    # ----------------------------------------------------    
    contents = contents.join("\n")
    contents.gsub!( /(\h*\n){3,}/, "\n\n" )
    
    @file_wrapper.write( preprocessed_filepath, contents )

    return preprocessed_filepath
  end

  def preprocess_test_file(filepath:, subdir:, includes:, flags:, include_paths:, defines:)
    preprocessed_filepath = @file_path_utils.form_preprocessed_file_filepath( filepath, subdir )

    command = @tool_executor.build_command_line(
      @configurator.tools_test_file_preprocessor,
      flags,
      filepath,
      preprocessed_filepath,
      defines,
      include_paths
      )
    
    @tool_executor.exec( command[:line], command[:options] )

    @streaminator.stdout_puts("Command: #{command}", Verbosity::DEBUG)

    contents = @preprocessinator_extractor.extract_base_file_from_preprocessed_expansion( preprocessed_filepath )

    # Reinsert #include statements into stripped down file
    # ----------------------------------------------------
    # Notes:
    #  - Preprocessing expands #includes, and we strip out those expansions.
    #  - #include order can be important. Iterating with unshift() inverts the order. So, we use revese().
    includes.reverse.each{ |include| contents.unshift( "#include \"#{include}\"" ) }

    # Insert Ceedling notice
    # ----------------------------------------------------
    comment = "// CEEDLING NOTICE: This generated file only to be consumed for test runner creation"
    contents = [comment, ''] + contents

    # Write file, doing some prettyifying along the way
    # ----------------------------------------------------    
    contents = contents.join("\n")
    contents.gsub!( /^\s*;/, '' )           # Drop blank lines with semicolons left over from macro expansion + trailing semicolon
    contents.gsub!( /\)\s+\{/, ")\n{" )     # Collapse any unnecessary white space between closing argument paren and opening function bracket
    contents.gsub!( /\{(\n){2,}/, "{\n" )   # Collapse any unnecessary white space between opening function bracket and code
    contents.gsub!( /(\n){2,}\}/, "\n}" )   # Collapse any unnecessary white space between code and closing function bracket
    contents.gsub!( /(\h*\n){3,}/, "\n\n" ) # Collapse repeated blank lines

    @file_wrapper.write( preprocessed_filepath, contents )

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
