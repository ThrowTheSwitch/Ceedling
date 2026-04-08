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

class CExtractor

  include CExtractorConstants

  # Data class representing all extracted content of C module
  CModule = Struct.new(
    :variables,             # Array of CVariableDeclaration structs
    :function_definitions,  # Array of CFunctionDefinition structs
    :function_declarations, # Array of CFunctionDeclaration structs
    keyword_init: true
  ) do
    # Constructor to set unassigned fields to empty arrays for convenience
    def initialize(variables: [], function_definitions: [], function_declarations: [])
      super
    end

    # Concatenate two CModule instances
    # Returns a new CModule with combined arrays
    def +(other)
      CModule.new(
        variables: (self.variables + other.variables),
        function_definitions: (self.function_definitions + other.function_definitions),
        function_declarations: (self.function_declarations + other.function_declarations)
      )
    end
  end

  constructor :c_extractor_code_text, :c_extractor_functions, :c_extractor_declarations

  attr_writer :chunk_size, :max_buffer_length

  def setup()
    # Aliases
    @code_text = @c_extractor_code_text
    @functions = @c_extractor_functions
    @declarations = @c_extractor_declarations

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
    variables = []

    # Ensure we're at the start of buffer
    io.rewind

    until io.eof?
      # First pass: Extract a function (most unique feature)
      func = extract_next_feature(
        io: io,
        max_length: @max_buffer_length,
        extractor: @functions.method(:try_extract_function_definition),
        params: [filepath]
      )
      if func
        function_definitions << func
        # Avoid the final `break` that ends all feature search
        next
      end

      # First pass: Extract a function forward declaration (next most unique feature)
      func = extract_next_feature(
        io: io,
        max_length: @max_buffer_length,
        extractor: @functions.method(:try_extract_function_declaration)
      )
      if func
        function_declarations << func
        # Avoid the final `break` that ends all feature search
        next
      end

      # Second pass: Extract variable declarations as array
      # Note that a compound variable declaration (e.g. `int x, y`) yields multiple declarations
      vars = extract_next_feature(
        io: io,
        max_length: @max_buffer_length,
        extractor: @declarations.method(:try_extract_variable)
      )
      if vars
        variables.concat(vars)
        # Avoid the final `break` that ends all feature search
        next
      end

      # If no features found, end the loop and return the accumulated results.
      break
    end

    return CModule.new(
      function_definitions: function_definitions,
      function_declarations: function_declarations,
      variables: variables
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
