# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'rake' # for ext() method
require 'ceedling/file_wrapper'

class PreprocessinatorFileAssembler

  constructor(
    :preprocessinator_reconstructor,
    :configurator,
    :tool_executor,
    :file_path_utils,
    :file_wrapper,
    :loginator,
    :reportinator
  )

  def collect_mockable_header_file_contents(
      test:,
      filepath:,
      directives_only_filepath:,
      fallback:,
      flags:,
      defines:,
      include_paths:,
      extras:
    )
    contents = []

    # Our extra file content to be preserved
    # Leave these empty if :extras is false
    pragmas = []
    macro_defs = []

    preprocessed_filepath = @file_path_utils.form_preprocessed_file_full_expansion_filepath( filepath, test )

    # Run GCC with full preprocessor expansion
    command = @tool_executor.build_command_line(
      @configurator.tools_test_file_full_preprocessor,
      # Additional arguments
      flags,
      # Argument replacement
      filepath,
      preprocessed_filepath,
      defines,
      include_paths
    )    
    @tool_executor.exec( command )

    @file_wrapper.open( preprocessed_filepath, 'r' ) do |file|
      contents = @preprocessinator_reconstructor.extract_file_as_array_from_expansion( file, filepath )
    end

    # Bail out if no extras are required
    return contents, [] if !extras

    # Try to find an #include guard in the first 2k of the file text.
    # An #include guard is one macro from the original file we don't want to preserve if we can help it.
    # We create our own #include guard in the header file we create.
    # It's possible preserving the macro from the original file's #include guard could trip something up.
    # Of course, it's also possible some header conditional compilation feature is dependent on it.
    # ¯\_(ツ)_/¯
    include_guard = @preprocessinator_reconstructor.extract_include_guard( @file_wrapper.read( filepath, 2048 ) )

    if fallback
      msg = @reportinator.generate_module_progress(
        operation: "Using fallback method to extract pragmas and macros from",
        module_name: test,
        filename: File.basename(filepath)
      )
      @loginator.log( msg, Verbosity::OBNOXIOUS, LogLabels::WARNING )

      @file_wrapper.open( filepath, 'r' ) do |file|
        # Get code contents of original source file as a string
        # TODO: Modify to process line-at-a-time for memory savings & performance boost
        _contents = file.read

        # Extract pragmas and macros from 
        pragmas = @preprocessinator_reconstructor.extract_pragmas( _contents )
        macro_defs = @preprocessinator_reconstructor.extract_macro_defs( _contents, include_guard )
      end
    else
      @file_wrapper.open( directives_only_filepath, 'r' ) do |file|
        # Get code contents of preprocessed directives-only file as a string
        # TODO: Modify to process line-at-a-time for memory savings & performance boost
        _contents = @preprocessinator_reconstructor.extract_file_as_string_from_expansion( file, filepath )

        # Extract pragmas and macros from 
        pragmas = @preprocessinator_reconstructor.extract_pragmas( _contents )
        macro_defs = @preprocessinator_reconstructor.extract_macro_defs( _contents, include_guard )
      end
    end

    return contents, (pragmas + macro_defs)
  end


  def collect_file_contents_from_directives_only_preprocessing(source_filepath:, test:)
    contents = []

    preprocessed_filepath = @file_path_utils.form_preprocessed_file_directives_only_filepath( source_filepath, test )

    @file_wrapper.open( preprocessed_filepath, 'r' ) do |file|
      contents = @preprocessinator_reconstructor.extract_file_as_array_from_expansion( file, source_filepath )
    end

    return contents
  end


  def assemble_preprocessed_header_file(filename:, preprocessed_filepath:, contents:, extras:, includes:)
    # Generate #include guard name for header files
    guardname = FileWrapper.generate_include_guard( filename )

    # Write contents of final preprocessed file a line at a time
    # ----------------------------------------------------------
    @file_wrapper.open( preprocessed_filepath, 'w' ) do |file|
      # Add include guards and extra blank lines to beginning of file contents
      file << "#ifndef #{guardname} // Ceedling-generated include guard\n"
      file << "#define #{guardname}\n\n"

      # Reinsert #include statements into stripped down file
      # Rely on Include object stringification for formatting of incudes
      includes.each { |include| file << "#{include}\n" }

      # Blank line
      file << "\n" unless includes.empty?

      # Add in any macro defintions or prgamas
      extras.each do |ex|
        if ex.class == String
          file << ex + "\n"

        elsif ex.class == Array
          ex.each { |line| file << line + "\n" }
        end

        # Blank line
        file << "\n"
      end

      # Add extracted contents from preprocessed file
      contents.each { |line| file << line + "\n" }

      # Add final rear guard with extra blank lines
      file << "\n#endif // #{guardname}\n"
    end
  end


  def collect_test_file_contents(
      test:,
      filepath:,
      directives_only_filepath:,
      fallback:,
      flags:,
      defines:,
      include_paths:
    )
    contents = []
    # TEST_SOURCE_FILE() and TEST_INCLUDE_PATH()
    test_directives = []

    preprocessed_filepath = @file_path_utils.form_preprocessed_file_full_expansion_filepath( filepath, test )

    # Run GCC with full preprocessor expansion
    command = @tool_executor.build_command_line(
      @configurator.tools_test_file_full_preprocessor,
      # Additional arguments
      flags,
      # Argument replacement
      filepath,
      preprocessed_filepath,
      defines,
      include_paths
    )
    @tool_executor.exec( command )

    @file_wrapper.open( preprocessed_filepath, 'r' ) do |file|
      contents = @preprocessinator_reconstructor.extract_file_as_array_from_expansion( file, filepath )
    end

    if fallback
      msg = @reportinator.generate_module_progress(
        operation: "Using fallback method to extract test directive macros from",
        module_name: test,
        filename: File.basename(filepath)
      )
      @loginator.log( msg, Verbosity::OBNOXIOUS, LogLabels::WARNING )

      @file_wrapper.open( filepath, 'r' ) do |file|
        # Get code contents of original source file as a string
        # TODO: Modify to process line-at-a-time for memory savings & performance boost
        _contents = file.read

        # Extract TEST_SOURCE_FILE() and TEST_INCLUDE_PATH()
        test_directives = @preprocessinator_reconstructor.extract_test_directive_macro_calls( _contents )
      end
    else
      @file_wrapper.open( directives_only_filepath, 'r' ) do |file|
        # Get code contents of preprocessed directives-only file as a string
        # TODO: Modify to process line-at-a-time for memory savings & performance boost
        _contents = @preprocessinator_reconstructor.extract_file_as_string_from_expansion( file, filepath )

        # Extract TEST_SOURCE_FILE() and TEST_INCLUDE_PATH()
        test_directives = @preprocessinator_reconstructor.extract_test_directive_macro_calls( _contents )
      end
    end

    return contents, test_directives
  end


  def assemble_preprocessed_code_file(filename:, preprocessed_filepath:, contents:, extras:, includes:)
    # Write contents of final preprocessed file a line at a time
    # ----------------------------------------------------------
    @file_wrapper.open( preprocessed_filepath, 'w' ) do |file|
      # Reinsert #include statements into stripped down file
      # Rely on Include object stringification for formatting of incudes
      includes.each { |include| file << "#{include}\n" }

      # Blank line
      file << "\n" unless includes.empty?

      # Add in any extras like test directive macros
      extras.each { |ex| file << ex + "\n" }

      # Blank line
      file << "\n" unless extras.empty?

      # Add extracted contents from preprocessed file
      contents.each { |line| file << line + "\n" }

      # Blank line
      file << "\n" unless contents.empty?
    end
  end

end
