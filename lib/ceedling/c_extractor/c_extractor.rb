# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'strscan'
require 'stringio'
require 'ceedling/exceptions'
require 'ceedling/c_extractor/c_extractor_constants'
require 'ceedling/c_extractor/c_extractor_preprocessing'
require 'ceedling/c_extractor/c_extractor_definitions'

class CExtractor

  include CExtractorConstants

  # Data class representing all extracted content of C module
  CModule = Struct.new(
    :variable_declarations, # Array of CVariableDeclaration structs
    :function_definitions,  # Array of CFunctionDefinition structs
    :function_declarations, # Array of CFunctionDeclaration structs
    :macro_definitions,     # Array of String — raw #define text (single or multiline)
    :type_definitions,      # Array of String — raw typedef text (single or multiline)
    :aggregate_definitions, # Array of String — raw non-typedef struct/enum/union text
    keyword_init: true
  ) do
    # Constructor to set unassigned fields to empty arrays for convenience
    def initialize(
        variable_declarations: [],
        function_definitions: [],
        function_declarations: [],
        macro_definitions: [],
        type_definitions: [],
        aggregate_definitions: []
      )
      super
    end

    # Concatenate two CModule instances
    # Returns a new CModule with combined arrays
    def +(other)
      CModule.new(
        variable_declarations: (self.variable_declarations + other.variable_declarations),
        function_definitions:  (self.function_definitions  + other.function_definitions),
        function_declarations: (self.function_declarations + other.function_declarations),
        macro_definitions:     (self.macro_definitions     + other.macro_definitions),
        type_definitions:      (self.type_definitions      + other.type_definitions),
        aggregate_definitions: (self.aggregate_definitions + other.aggregate_definitions)
      )
    end
  end

  constructor :c_extractor_code_text, :c_extractor_functions, :c_extractor_declarations, :c_extractor_preprocessing, :c_extractor_definitions

  attr_writer :chunk_size, :max_buffer_length

  def setup()
    # Aliases
    @code_text     = @c_extractor_code_text
    @functions     = @c_extractor_functions
    @declarations  = @c_extractor_declarations
    @preprocessing = @c_extractor_preprocessing
    @definitions   = @c_extractor_definitions

    @chunk_size        = DEFAULT_CHUNK_SIZE
    @max_buffer_length = DEFAULT_MAX_FUNCTION_LENGTH
  end

  # Extract C module contents from a source file on disk.
  #
  # Parameters:
  #   filepath: String path to the C source file to extract from
  #
  # Returns: CModule struct containing all features extracted.
  #
  # Raises:
  #   CeedlingException: If file cannot be opened (permissions, doesn't exist, etc.)
  def from_file(filepath)
    begin
      File.open(filepath, 'r') do |file|
        return extract_contents( file, filepath )
      end
    rescue => ex
      raise CeedlingException.new("Error opening file for C contents extraction `#{filepath}` ⏩️ #{ex.message}")
    end
  end

  # Extract C module contents from an in-memory string.
  #
  # Parameters:
  #   content:           String containing C source code to extract from
  #   chunk_size:        (Optional) Size of chunks to read at a time (default: 16 KB)
  #   max_buffer_length: (Optional) Maximum allowed function size (default: 5 MB)
  #   max_line_length:   (Optional) Maximum allowed line length (default: 1000 chars)
  #
  # Returns: CModule struct containing all features extracted.
  def from_string(
    content:,
    chunk_size:        DEFAULT_CHUNK_SIZE,
    max_buffer_length: DEFAULT_MAX_FUNCTION_LENGTH,
    max_line_length:   DEFAULT_MAX_LINE_LENGTH
  )
    @chunk_size        = chunk_size
    @max_buffer_length = max_buffer_length
    @functions.max_line_length    = max_line_length
    @declarations.max_line_length = max_line_length

    return extract_contents( StringIO.new( content ), nil )
  end

  private

  # Extracts all C code features from the given IO source.
  #
  # Parameters:
  #   io:       Ruby IO object (File or StringIO) to read C source from
  #   filepath: String path to the original source file (may be nil for string input)
  #
  # Returns: CModule struct containing all features extracted.
  #
  # Raises:
  #   CeedlingException: If a feature exceeds max_buffer_length during extraction
  def extract_contents(io, filepath)
    function_definitions  = []
    function_declarations = []
    variable_declarations = []
    macro_definitions     = []
    type_definitions      = []
    aggregate_definitions = []

    # Ensure we're at the start of buffer
    io.rewind

    until io.eof?
      # First: preprocessing directives — '#' is the most syntactically unique leading character.
      # All directives are consumed; filter_directive selects only those collected for storage.
      directive = extract_next_feature(
        io: io,
        max_length: @max_buffer_length,
        extractor: @preprocessing.method(:try_extract_directive)
      )
      if directive
        macro_def = @preprocessing.filter_directive(directive, CExtractorPreprocessing::MACRO_DEFINITION)
        macro_definitions << macro_def if macro_def
        next
      end

      # Second: typedef declarations — 'typedef' is as syntactically unique as '#',
      # so handle it early before any heuristic-based feature detectors.
      typedef_def = extract_next_feature(
        io:         io,
        max_length: @max_buffer_length,
        extractor:  @definitions.method(:try_extract_typedef)
      )
      if typedef_def
        type_definitions << typedef_def
        next
      end

      # Third: static assertions — C11 _Static_assert / C23 static_assert.
      # Keyword-led and syntactically unambiguous; consumed but not collected.
      static_assert = extract_next_feature(
        io:         io,
        max_length: @max_buffer_length,
        extractor:  @preprocessing.method(:try_extract_static_assert)
      )
      next if static_assert

      # Fourth: non-typedef struct/enum/union type definitions.
      # Keyword-led and syntactically unambiguous at the brace level;
      # collected into aggregate_definitions.
      agg_def = extract_next_feature(
        io:         io,
        max_length: @max_buffer_length,
        extractor:  @definitions.method(:try_extract_aggregate_definition)
      )
      if agg_def
        aggregate_definitions << agg_def
        next
      end

      # Extract a function definition (most unique non-preprocessor feature)
      func = extract_next_feature(
        io: io,
        max_length: @max_buffer_length,
        extractor: @functions.method(:try_extract_function_definition),
        params: [filepath]
      )
      if func
        function_definitions << func
        next
      end

      # Extract a function forward declaration (next most unique feature)
      func = extract_next_feature(
        io: io,
        max_length: @max_buffer_length,
        extractor: @functions.method(:try_extract_function_declaration)
      )
      if func
        function_declarations << func
        next
      end

      # Extract variable declarations as array
      # NOTE: A compound variable declaration (e.g. `int x, y`) yields multiple declarations
      vars = extract_next_feature(
        io: io,
        max_length: @max_buffer_length,
        extractor: @declarations.method(:try_extract_variable)
      )
      if vars
        variable_declarations.concat(vars)
        next
      end

      # If no features found, we are either at EOF or stuck on unrecognized text.
      # In either case, break out of the loop to avoid infinite looping and return the accumulated results.
      break
    end

    return CModule.new(
      function_definitions:  function_definitions,
      function_declarations: function_declarations,
      variable_declarations: variable_declarations,
      macro_definitions:     macro_definitions,
      type_definitions:      type_definitions,
      aggregate_definitions: aggregate_definitions
    )
  ensure
    io.close
  end

  # Generic chunked buffer extraction routine
  # Reads IO in chunks, building a buffer until the provided extractor successfully extracts a feature
  #
  # Parameters:
  #   io: IO object to read from
  #   max_length: Maximum buffer size before raising an error
  #   extractor: Method/Proc that takes a StringScanner and returns [success, extracted_data]
  #              The extractor should advance the scanner position past the extracted feature on success
  #
  # Returns: The extracted data on success, nil if EOF reached without finding a complete feature
  #
  # Side effects:
  #  On success: Advance IO position to immediately after the extracted feature.
  #  On failure: Rewind IO position to the start of the current buffer.
  def extract_next_feature(io:, max_length:, extractor:, params: [])
    buffer = ""
    chunk_start_pos = io.pos

    # Incrementally attempt feature extraction with repeated attempts and a growing buffer.
    #
    # Return on successful finding of a complete feature.
    # Exit the method with failure (nil) and rewind IO:
    #  1. If we reach end of IO.
    #  2. Exceed maximum buffer length.
    #  3. Find no feature.
    #
    # Loop:
    #  1. Advance in attempting to extract a feature in the current buffer.
    #  2. If we find nothing, expand the buffer with another chunk.
    #  3. Go back to (1).
    loop do
      # Read next chunk
      chunk = io.read(@chunk_size)

      # Break out of the loop if we've reached the end of IO
      break unless chunk # EOF

      # Expand the buffer with the new chunk
      buffer << chunk

      # Safety check -- don't let buffer grow indefinitely
      if buffer.length > max_length
        raise CeedlingException.new("Feature extraction exceeded maximum length of #{max_length} characters")
      end

      # Create a new scanner for the current buffer
      scanner = StringScanner.new(buffer)

      # Skip any deadspace
      @code_text.skip_deadspace(scanner)

      # If reached end of string having found no feature -- restart loop to containing loop to grow buffer
      next if scanner.eos?

      # Try extract complete feature using provided extractor
      success, feature = extractor.call(scanner, *params)

      if success
        # Consume any trailing semicolons that may follow the extracted feature.
        # This handles cases like "int a;;" or "void foo() {};" where legal but
        # unnecessary semicolons could break subsequent feature extraction.
        @code_text.skip_semicolons(scanner)

        # Rewind IO buffer to position after this feature for next extraction attempt
        io.seek(chunk_start_pos + scanner.pos)
        return feature
      end
    end

    # Reached IO EOF without finding complete feature -- rewind IO buffer for next extraction attempt
    io.seek(chunk_start_pos)
    return nil
  end
end
