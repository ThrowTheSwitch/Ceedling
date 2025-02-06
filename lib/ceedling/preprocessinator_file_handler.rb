# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'rake' # for ext() method

class PreprocessinatorFileHandler

  constructor :preprocessinator_extractor, :configurator, :tool_executor, :file_path_utils, :file_wrapper, :loginator

  def collect_header_file_contents(source_filepath:, test:, flags:, defines:, include_paths:, extras:)
    contents = []

    # Our extra file content to be preserved
    # Leave these empty if :extras is false
    pragmas = []
    macro_defs = []

    preprocessed_filepath = @file_path_utils.form_preprocessed_file_full_expansion_filepath( source_filepath, test )

    # Run GCC with full preprocessor expansion
    command = @tool_executor.build_command_line(
      @configurator.tools_test_file_full_preprocessor,
      flags,
      source_filepath,
      preprocessed_filepath,
      defines,
      include_paths
    )    
    @tool_executor.exec( command )

    @file_wrapper.open( preprocessed_filepath, 'r' ) do |file|
      contents = @preprocessinator_extractor.extract_file_as_array_from_expansion( file, source_filepath )
    end

    # Bail out, skipping directives-only preprocessing if no extras are required
    return contents, (pragmas + macro_defs) if !extras

    preprocessed_filepath = @file_path_utils.form_preprocessed_file_directives_only_filepath( source_filepath, test )

    # Run GCC with directives-only preprocessor expansion
    command = @tool_executor.build_command_line(
      @configurator.tools_test_file_directives_only_preprocessor,
      flags,
      source_filepath,
      preprocessed_filepath,
      defines,
      include_paths
    )
    results = @tool_executor.exec( command )

    # Try to find an #include guard in the first 2k of the file text.
    # An #include guard is one macro from the original file we don't want to preserve if we can help it.
    # We create our own #include guard in the header file we create.
    # It's possible preserving the macro from the original file's #include guard could trip something up.
    # Of course, it's also possible some header conditional compilation feature is dependent on it.
    # ¯\_(ツ)_/¯
    include_guard = @preprocessinator_extractor.extract_include_guard( @file_wrapper.read( source_filepath, 2048 ) )

    # If we received a warning from preprocessor saying that clang can't handle directives-only (common with older clang)
    # then we need to attempt to extract the information directly from the source file instead
    if results[:output].match /warning[^\n]+-fdirectives-only/
      @file_wrapper.open( source_filepath, 'r' ) do |file|
        # Get code contents of original source file as a string
        # TODO: Modify to process line-at-a-time for memory savings & performance boost
        _contents = file.read

        # Extract pragmas and macros from 
        pragmas = @preprocessinator_extractor.extract_pragmas( _contents )
        macro_defs = @preprocessinator_extractor.extract_macro_defs( _contents, include_guard )
      end
    else
      @file_wrapper.open( preprocessed_filepath, 'r' ) do |file|
        # Get code contents of preprocessed directives-only file as a string
        # TODO: Modify to process line-at-a-time for memory savings & performance boost
        _contents = @preprocessinator_extractor.extract_file_as_string_from_expansion( file, source_filepath )

        # Extract pragmas and macros from 
        pragmas = @preprocessinator_extractor.extract_pragmas( _contents )
        macro_defs = @preprocessinator_extractor.extract_macro_defs( _contents, include_guard )
      end
    end

    return contents, (pragmas + macro_defs)
  end


  def assemble_preprocessed_header_file(filename:, preprocessed_filepath:, contents:, extras:, includes:)
    _contents = []

    # Add #include guards for header files
    # Note: These aren't truly needed as preprocessed header files are only ingested by CMock.
    #       They're created for sake of completeness and just in case...
    # ----------------------------------------------------
    # abc-XYZ.h --> _ABC_XYZ_H_
    guardname = '_' + filename.gsub(/\W/, '_').upcase + '_'

    forward_guards = [
      "#ifndef #{guardname} // Ceedling-generated include guard",
      "#define #{guardname}",
      ''
    ]

    # Insert Ceedling notice
    # ----------------------------------------------------
    comment = "// CEEDLING NOTICE: This generated file only to be consumed by CMock"
    _contents += [comment, '']

    # Add guards to beginning of file contents
    _contents += forward_guards

    # Blank line
    _contents << ''

    # Reinsert #include statements into stripped down file
    includes.each{ |include| _contents << "#include \"#{include}\"" }

    # Blank line
    _contents << ''

    # Add in any macro defintions or prgamas
    extras.each do |ex|
      if ex.class == String
        _contents << ex

      elsif ex.class == Array
        _contents += ex
      end

      # Blank line
      _contents << ''
    end

    _contents += contents

    _contents += ['', "#endif // #{guardname}", '']  # Rear guard

    # Write file, collapsing any repeated blank lines
    # ----------------------------------------------------    
    _contents = _contents.join("\n")
    _contents.gsub!( /(\h*\n){3,}/, "\n\n" )

    # Remove paths from expanded #include directives
    # ----------------------------------------------------
    #  - We rely on search paths at compilation rather than explicit #include paths
    #  - Match (#include ")((path/)+)(file") and reassemble string using first and last matching groups
    _contents.gsub!( /(#include\s+")(?:(?:[^"\/]+\/)+)([^"\/]*")/, '\1\2' )

    # Write contents of final preprocessed file
    @file_wrapper.write( preprocessed_filepath, _contents )
  end


  def collect_test_file_contents(source_filepath:, test:, flags:, defines:, include_paths:)
    contents = []
    # TEST_SOURCE_FILE() and TEST_INCLUDE_PATH()
    test_directives = []

    preprocessed_filepath = @file_path_utils.form_preprocessed_file_full_expansion_filepath( source_filepath, test )

    # Run GCC with full preprocessor expansion
    command = @tool_executor.build_command_line(
      @configurator.tools_test_file_full_preprocessor,
      flags,
      source_filepath,
      preprocessed_filepath,
      defines,
      include_paths
    )
    @tool_executor.exec( command )

    @file_wrapper.open( preprocessed_filepath, 'r' ) do |file|
      contents = @preprocessinator_extractor.extract_file_as_array_from_expansion( file, source_filepath )
    end

    preprocessed_filepath = @file_path_utils.form_preprocessed_file_directives_only_filepath( source_filepath, test )

    # Run GCC with directives-only preprocessor expansion
    command = @tool_executor.build_command_line(
      @configurator.tools_test_file_directives_only_preprocessor,
      flags,
      source_filepath,
      preprocessed_filepath,
      defines,
      include_paths
    )    
    results = @tool_executor.exec( command )

    # If we receive a warning saying that clang can't handle directives-only (common with older clang)
    # then we fall back to using the original source file to detect all TEST_SOURCE_FILE and TEST_INCLUDE_PATH macros
    if results[:output].match /warning[^\n]+-fdirectives-only/
      @file_wrapper.open( source_filepath, 'r' ) do |file|
        # Get code contents of original source file as a string
        # TODO: Modify to process line-at-a-time for memory savings & performance boost
        _contents = file.read

        # Extract TEST_SOURCE_FILE() and TEST_INCLUDE_PATH()
        test_directives = @preprocessinator_extractor.extract_test_directive_macro_calls( _contents )
      end
    else
      @file_wrapper.open( preprocessed_filepath, 'r' ) do |file|
        # Get code contents of preprocessed directives-only file as a string
        # TODO: Modify to process line-at-a-time for memory savings & performance boost
        _contents = @preprocessinator_extractor.extract_file_as_string_from_expansion( file, source_filepath )

        # Extract TEST_SOURCE_FILE() and TEST_INCLUDE_PATH()
        test_directives = @preprocessinator_extractor.extract_test_directive_macro_calls( _contents )
      end
    end

    return contents, test_directives
  end


  def assemble_preprocessed_test_file(filename:, preprocessed_filepath:, contents:, extras:, includes:)
    _contents = []

    # Insert Ceedling notice
    # ----------------------------------------------------
    comment = "// CEEDLING NOTICE: This generated file only to be consumed for test runner creation"
    _contents += [comment, '']

    # Blank line
    _contents << ''

    # Reinsert #include statements into stripped down file
    includes.each{ |include| _contents << "#include \"#{include}\"" }

    # Blank line
    _contents << ''

    # Add in test directive macro calls
    extras.each {|ex| _contents << ex}

    # Blank line
    _contents << ''

    _contents += contents

    # Write file, doing some prettyifying along the way
    # ----------------------------------------------------    
    _contents = _contents.join("\n")
    _contents.gsub!( /^\s*;/, '' )           # Drop blank lines with semicolons left over from macro expansion + trailing semicolon
    _contents.gsub!( /\)\s+\{/, ")\n{" )     # Collapse any unnecessary white space between closing argument paren and opening function bracket
    _contents.gsub!( /\{(\n){2,}/, "{\n" )   # Collapse any unnecessary white space between opening function bracket and code
    _contents.gsub!( /(\n){2,}\}/, "\n}" )   # Collapse any unnecessary white space between code and closing function bracket
    _contents.gsub!( /(\h*\n){3,}/, "\n\n" ) # Collapse repeated blank lines

    # Write contents of final preprocessed file
    @file_wrapper.write( preprocessed_filepath, _contents )
  end

end
