# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'strscan'
require 'stringio'
require 'ceedling/exceptions'

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

  # Data class representing an extracted C function
  CFunction = Struct.new(
    :name,            # Function name only (e.g., "foo")
    :signature,       # Function signature (e.g., "int foo(void)")
    :body,            # Function body including containing braces
    :code_block,      # Complete function text (signature + body)
    :line_count,      # Total number of lines in code_block
    keyword_init: true
  ) do
    # Constructor to set unassigned fields to nil for convenience
    def initialize(name: nil, signature: nil, body: nil, code_block: nil, line_count: 0)
      super
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
      max_function_length: DEFAULT_MAX_FUNCTION_LENGTH,
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
  #   max_function_length: (Optional) Maximum allowed function size (default: 5 MB)
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
  #     max_function_length: 100
  #   )
  def self.from_string(
    content:,
    # Exposed for testing purposes
    chunk_size: DEFAULT_CHUNK_SIZE,
    max_function_length: DEFAULT_MAX_FUNCTION_LENGTH,
    max_line_length: DEFAULT_MAX_LINE_LENGTH
  )
    return new(
      io: StringIO.new(content),
      chunk_size: chunk_size,
      max_function_length: max_function_length,
      max_line_length: max_line_length
    )
  end
  
  def initialize(io:, chunk_size:, max_function_length:, max_line_length:)
    @io = io
    @chunk_size = chunk_size
    @max_function_length = max_function_length
    @max_line_length = max_line_length
  end
  
  def extract_contents()
    functions = []
    variables = []
    
    # Scan through the IO buffer in memory-limited chunks.
    # Increase the total memory scanned in chunks (up to a sane limit) looking for a complete function.
    # Once a complete function is found, move ahead in the IO buffer to a position just after the 
    # discovered function and begin chunking and scanning again.

    # First pass: Extract all functions
    @io.rewind
    until @io.eof?
      func = extract_next_feature(
        io: @io,
        max_length: @max_function_length,
        extractor: method(:try_extract_function)
      )
      functions << func if func
    end
    
    # Second pass: Extract all variables
    # @io.rewind
    # until @io.eof?
    #   var = extract_next_feature(
    #     io: @io,
    #     max_length: @max_variable_length,
    #     extractor: method(:try_extract_variable)
    #   )
    #   variables << var if var
    # end
    
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

      # Initialize last_scanner_pos to current position
      last_scanner_pos = scanner.pos

      # Attempt to find and extract complete feature using provided extractor
      loop do
        # Skip any deadspace
        skip_deadspace(scanner)

        # If reached end of string having found no feature -- exit loop to containing loop to grow buffer
        break if scanner.eos?

        # Update last_scanner_pos to current position
        last_scanner_pos = scanner.pos

        # Try extract complete feature using provided extractor
        success, feature = extractor.call(scanner)

        if success
          # Rewind IO buffer to position after this feature for next extraction attempt
          io.seek(chunk_start_pos + scanner.pos)
          return feature
        end

        # If we haven't advanced (i.e. found nothing), break out of the loop to expand the buffer with another chunk
        break if scanner.pos == last_scanner_pos
      end
    end
    
    # Reached IO EOF without finding complete feature
    return nil
  end

  # Try to extract a complete function from the scanner
  # Returns [success, function_data] where:
  #   - success: boolean indicating if extraction was successful
  #   - function_data: CFunction with as much info as available (may be partial on failure)
  def try_extract_function(scanner)
    start_pos = scanner.pos
    
    # Look for function signature
    signature = extract_function_signature(scanner)
    return [false, CFunction.new] unless signature
    
    skip_deadspace(scanner)

    unless scanner.peek(1) == '{'
      return [false, CFunction.new(
        name: parse_function_name(signature),
        signature: signature
      )]
    end
    
    # Extract function body
    success, braced_body = extract_balanced_braces(scanner)
    unless success
      return [false, CFunction.new(
        name: parse_function_name(signature),
        signature: signature,
        code_block: scanner.string[start_pos...scanner.pos]
      )]
    end
    
    # Extract full function definition
    code_block = scanner.string[start_pos...scanner.pos]
    
    # Fill out function data class
    func = CFunction.new(
      name: parse_function_name(signature),
      signature: signature,
      body: braced_body,
      code_block: code_block,
      line_count: code_block.count("\n") + 1
    )
    
    return [true, func]
  end

  def parse_function_name(signature)
    # Find the opening parenthesis
    paren_pos = signature.index('(')
    return nil unless paren_pos
    
    # Extract everything before the parenthesis
    before_paren = signature[0...paren_pos]
    
    # Split by whitespace and special characters, get the last token
    # This handles cases like:
    #   "int foo" -> "foo"
    #   "static void* bar" -> "bar"
    #   "unsigned long long baz" -> "baz"
    #   "int (*func_ptr)" -> "func_ptr" (function pointer)
    tokens = before_paren.split(/[\s*]+/)
    
    # Get the last non-empty token
    name = tokens.reverse.find { |t| !t.empty? }
    
    # Handle function pointers: remove parentheses
    # e.g., "(*func_ptr)" -> "func_ptr"
    name&.gsub(/[()]/, '')
  end
  
  # Extract a function signature from the scanner
  # 
  # A valid function signature must:
  #   1. Contain balanced parentheses (for parameter list)
  #   2. Be followed by an opening brace '{' (function definition)
  #   3. NOT be followed by a semicolon (which indicates a declaration, not a definition)
  # 
  # This method handles complex signatures including:
  #   - Simple functions: "int foo(void)"
  #   - Function pointers in return type: "int (*getFunction(void))(int, int)"
  #   - Function pointers in parameters: "void process(int (*callback)(void))"
  #   - Nested parentheses: "int foo((int)(x), (int)(y))"
  # 
  # The key insight is that we need to find the OUTERMOST balanced parentheses that represent
  # the function's parameter list, not just any balanced parentheses.
  # 
  # Parameters:
  #   scanner: StringScanner positioned at the start of a potential function signature
  # 
  # Returns:
  #   - The signature string (cleaned and normalized) if this is a function definition
  #   - nil if this is not a function definition (declaration, struct, etc.)
  # 
  # Side effects:
  #   - On success (function definition): Advances scanner to the opening brace '{'
  #   - On failure (declaration): Advances scanner past the semicolon ';'
  #   - On failure (other): Resets scanner to starting position
  # 
  # Examples:
  #   "int foo(void) {"                          -> returns "int foo(void)", scanner at '{'
  #   "int foo(void);"                           -> returns nil, scanner after ';'
  #   "struct foo {"                             -> returns nil, scanner at start
  #   "int foo(int x,\n  int y) {"               -> returns "int foo(int x, int y)", scanner at '{'
  #   "int (*getFunction(void))(int, int) {"     -> returns "int (*getFunction(void))(int, int)", scanner at '{'
  #   "void process(int (*callback)(void)) {"    -> returns "void process(int (*callback)(void))", scanner at '{'
  def extract_function_signature(scanner)
    start_pos = scanner.pos
    paren_depth = 0
    in_string = false
    string_char = nil
    signature_candidates = []  # Track positions where paren_depth returns to 0
    
    until scanner.eos?
      char = scanner.peek(1)
      
      # Safety check
      if scanner.pos - start_pos > @max_line_length
        raise CeedlingException.new("Function signature exceeds maximum length of #{@max_line_length} characters")
      end

      # Handle string literals
      if in_string
        if char == '\\'
          scanner.getch
          scanner.getch unless scanner.eos?
          next
        elsif char == string_char
          scanner.getch
          in_string = false
          string_char = nil
          next
        else
          scanner.getch
          next
        end
      end
      
      case char
      when '"', "'"
        in_string = true
        string_char = char
        scanner.getch
      when '/'
        if scanner.peek(2) =~ %r{^(/[/*])}
          skip_comment(scanner)
        else
          scanner.getch
        end
      when '('
        paren_depth += 1
        scanner.getch
      when ')'
        paren_depth -= 1
        scanner.getch
        
        # When we return to depth 0, this could be the end of the function's parameter list
        if paren_depth == 0
          signature_candidates << scanner.pos
        elsif paren_depth < 0
          # Unbalanced parentheses - not a valid function signature
          scanner.pos = start_pos
          return nil
        end
      when '{'
        # Found opening brace - check if any of our candidates is valid
        if signature_candidates.empty?
          # No balanced parens found before brace - not a function
          scanner.pos = start_pos
          return nil
        end
        
        # The last candidate (outermost closing paren) should be the function parameter list
        signature_end_pos = signature_candidates.last
        
        # Extract and clean the signature
        signature = scanner.string[start_pos...signature_end_pos].strip
        signature.gsub!(/\r\n|\r|\n|\t/, ' ')
        signature.gsub!(/\s+/, ' ')
        
        return signature
      when ';'
        # Found semicolon - this is a declaration, not a definition
        if signature_candidates.any?
          # Skip past the semicolon
          scanner.getch
        else
          # No balanced parens found - reset position
          puts('B')
          scanner.pos = start_pos
        end
        return nil
      else
        scanner.getch
      end      
    end
    
    # Reached end without finding complete signature
    scanner.pos = start_pos
    nil
  end
  
  # Extract a balanced block of braces from the scanner
  # Handles nested braces, string literals, and comments that might contain braces
  # 
  # Parameters:
  #   scanner: StringScanner positioned at the opening brace
  # 
  # Returns: [success, extracted_block] where:
  #   - success: boolean indicating if a complete balanced block was found
  #   - extracted_block: string containing the complete block including braces (nil on failure)
  # 
  # Side effects: Advances scanner position past the closing brace on success
  # 
  # Examples:
  #   "{ code }"           -> [true, "{ code }"]
  #   "{ a { b } c }"      -> [true, "{ a { b } c }"]
  #   "{ incomplete"       -> [false, nil]
  #   "not a brace"        -> [false, nil]
  def extract_balanced_braces(scanner)
    start_pos = scanner.pos
    
    # Verify we're starting at an opening brace
    return [false, nil] unless scanner.getch == '{'
    
    depth = 1
    
    until scanner.eos?
      char = scanner.peek(1)
      
      case char
      when '{'
        # Found nested opening brace -- increase depth
        depth += 1
        scanner.getch
      when '}'
        # Found closing brace -- decrease depth
        depth -= 1
        scanner.getch
        # When depth reaches 0, we've found the matching closing brace
        if depth == 0
          extracted_block = scanner.string[start_pos...scanner.pos]
          return [true, extracted_block]
        end
      when '"', "'"
        # Skip string literals that might contain braces
        skip_c_string(scanner, char)
      when '/'
        # Skip comments that might contain braces
        if scanner.peek(2) =~ %r{^(/[/*])}
          skip_comment(scanner)
        else
          scanner.getch
        end
      else
        # Regular character -- just advance
        scanner.getch
      end
    end
    
    # Reached end of input without finding matching closing brace
    [false, nil]
  end

  # Skip a C string or character literal
  # Handles escape sequences to avoid false termination on escaped quotes
  # 
  # Parameters:
  #   scanner: StringScanner positioned at the opening quote
  #   quote: The quote character (either '"' for strings or "'" for characters)
  # 
  # Returns: Number of bytes skipped (including opening and closing quotes)
  # 
  # Side effects: Advances scanner position past the closing quote (or to end of string if unterminated)
  # 
  # Examples:
  #   "hello"       -> skips 7 bytes
  #   'a'           -> skips 3 bytes
  #   "say \"hi\""  -> skips 11 bytes (handles escaped quotes)
  #   "path\\file"  -> skips 11 bytes (handles escaped backslashes)
  def skip_c_string(scanner, quote)
    start_pos = scanner.pos
    scanner.getch # Opening quote
    
    until scanner.eos?
      if scanner.scan(/\\/)
        scanner.getch
      elsif scanner.getch == quote
        break
      end
    end
    
    return (scanner.pos - start_pos)
  end

  # Skip "deadspace" - non-code elements that should be ignored during extraction
  # Deadspace includes:
  #   - Whitespace (spaces, tabs, newlines, carriage returns)
  #   - Comments (both single-line // and multi-line /* */)
  #   - Preprocessor directives (lines starting with #, including multi-line directives)
  #
  # NOTE: C extraction is not implemented as a full C parser and/or preprocessor
  # We assume that the file to be processed is either relatively simple or has already been 
  # preprocessed to remove complex preprocessor directives, etc. Certain complex blocks
  # cannot be processed by this method.
  # 
  # This method repeatedly scans for and skips these elements until no more are found,
  # ensuring all consecutive deadspace is consumed in a single call.
  # 
  # Parameters:
  #   scanner: StringScanner positioned at potential deadspace
  # 
  # Returns: Number of bytes skipped
  # 
  # Side effects: Advances scanner position past all consecutive deadspace
  # 
  # Examples:
  #   "   \n// comment\n#define FOO\ncode" -> skips to "code"
  #   "/* block */  \t\ncode"              -> skips to "code"
  #   "code"                               -> skips 0 bytes (no deadspace)
  def skip_deadspace(scanner)
    start_pos = scanner.pos

    loop do
      initial = scanner.pos
      
      # Skip whitespace
      scanner.skip(/\s+/)
      
      # Skip comments
      skip_comment(scanner) if scanner.check(%r{/[/*]})
      
      # Skip preprocessor directives
      skip_preprocessor_directive(scanner) if scanner.check(/#/)
      
      # If nothing was skipped, we're done
      break if scanner.pos == initial
    end

    return (scanner.pos - start_pos)
  end
  
  def skip_comment(scanner)
    # Single line comment
    if scanner.scan(%r{//})
      scanner.skip_until(/\n/) || scanner.terminate
    # Multiline comment
    elsif scanner.scan(%r{/\*})
      scanner.skip_until(%r{\*/}) || scanner.terminate
    end
  end
  
  # Skip preprocessor directives (lines starting with #)
  # Handles multiline directives with backslash continuation
  def skip_preprocessor_directive(scanner)
    return false unless scanner.scan(/#/)
    
    # Skip the rest of the directive line, handling line continuations
    loop do
      # Scan to end of line or backslash
      scanner.scan(/[^\n\\]*/)
      
      # Check if line continues
      if scanner.scan(/\\\n/)
        # Line continues, keep scanning
        next
      else
        # End of directive - consume the newline if present
        scanner.scan(/\n/)
        break
      end
    end
    
    true
  end
  
  # Skip module-level variable declarations (declarations ending with semicolon)
  # This distinguishes between:
  #   - "int foo;" (variable - skip)
  #   - "int foo() {" (function - don't skip)
  # def skip_variable_declaration(scanner)
  #   start_pos = scanner.pos
  #   paren_depth = 0
  #   found_paren = false
    
  #   until scanner.eos?
  #     char = scanner.peek(1)
      
  #     case char
  #     when '('
  #       found_paren = true
  #       paren_depth += 1
  #       scanner.getch
  #     when ')'
  #       paren_depth -= 1
  #       scanner.getch
  #       # If we close all parens and next is '{', this is a function, not a variable
  #       if paren_depth == 0 && found_paren
  #         skip_deadspace(scanner)
  #         if scanner.peek(1) == '{'
  #           # This is a function, rewind and return false
  #           scanner.pos = start_pos
  #           return false
  #         end
  #       end
  #     when ';'
  #       # Found semicolon - this is a variable declaration, consume it and return true
  #       scanner.getch
  #       return true
  #     when '{'
  #       # Found opening brace without proper function signature - could be:
  #       # - struct/union/enum definition
  #       # - array initialization
  #       # Either way, skip the entire braced block
  #       if extract_balanced_braces(scanner)
  #         # After the braces, there might be a semicolon (e.g., "struct foo {...};")
  #         skip_deadspace(scanner)
  #         scanner.getch if scanner.peek(1) == ';'
  #         return true
  #       else
  #         # Incomplete braces, rewind
  #         scanner.pos = start_pos
  #         return false
  #       end
  #     when '"', "'"
  #       skip_c_string(scanner, char)
  #     when '/'
  #       if scanner.peek(2) =~ %r{^(/[/*])}
  #         skip_comment(scanner)
  #       else
  #         scanner.getch
  #       end
  #     else
  #       scanner.getch
  #     end
      
  #     # Don't scan too far
  #     return false if scanner.pos - start_pos > 10000
  #   end
    
  #   # Incomplete declaration, rewind
  #   scanner.pos = start_pos
  #   false
  # end  
end
