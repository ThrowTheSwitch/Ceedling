# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'rake' # for ext() method
require 'ceedling/file_wrapper'
require 'ceedling/encodinator'
require 'ceedling/preprocess/c_preprocessor_conditionals'

class PreprocessinatorFileAssembler

  constructor(
    :preprocessinator_reconstructor,
    :configurator,
    :tool_executor,
    :file_path_utils,
    :file_wrapper,
    :parsing_parcels,
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
    return contents, [], nil if !extras

    # Try to find an #include guard in the first 2k of the file text.
    # An #include guard is one macro from the original file we don't want to preserve if we can help it.
    # We create our own #include guard in the header file we create.
    # It's possible preserving the macro from the original file's #include guard could trip something up.
    # Of course, it's also possible some header conditional compilation feature is dependent on it.
    # ¯\_(ツ)_/¯
    include_guard = @preprocessinator_reconstructor.extract_include_guard( @file_wrapper.read( filepath, 2048 ).clean_encoding )

    if fallback
      msg = @reportinator.generate_module_progress(
        operation: "Using fallback method to extract pragmas and macros from",
        module_name: test,
        filename: File.basename(filepath)
      )
      @loginator.log( msg, Verbosity::OBNOXIOUS, LogLabels::WARNING )

      # Open in binary mode + clean encoding: source files may contain non-ASCII bytes
      # in comments (e.g. © symbols) that cause encoding errors under non-C locale.
      @file_wrapper.open( filepath, 'rb' ) do |file|
        # TODO: Modify to process line-at-a-time for memory savings & performance boost
        _contents = file.read.clean_encoding

        # Filter out inactive conditional blocks before extraction so that only
        # pragmas and macros that are active for the current defines list are returned.
        _contents = _filter_conditionals( _contents, defines )

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

    return contents, (pragmas + macro_defs), include_guard
  end


  def collect_file_contents_from_directives_only_preprocessing(source_filepath:, test:)
    contents = []

    preprocessed_filepath = @file_path_utils.form_preprocessed_file_raw_directives_only_filepath( source_filepath, test )

    @file_wrapper.open( preprocessed_filepath, 'r' ) do |file|
      contents = @preprocessinator_reconstructor.extract_file_as_array_from_expansion( file, source_filepath )
    end

    return contents
  end

  # Extract macro definitions and pragmas from a file using text scanning (fallback mode).
  # Used to preserve #define macros and #pragma directives in partial file reconstruction
  # when the directives-only preprocessor (-fdirectives-only) is not available.
  # Mirrors the fallback branch of collect_mockable_header_file_contents.
  def collect_macros_and_pragmas_fallback(source_filepath:, defines: [])
    include_guard = @preprocessinator_reconstructor.extract_include_guard(
      @file_wrapper.read( source_filepath, 2048 ).clean_encoding
    )

    pragmas = []
    macro_defs = []

    @file_wrapper.open( source_filepath, 'rb' ) do |file|
      _contents = file.read.clean_encoding
      _contents = _filter_conditionals( _contents, defines )
      pragmas    = @preprocessinator_reconstructor.extract_pragmas( _contents )
      macro_defs = @preprocessinator_reconstructor.extract_macro_defs( _contents, include_guard )
    end

    return pragmas + macro_defs
  end


  def collect_file_contents_fallback(source_filepath:, defines: [])
    # Open in binary mode + clean encoding: source files may have non-ASCII bytes
    # in comments (e.g. © symbols) that raise encoding errors under locale-dependent
    # text-mode encoding on non-C-locale systems.
    # Call line.chomp before clean_encoding: readlines(chomp:true) in binary mode
    # removes the \n separator but leaves \r on Windows CRLF lines. clean_encoding's
    # :universal_newline option would then convert that lone \r → \n, producing lines
    # with a spurious trailing \n that causes double-newlines in assembled output.
    # String#chomp (no-arg) removes \r\n, \r, or \n — safe on all platforms.
    cond_tracker = CPreprocessorConditionals.new( defines )
    result = []

    @file_wrapper.open( source_filepath, 'rb' ) do |file|
      file.readlines( chomp: true ).each do |raw_line|
        line = raw_line.chomp.clean_encoding

        # Strip inline // comment from a temporary copy for directive detection only.
        # We preserve the original line (with comments) in output per design intent.
        stripped = line.sub( /\s*\/\/.*$/, '' ).lstrip

        # Feed the comment-stripped line to the conditional tracker.
        # The tracker only reacts to lines beginning with '#'.
        cond_tracker.process_directive( stripped )

        # Skip all preprocessor directive lines from output (they appear in the
        # assembled file via the includes list and extras rather than raw content).
        # The non-fallback path produces GCC expansion output which contains no
        # literal #include/#define/#pragma lines either.
        next if stripped.start_with?( '#' )

        # Skip lines inside inactive conditional blocks
        next unless cond_tracker.active?

        result << line
      end
    end

    return result
  end


  def collect_file_contents_from_full_expansion(source_filepath:, test:)
    contents = []

    full_expansion_filepath = @file_path_utils.form_preprocessed_file_full_expansion_filepath( source_filepath, test )

    @file_wrapper.open( full_expansion_filepath, 'r' ) do |file|
      contents = @preprocessinator_reconstructor.extract_file_as_array_from_expansion( file, source_filepath )
    end

    return contents
  end


  def assemble_preprocessed_header_file(filename:, preprocessed_filepath:, contents:, extras:, includes:, include_guard: nil)
    # Reuse the original header's own #include guard name when we found one so that this
    # reconstructed file is recognized as "the same header" by the preprocessor wherever both
    # are reachable (e.g. once via a mock's shadowed copy, once via the original source path).
    # Fall back to a synthetic guard derived from the filename otherwise.
    guardname = include_guard || FileWrapper.generate_include_guard( filename )

    # Write contents of final preprocessed file a line at a time
    # ----------------------------------------------------------
    @file_wrapper.open( preprocessed_filepath, 'w' ) do |file|
      # Add include guards and extra blank lines to beginning of file contents
      file << "#ifndef #{guardname}\n"
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
    # TEST_CASE() / TEST_RANGE() / TEST_MATRIX(), paired with the test function name each precedes
    test_case_directives = []

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

      # Open in binary mode + clean encoding: source files may contain non-ASCII bytes
      # in comments (e.g. © symbols) that cause encoding errors under non-C locale.
      @file_wrapper.open( filepath, 'rb' ) do |file|
        _contents = file.read.clean_encoding

        # Filter out inactive conditional blocks before extraction so that only
        # test directives that are active for the current defines list are returned.
        _contents = _filter_conditionals( _contents, defines )

        # Extract TEST_SOURCE_FILE() and TEST_INCLUDE_PATH()
        test_directives = @preprocessinator_reconstructor.extract_test_directive_macro_calls( _contents )

        # Extract TEST_CASE()/TEST_RANGE()/TEST_MATRIX() calls paired with the test function
        # they immediately precede -- these vanish from `contents` above because they're real
        # (empty-expanding) Unity macros erased by full preprocessor expansion, so we must
        # recover them from this macro-preserving text instead.
        test_case_directives = @preprocessinator_reconstructor.extract_test_case_directives( _contents )
      end
    else
      @file_wrapper.open( directives_only_filepath, 'r' ) do |file|
        # Get code contents of preprocessed directives-only file as a string
        _contents = @preprocessinator_reconstructor.extract_file_as_string_from_expansion( file, filepath )

        # Extract TEST_SOURCE_FILE() and TEST_INCLUDE_PATH()
        test_directives = @preprocessinator_reconstructor.extract_test_directive_macro_calls( _contents )

        # Extract TEST_CASE()/TEST_RANGE()/TEST_MATRIX() calls paired with the test function
        # they immediately precede (see comment in the fallback branch above)
        test_case_directives = @preprocessinator_reconstructor.extract_test_case_directives( _contents )
      end
    end

    # Reinsert TEST_CASE()/TEST_RANGE()/TEST_MATRIX() calls immediately ahead of their test
    # function in `contents` -- full expansion erased them in place with no trace (not even a
    # blank line), so position must be recovered by matching on the function name they modify.
    contents = @preprocessinator_reconstructor.splice_test_case_directives(
      contents: contents,
      directives: test_case_directives
    )

    return contents, test_directives
  end


  ### Private ###

  private

  # Filters `file_contents` string through CPreprocessorConditionals, returning
  # only lines in active conditional blocks. Uses code_lines internally so
  # comments are stripped and line continuations are joined before filtering.
  # Intended for token extraction (pragmas, macro defs, test directives) — NOT
  # for content output where comments must be preserved.
  def _filter_conditionals(file_contents, defines)
    tracker = CPreprocessorConditionals.new( defines )
    lines = []
    @parsing_parcels.code_lines( file_contents ) do |line|
      tracker.process_directive( line )
      lines << line if tracker.active?
    end
    lines.join("\n") + "\n"
  end

  public

  def assemble_preprocessed_code_file(filename:, preprocessed_filepath:, contents:, extras:, includes:)
    # Write contents of final preprocessed file a line at a time
    # ----------------------------------------------------------
    @file_wrapper.open( preprocessed_filepath, 'w' ) do |file|
      # Reinsert #include statements into stripped down file
      # Rely on Include object stringification for formatting of incudes
      includes.each { |include| file << "#{include}\n" }

      # Blank line
      file << "\n" unless includes.empty?

      # Add in any extras like test directive macros or preserved macro definitions
      extras.each do |ex|
        if ex.class == String
          file << ex + "\n"
        elsif ex.class == Array
          ex.each { |line| file << line + "\n" }
        end
      end

      # Blank line
      file << "\n" unless extras.empty?

      # Add extracted contents from preprocessed file
      contents.each { |line| file << line + "\n" }

      # Blank line
      file << "\n" unless contents.empty?
    end
  end

end
