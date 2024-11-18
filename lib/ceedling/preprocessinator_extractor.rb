# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'

class PreprocessinatorExtractor 
 
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

    # Iterate through all lines and alternate between extract and ignore modes.
    # All lines between a '#' line containing the file name of our filepath and the
    # next '#' line should be extracted.
    #
    # Notes:
    #  1. Successive blocks can all be for the same source text file without terminating
    #  2. The first line of the file could start a text block we care about
    #  3. End of file could end a text block

    base_name  = File.basename( filepath )
    directive  = /^# \d+ \"/
    marker     = /^# \d+ \".*#{Regexp.escape(base_name)}\"/
    extract    = false

    lines = []

    # Use `each_line()` instead of `readlines()`.
    # `each_line()` processes IO buffer one line at a time instead of all lines in an array.
    # At large buffer sizes this is far more memory efficient and faster
    input.each_line( chomp:true ) do |line|
      
      # Clean up any oddball characters in an otherwise ASCII document
      line.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
      
      # Handle extraction if the line is not a preprocessor directive
      if extract and not line =~ directive
        _line = line.strip()
        # Restore line if stripping leaves text
        _line = line if !_line.empty?
        lines << _line
      # Otherwise the line contained a preprocessor directive; drop out of extract mode
      else
        extract = false
      end

      # Enter extract mode if the line is a preprocessor directive with filename of interest
      extract = true if line =~ marker
    end

    return lines
  end


  # Simple variation of preceding that returns file contents as single string
  def extract_file_as_string_from_expansion(input, filepath)
    return extract_file_as_array_from_expansion(input, filepath).join( "\n" )
  end


  # Extract all test directive macros as a list from a file as string
  def extract_test_directive_macro_calls(file_contents)
    regexes = [
      /#{UNITY_TEST_SOURCE_FILE}.+?"\)/,
      /#{UNITY_TEST_INCLUDE_PATH}.+?"\)/
    ]

    return extract_tokens_by_regex_list( file_contents, *regexes )
  end


  # Extract all pragmas as a list from a file as string
  def extract_pragmas(file_contents)
    tokens = extract_tokens_by_regex_list( file_contents, /#pragma.+$/ )
    return tokens.map {|token| token.rstrip()}
  end


  # Extract all macro definitions and pragmas as a list from a file as string
  def extract_macro_defs(file_contents)
    results = []

    tokens = extract_tokens_by_regex_list(
      file_contents,
      /(#\s*define\s+.*?(\\\s*\n.*?)*)\n/
    )

    tokens.each do |token|
      multiline = token[0].split( "\n" )
      multiline.map! {|line| line.rstrip()}
      if multiline.size == 1
        results << multiline[0]
      else
        results << multiline
      end
    end

    return results
  end

  ### Private ###

  private

  def extract_tokens_by_regex_list(file_contents, *regexes)
    tokens = []

    regexes.each do |regex|
      tokens += file_contents.scan( regex )
    end

    return tokens
  end

end
