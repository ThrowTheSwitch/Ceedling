# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'strscan'
require 'stringio'
require 'ceedling/exceptions'
require 'ceedling/c_extractor/c_extractor_code_text'
require 'ceedling/c_extractor/c_extractor_functions'
require 'ceedling/c_extractor/c_extractor_declarations'

class CExtractor
  DEFAULT_CHUNK_SIZE = (16 * 1024)                # 16 KB -- enough for most functions
  DEFAULT_MAX_FUNCTION_LENGTH = (5 * 1024 * 1024) # 5 MB mega-length safety limit
  DEFAULT_MAX_LINE_LENGTH = 1000                  # 1000 character safety limit

  # Data class representing all extracted content of C module
  CModule = Struct.new(
    :vars,       # Array of strings containing module-level variable declarations
    :funcs,      # Array of CFunction structs
    keyword_init: true
  ) do
    # Constructor to set unassigned fields to empty arrays for convenience
    def initialize(vars: [], funcs: [])
      super
    end

    # Concatenate two CModule instances
    # Returns a new CModule with combined `vars` and `funcs` arrays
    def +(other)
      CModule.new(
        vars: (self.vars + other.vars),
        funcs: (self.funcs + other.funcs)
      )
    end
  end
  
  # Factory method for file-based C extraction
  #
  # Creates a CExtractor instance configured to read from a file on disk.
  # Uses default settings for chunk size, maximum function length, and maximum line length.
  #
  # Line length is the character count for logical lines -- function signature, variable declarations.
  #
  # Parameters:
  #   filepath: String path to the C source file to extract from
  #
  # Returns: CExtractor instance ready to extract C code features
  #
  # Raises:
  #   CeedlingException: If file cannot be opened (permissions, doesn't exist, etc.)
  #
  # Example:
  #   extractor = CExtractor.from_file("src/module.c")
  #   module_contents = extractor.extract_contents()
  def self.from_file(filepath)
    
    begin
      file = File.open(filepath, 'r')
    rescue SystemCallError => e
      raise CeedlingException.new("Failed to open file for C contents extraction `#{filepath}`: #{e.message}")
    rescue => e
      raise CeedlingException.new("Error opening file for C contents extraction `#{filepath}`: #{e.message}")
    end

    return new(
      io: file,
      chunk_size: DEFAULT_CHUNK_SIZE,
      max_buffer_length: DEFAULT_MAX_FUNCTION_LENGTH,
      max_line_length: DEFAULT_MAX_LINE_LENGTH
    )
  end
  
  # Factory method for string-based C extraction
  #
  # Creates a CExtractor instance configured to read from an in-memory string.
  # Primarily used for testing, but can also be used when C code is already in memory.
  # Allows customization of extraction parameters for testing edge cases.
  #
  # Line length is the character count for logical lines -- function signature, variable declarations.
  #
  # Parameters:
  #   content: String containing C source code to extract from
  #   chunk_size: (Optional) Size of chunks to read at a time (default: 16 KB)
  #   max_buffer_length: (Optional) Maximum allowed function size (default: 5 MB)
  #   max_line_length: (Optional) Maximum allowed line length (default: 1000 chars)
  #
  # Returns: CExtractor instance ready to extract C code features
  #
  # Example:
  #   code = "int foo(void) { return 42; }"
  #   extractor = CExtractor.from_string(content: code)
  #   module_contents = extractor.extract_contents()
  #
  # Testing example:
  #   extractor = CExtractor.from_string(
  #     content: test_code,
  #     chunk_size: 10,  # Small chunks to test chunking logic
  #     max_buffer_length: 100
  #   )
  def self.from_string(
    content:,
    # Exposed for testing purposes
    chunk_size: DEFAULT_CHUNK_SIZE,
    max_buffer_length: DEFAULT_MAX_FUNCTION_LENGTH,
    max_line_length: DEFAULT_MAX_LINE_LENGTH
  )
    return new(
      io: StringIO.new(content),
      chunk_size: chunk_size,
      max_buffer_length: max_buffer_length,
      max_line_length: max_line_length
    )
  end
  
  def initialize(io:, chunk_size:, max_buffer_length:, max_line_length:)
    @io = io
    @chunk_size = chunk_size
    @max_buffer_length = max_buffer_length
    @max_line_length = max_line_length

    # Composition / dependency injection
    @code_text = CExtractorCodeText.new()
    @declarations = CExtractorDeclarations.new(@max_line_length)
    @functions = CExtractorFunctions.new(@code_text, @max_line_length)
  end
  
  def extract_contents()
    functions = []
    variables = []
    
    # Scan through the IO buffer in memory-limited chunks.
    # Increase the total memory scanned in chunks (up to a sane limit) looking for a complete function.
    # Once a complete function is found, move ahead in the IO buffer to a position just after the 
    # discovered function and begin chunking and scanning again.

    # Ensure we're at the start of buffer
    @io.rewind

    until @io.eof?
      # First pass: Extract a function (most unique feature)
      func = extract_next_feature(
        io: @io,
        max_length: @max_buffer_length,
        extractor: @functions.method(:try_extract_function_definition)
      )
      if func
        functions << func
        next
      end

      # Second pass: Extract variable declarations
      var = extract_next_feature(
        io: @io,
        max_length: @max_buffer_length,
        extractor: @declarations.method(:try_extract_variable)
      )
      if var
        variables << var
        next
      end
      
      # If no features found, end the loop and return the accumulated results.
      break
    end
    
    return CModule.new(funcs: functions, vars: variables)
  ensure
    @io.close
  end
  
  private
  
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
  # Side effects: Advances IO position to immediately after the extracted feature
  def extract_next_feature(io:, max_length:, extractor:)
    buffer = ""
    chunk_start_pos = io.pos
    
    # Incrementally attempt feature extraction.
    # Return on successful finding a complete feature.
    # Otherwise, the search follows this order:
    #  1. Exit the method with failure (nil) if we reach end of IO or exceeds maximum buffer length.
    #  2. Advance in attempting to extract a feature in the current buffer.
    #  3. If we find nothing, expand the buffer with another chunk.
    #  4. Go back to (1)
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
      success, feature = extractor.call(scanner)

      if success
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
