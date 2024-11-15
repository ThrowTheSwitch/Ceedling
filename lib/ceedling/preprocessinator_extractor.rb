# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

class PreprocessinatorExtractor

  # Preprocessing expands macros, eliminates comments, strips out #ifdef code, etc.
  # However, it also expands in place each #include'd file. So, we must extract 
  # only the lines of the file that belong to the file originally preprocessed.

  ##
  ## Preprocessor Expansion Output Handling
  ## ======================================
  ##
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
  def extract_file_from_full_expansion(input, filepath)

    # Iterate through all lines and alternate between extract and ignore modes.
    # All lines between a '#' line containing the file name of our filepath and the
    # next '#' line should be extracted.

    base_name  = File.basename( filepath )
    pattern    = /^#.*(\s|\/|\\|\")#{Regexp.escape(base_name)}/
    directive  = /^#(?!pragma\b)/ # Preprocessor directive that's not a #pragma
    extract    = false # Found lines of file we care about?

    lines = []

    # Use `each_line()` instead of `readlines()`.
    # `each_line()` processes IO buffer one line at a time instead of all lines in an array.
    # At large buffer sizes this is far more memory efficient and faster
    input.each_line( chomp:true ) do |line|
      
      # Clean up any oddball characters in an otherwise ASCII document
      line.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
      
      # Handle extract mode if the line is not a preprocessor directive
      if extract and not line =~ directive
        # Add the line with whitespace removed
        lines << line.strip()
      
      # Otherwise the line contained a preprocessor directive; drop out of extract mode
      else
        extract = false
      end

      # Enter extract mode if the line is a preprocessor directive with filename of interest
      extract = true if line =~ pattern
    end

    return lines
  end


  # `input` must have the interface of IO -- StringIO for testing or File in typical use
  # `buffer_size` exposed mostly for testing of stream handling
  def extract_file_from_directives_only_expansion(input, filepath, buffer_size:256)
    contents = ""

    base_name  = File.basename(filepath)
    pattern    = /(^#.+\".*#{Regexp.escape(base_name)}\"\s+\d+\s*\n)(.+)/m

    # Seek tracking and buffer size management
    _buffer_size = [buffer_size, input.size()].min
    read_total   = 0

    # Iteratively scan backwards until we find line matching regex pattern
    while read_total < input.size()

      # Move input pointer backward from end
      input.seek( input.size() - read_total - _buffer_size, IO::SEEK_SET )

      # Read from IO stream into a buffer
      buffer = input.read( _buffer_size )

      # Update total bytes read
      read_total += _buffer_size

      # Determine next buffer read size -- minimum of target buffer size or remaining bytes in stream
      _buffer_size  = [buffer_size, (input.size() - read_total)].min

      # Inline handle any oddball bytes
      buffer.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')

      # Prepend bytes read to contents
      contents = buffer + contents

      # Match on the pattern
      match = pattern.match( contents )

      # If a match, return everything after preprocessor directive line with filename of interest
      return match[2] if !match.nil?
    end
  end

end
