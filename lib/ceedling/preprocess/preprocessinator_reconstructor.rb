# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/encodinator'
require 'ceedling/parsing_parcels'

class PreprocessinatorReconstructor 
 
  constructor :parsing_parcels

  ##
  ## Preprocessor Expansion Output Handling
  ## ======================================
  ## 
  ## Preprocessing expands macros, eliminates comments, strips out #ifdef code, etc.
  ## However, it also expands in place each #include'd file. So, we must extract 
  ## only the lines of the file that belong to the file originally preprocessed.
  ## 
  ## We do this by examininig each line and ping-ponging between extracting and
  ## ignoring text based on preprocessor statements referencing the file we're
  ## seeking to reassemble.
  ##
  ## Note that the same text handling approach applies to full preprocessor 
  ## expansion as directives only expansion.
  ## 
  ## Example preprocessed expansion output
  ## --------------------------------------
  ## 
  ## # 14 "test/TestUsartModel.c" 2
  ## 
  ## void setUp(void)
  ## {
  ## }
  ## 
  ## void tearDown(void)
  ## {
  ## }
  ## 
  ## void testUsartModelInit(void)
  ## {
  ##   TemperatureFilter_Init_CMockExpect(26);
  ## 
  ##   UsartModel_Init();
  ## }
  ## # 55 "test/TestUsartModel.c"
  ## void testGetBaudRateRegisterSettingShouldReturnAppropriateBaudRateRegisterSetting(void)
  ## {
  ##   uint8 dummyRegisterSetting = 17;
  ##   UsartModel_CalculateBaudRateRegisterSetting_CMockExpectAndReturn(58, 48054857, 115200, dummyRegisterSetting);
  ## 
  ##   UnityAssertEqualNumber((UNITY_INT)(UNITY_UINT8 )((dummyRegisterSetting)), (UNITY_INT)(UNITY_UINT8 )((UsartModel_GetBaudRateRegisterSetting())), (((void*)0)), (UNITY_UINT)(60), UNITY_DISPLAY_STYLE_UINT8);
  ## }
  ## 
  ## void testIgnore(void)
  ## {
  ##   UnityIgnore( (((void*)0)), (UNITY_UINT)(65));
  ## }
  ## # 75 "test/TestUsartModel.c"
  ## void testGetFormattedTemperatureFormatsTemperatureFromCalculatorAppropriately(void)
  ## {
  ##   TemperatureFilter_GetTemperatureInCelcius_CMockExpectAndReturn(77, 25.0f);
  ##   UnityAssertEqualString((const char*)(("25.0 C\n")), (const char*)((UsartModel_GetFormattedTemperature())), (((void*)0)), (UNITY_UINT)(78));
  ## }
  ## 
  ## void testShouldReturnErrorMessageUponInvalidTemperatureValue(void)
  ## {
  ##   TemperatureFilter_GetTemperatureInCelcius_CMockExpectAndReturn(83, -__builtin_huge_valf());
  ##   UnityAssertEqualString((const char*)(("Temperature sensor failure!\n")), (const char*)((UsartModel_GetFormattedTemperature())), (((void*)0)), (UNITY_UINT)(84));
  ## }
  ## 
  ## void testShouldReturnWakeupMessage(void)
  ## {
  ##   UnityAssertEqualString((const char*)(("It's Awesome Time!\n")), (const char*)((UsartModel_GetWakeupMessage())), (((void*)0)), (UNITY_UINT)(89));
  ## }

  # `input` must have the interface of IO -- StringIO for testing or File in typical use
  def extract_file_as_array_from_expansion(input, filepath)
    lines = []
    _scan_expansion_for_file(input, filepath) { |line| lines << line }
    return lines
  end


  # Simple variation of preceding that returns file contents as single string
  def extract_file_as_string_from_expansion(input, filepath)
    return extract_file_as_array_from_expansion(input, filepath).join( "\n" )
  end


  # Writes only C code from `input` preprocessor expansion belonging to `filepath`
  # to `output` IO object incrementally (one logical line at a time) without building
  # an intermediate array. `output` must respond to `puts` (e.g. File or StringIO).
  def compact_from_expansion(input:, filepath:, output:)
    _scan_expansion_for_file(input, filepath) { |line| output.puts(line) }
  end


  # File-based convenience wrapper around `compact_from_expansion`.
  # Opens `input_filepath` for reading and `output_filepath` for writing,
  # then delegates to `compact_from_expansion` with the resulting IO objects.
  def compact_file_from_expansion(input_filepath:, source_filepath:, output_filepath:)
    # Open input in binary mode: GCC output under non-C locale contains non-ASCII bytes
    # (localized markers). Per-line clean_encoding in _scan_expansion_for_file handles content.
    File.open( input_filepath, 'rb' ) do |input|
      File.open( output_filepath, 'w' ) do |output|
        compact_from_expansion( input: input, filepath: source_filepath, output: output )
      end
    end
  end


  # Extract all test directive macros as a list from a file as string
  def extract_test_directive_macro_calls(file_contents)
    # Look for TEST_SOURCE_FILE("...") and TEST_INCLUDE_PATH("...") in a string (i.e. a file's contents as a string)

    regexes = [
      /(#{PATTERNS::TEST_SOURCE_FILE})/,
      /(#{PATTERNS::TEST_INCLUDE_PATH})/
    ]

    return extract_tokens_by_regex_list( file_contents, *regexes ).map(&:first)
  end


  # Extract TEST_CASE()/TEST_RANGE()/TEST_MATRIX() calls paired with the name of the test
  # function each stack of calls immediately precedes.
  #
  # Unlike `extract_test_directive_macro_calls` above, this cannot be built on top of
  # `extract_tokens_by_regex_list()`. That helper (via `@parsing_parcels.code_lines`) hands
  # the regex one physical/continuation-joined line at a time, so a pattern spanning
  # "TEST_CASE(...)\nvoid test_Foo(" could never match -- and that split-across-two-lines
  # layout is the overwhelmingly common real-world case (each macro call is a line of its
  # own, the function signature is the next line down). So we scan the whole string in one
  # pass instead, letting `PATTERNS::TEST_CASE_DIRECTIVE`'s `/m` flag see across line breaks.
  #
  # `file_contents` is expected to already have had comments stripped and #if/#ifdef/#include
  # directives (and their line markers) resolved away -- true of both callers in
  # PreprocessinatorFileAssembler#collect_test_file_contents: the non-fallback path reads
  # the directives-only GCC output (already comment-stripped in place by
  # PreprocessinatorCommentStripper before this ever runs, and already stripped of line
  # markers by `_scan_expansion_for_file` above), and the fallback path reads text already
  # run through `@parsing_parcels.code_lines` (which strips comments) plus conditional
  # filtering. So there's nothing here to confuse the adjacency test between a macro call
  # and the function signature that follows it.
  def extract_test_case_directives(file_contents)
    pairs = []

    file_contents.scan( PATTERNS::TEST_CASE_DIRECTIVE ) do |directive, function|
      pairs << { function: function, directive: directive.strip.split( "\n" ).map( &:rstrip ) }
    end

    return pairs
  end


  # Reinsert TEST_CASE()/TEST_RANGE()/TEST_MATRIX() calls (extracted above from a
  # macro-preserving preprocessor pass) into `contents` (built from a *fully expanded*
  # preprocessor pass, where these macros -- real Unity macros that `#define` to nothing --
  # have already vanished without a trace) immediately ahead of the matching test function's
  # line. `contents` is a scanning artifact only (never compiled), so reinserting this raw,
  # unexpanded macro text back into it is safe: Unity's own runner generator is the only
  # consumer, and it only cares that the text is there, immediately before the function.
  #
  # A single cursor walks `contents` forward as each directive is placed, rather than
  # independently searching the whole array per directive. Two reasons: it mirrors the
  # existing precedent for this exact original-order correlation problem elsewhere in
  # Ceedling (GeneratorTestRunner#parse_test_file's line-number remap, and Unity's own
  # find_tests() line-number lookup), and it avoids ever misattributing a directive to an
  # earlier stray match of the same function name (e.g. a forward declaration) instead of
  # the real definition that follows it in file order.
  def splice_test_case_directives(contents:, directives:)
    cursor = 0

    directives.each do |pair|
      function_regex = /^\s*void\s+#{Regexp.escape(pair[:function])}\s*\(/

      # Search forward from the cursor only. If the function isn't found -- e.g. it was
      # compiled out by an inactive #ifdef branch, resolved identically in both the source
      # this directive came from and in `contents` itself -- there's nothing to attach the
      # directive to, and dropping it silently is correct: an orphaned directive is inert.
      index = nil
      contents[cursor..-1].each_with_index do |line, offset|
        if line =~ function_regex
          index = cursor + offset
          break
        end
      end
      next if index.nil?

      contents.insert( index, *pair[:directive] )

      # Advance past the directive lines just inserted and the function line itself so the
      # next directive's search starts after this one, preserving file order.
      cursor = index + pair[:directive].size + 1
    end

    return contents
  end


  # Extract all pragmas as a list from a file as string
  def extract_pragmas(file_contents)
    return extract_multiline_directives( file_contents, 'pragma' )
  end


  # Find include guard in file contents as string
  def extract_include_guard(file_contents)
    # Look for first occurrence of #ifndef <sring> followed by #define <string>
    regex = /#\s*ifndef\s+(\w+)(?:\s*\n)+\s*#\s*define\s+(\w+)/
    matches = file_contents.match( regex )

    # Return if no match results
    return nil if matches.nil?

    # Return if match results are not expected size
    return nil if matches.size != 3

    # Return if #ifndef <string> does not match #define <string>
    return nil if matches[1] != matches[2]

    # Return string in common
    return matches[1]
  end


  # Extract all macro definitions as a list from a file as string
  def extract_macro_defs(file_contents, include_guard)
    macro_definitions = extract_multiline_directives( file_contents, 'define' )

    # Remove an include guard if provided
    macro_definitions.reject! {|macro| macro.include?( include_guard ) } if !include_guard.nil?

    return macro_definitions
  end

  ### Private ###

  private

  ##
  ## Iterate through all lines and alternate between extract and ignore modes.
  ## All lines between a '#' line containing the filepath to extract (a line marker) and the next '#' line should be extracted.
  ##
  ## GCC preprocessor output line marker format: `# <linenum> "<filename>" <flags>`
  ##
  ## Documentation on line markers in GCC preprocessor output:
  ##  https://gcc.gnu.org/onlinedocs/gcc-3.0.2/cpp_9.html
  ##
  ## Notes:
  ##  1. Successive blocks can all be from the same source text file without a different, intervening '#' line.
  ##     Multiple back-to-back blocks could all begin with '# 99 "path/file.c"'.
  ##  2. The first line of the file could start a text block we care about.
  ##  3. End of file could end a text block.
  ##  4. Usually, the first line marker contains no trailing flag.
  ##  5. Different preprocessors conforming to the GCC output standard may use different trailiing flags.
  ##  6. Our simple ping-pong-between-line-markers extraction technique does not require decoding flags.
  ##
  ## Yields one complete logical line at a time to the given block.
  ## A single `pending_line` buffer is held to allow aggregation of preprocessor-wrapped
  ## expansions (multiple physical lines at the same logical line number) before yielding.
  ##
  def _scan_expansion_for_file(input, filepath, &block)
    # Expand filepath under inspection to ensure proper match
    extraction_filepath = File.expand_path( filepath )
    # Preprocessor directive blocks generally take the form of '# <digits> <text> [optional digits]'
    directive   = /^# \d+ \"/
    # Line markers have the specific form of '# <digits> "path/filename.ext" [optional digits]' (see above)
    line_marker = /^#\s(\d+)\s\"(.+)\"/
    # Boolean to ping pong between line-by-line extract/ignore
    extract = false

    line_num      = 0
    last_line_num = 0

    # Buffer for the last logical line (may still receive aggregated content)
    pending_line  = nil
    # Whether a blank line should follow pending_line when flushed
    pending_blank = false

    # Yields pending_line (and optional trailing blank) then clears the buffer
    flush = lambda do
      unless pending_line.nil?
        block.call( pending_line )
        block.call( '' ) if pending_blank
        pending_line  = nil
        pending_blank = false
      end
    end

    # Use `each_line()` instead of `readlines()` (chomp removes newlines).
    # `each_line()` processes the IO buffer one line at a time instead of ingesting lines in an array.
    # At large buffer sizes needed for potentially lengthy preprocessor output this is far more memory efficient and faster.
    input.each_line( chomp:true ) do |line|

      # Clean up any oddball characters in an otherwise ASCII document
      line = line.clean_encoding

      # Handle expansion extraction if the line is not a preprocessor directive
      if extract and not line =~ directive
        line_num += 1

        # Strip a line so we can omit useless blank lines
        _line = line.strip()

        # Skip processing blank lines, but mark a pending blank unless we already have one
        if _line.empty?
          pending_blank = true if !pending_line.nil? && !pending_line.empty?
          next
        end

        # If the linemarker line number hasn't advanced, aggregate the expanded line into pending
        if (last_line_num == line_num) and !pending_line.nil?
          # Append the stripped line to the pending line
          # Include a space in the concatenation unless it's a semicolon or pending_line is blank
          pending_line = (_line == ';' or pending_line.empty?) ? (pending_line + _line) : (pending_line + ' ' + _line)
        else
          # Flush previous pending line before starting a new one
          flush.call()
          # Collect a left-whitespace-preserved version of the line
          pending_line = line.rstrip()
        end

      # Otherwise the line contained a preprocessor directive; drop out of extract mode
      else
        extract = false
      end

      # Enter extract mode if the line is a preprocessor line marker with filepath of interest
      matches = line.match( line_marker )
      if matches and matches.size() > 2
        last_line_num = line_num
        line_num = (matches[1].to_i - 1)
        fp = File.expand_path( matches[2].strip() )
        extract = true if extraction_filepath == fp
      end
    end

    # Yield any remaining buffered line at end of input
    flush.call()
  end


  def extract_multiline_directives(file_contents, directive)
    results = []

    # Output from the GCC preprocessor directives-only mode is the intended input to be processed here.
    # The GCC preprpocessor smooshes multiline directives into a single line.
    # We process both single and multiline directives here in case this is ever not true or we need
    # to extract directives from files that have not been preprocessed.

    # This regex captures any single or multiline preprocessor directive definition:
    #  - Looks for any string that begins with '#<directive>' ('#' and '<directive>' may be separated by spaces per C spec).
    #  - Captures all text (non-greedily) after '#<directive>' on a first line through 0 or more line continuations up to a final newline.
    #  - Line continuations comprise a final '\' on a given line followed by whitespace & newline, wrapping to the next
    #    line up to a final '\' on that next line.
    regex = /(#\s*#{directive}[^\n]*)\n/

    tokens = extract_tokens_by_regex_list( file_contents, regex )

    tokens.each do |token|
      # Get the full text string from `scan() results` and split it at any newlines
      lines = token[0].split( "\n" )
      # Lop off any trailing whitespace (mostly to simplify unit testing)
      lines.map! {|line| line.rstrip()}

      # If the result of splitting is just a single string, add it to the results array as a single string
      if lines.size == 1
        results << lines[0]
      # Otherwise, add the array of split strings to the results as a sub-array
      else
        results << lines
      end
    end

    return results
  end


  def extract_tokens_by_regex_list(file_contents, *regexes)
    tokens = []

    # For each regex provided, extract all matches from the source string
    regexes.each do |regex|
      @parsing_parcels.code_lines( file_contents ) do |line|
        tokens += line.scan( regex )
      end
    end

    return tokens
  end

end
