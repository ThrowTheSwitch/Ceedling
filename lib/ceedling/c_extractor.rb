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
  DEFAULT_MAX_SIGNATURE_LENGTH = 1000             # 1000 character safety limit

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
  
  # Factory method for file-based extraction
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
      max_signature_length: DEFAULT_MAX_SIGNATURE_LENGTH
    )
  end
  
  # Factory method for string-based extraction (testing)
  def self.from_string(
    content:,
    # Exposed for testing purposes
    chunk_size: DEFAULT_CHUNK_SIZE,
    max_function_length: DEFAULT_MAX_FUNCTION_LENGTH,
    max_signature_length: DEFAULT_MAX_SIGNATURE_LENGTH
  )
    return new(
      io: StringIO.new(content),
      chunk_size: chunk_size,
      max_function_length: max_function_length,
      max_signature_length: max_signature_length
    )
  end
  
  def initialize(io:, chunk_size:, max_function_length:, max_signature_length:)
    @io = io
    @chunk_size = chunk_size
    @max_function_length = max_function_length
    @max_signature_length = max_signature_length
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
      func = extract_next_function(@io)
      functions << func if func
    end
    
    # Second pass: Extract all variables
    # @io.rewind
    # until @io.eof?
    #   var = extract_next_variable(@io)
    #   variables << var if var
    # end
    
    return CModule.new(funcs: functions, vars: variables)
  ensure
    @io.close
  end
  
  private
  
  def extract_next_function(io)
    buffer = ""
    chunk_start_pos = io.pos
    
    # Read chunks until we find a complete function
    loop do
      # Read next chunk
      chunk = io.read(@chunk_size)
      break unless chunk # EOF
      
      buffer << chunk
      
      # Try to extract a function from buffer
      scanner = StringScanner.new(buffer)
      
      skip_deadspace(scanner)

      # Reached end of string having found no function -- skip to next chunk
      next if scanner.eos?
      
      # Try to find and extract complete function
      success, func = try_extract_function(scanner)
      if success
        # Rewind IO buffer to immediately after this function so next call starts at the right place
        io.seek(chunk_start_pos + scanner.pos)
        
        return func
      end
      
      # No complete function yet -- need more data
      # Safety check -- don't let buffer grow indefinitely
      if buffer.length > @max_function_length
        _name = func.name ? "`#{func.name}()` " : ''
        raise CeedlingException.new("Function #{_name}exceeds maximum length of #{@max_function_length} characters")
      end
    end
    
    # Reached EOF without finding complete function
    nil
  end

  # Try to extract a complete function from the scanner
  # Returns [success, function_data] where:
  #   - success: boolean indicating if extraction was successful
  #   - function_data: CFunction with as much info as available (may be partial on failure)
  def try_extract_function(scanner)
    start_pos = scanner.pos
    
    # Look for function signature
    signature = extract_signature(scanner)
    return [false, CFunction.new] unless signature
    
    skip_deadspace(scanner)
    unless scanner.peek(1) == '{'
      return [false, CFunction.new(
        name: parse_function_name(signature),
        signature: signature
      )]
    end
    
    # Extract function body
    body_start = scanner.pos
    unless extract_balanced_braces(scanner)
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
      body: scanner.string[body_start...scanner.pos],
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
  # A valid signature must:
  #   1. Contain balanced parentheses (for parameter list)
  #   2. Be followed by an opening brace '{' (function definition)
  #   3. Not be followed by a semicolon (which would indicate a declaration)
  # Returns the signature string if valid, nil otherwise
  def extract_signature(scanner)
    start_pos = scanner.pos
    paren_depth = 0
    found_parens = false
    in_string = false
    string_char = nil
    
    until scanner.eos?
      char = scanner.peek(1)
      
      # Safety check
      if scanner.pos - start_pos > @max_signature_length
        raise CeedlingException.new("Function signature exceeds maximum length of #{@max_signature_length} characters")
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
        found_parens = true
        paren_depth += 1
        scanner.getch
      when ')'
        paren_depth -= 1
        scanner.getch
        if paren_depth == 0 && found_parens
          # Found balanced parentheses - this could be a function signature
          signature = scanner.string[start_pos...scanner.pos].strip
          # Return signature as single line with no original line breaks
          return signature.gsub(/\r\n|\r|\n/, ' ')
        end
      when '{'
        # Hit opening brace before finding balanced parens
        # This is NOT a function (e.g., struct definition)
        scanner.pos = start_pos
        return nil
      when ';'
        # Hit semicolon before finding balanced parens
        # This is NOT a function
        scanner.pos = start_pos
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
  # Returns true if a complete balanced block was found, false otherwise
  # Side effect: Advances scanner position past the closing brace on success
  def extract_balanced_braces(scanner)
    # Verify we're starting at an opening brace
    return false unless scanner.getch == '{'
    
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
        return true if depth == 0
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
    false
  end
  
  def skip_c_string(scanner, quote)
    scanner.getch # Opening quote
    
    until scanner.eos?
      if scanner.scan(/\\/)
        scanner.getch
      elsif scanner.getch == quote
        break
      end
    end
  end
  
  def skip_comment(scanner)
    if scanner.scan(%r{//})
      scanner.skip_until(/\n/) || scanner.terminate
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
  def skip_variable_declaration(scanner)
    start_pos = scanner.pos
    paren_depth = 0
    found_paren = false
    
    until scanner.eos?
      char = scanner.peek(1)
      
      case char
      when '('
        found_paren = true
        paren_depth += 1
        scanner.getch
      when ')'
        paren_depth -= 1
        scanner.getch
        # If we close all parens and next is '{', this is a function, not a variable
        if paren_depth == 0 && found_paren
          skip_deadspace(scanner)
          if scanner.peek(1) == '{'
            # This is a function, rewind and return false
            scanner.pos = start_pos
            return false
          end
        end
      when ';'
        # Found semicolon - this is a variable declaration, consume it and return true
        scanner.getch
        return true
      when '{'
        # Found opening brace without proper function signature - could be:
        # - struct/union/enum definition
        # - array initialization
        # Either way, skip the entire braced block
        if extract_balanced_braces(scanner)
          # After the braces, there might be a semicolon (e.g., "struct foo {...};")
          skip_deadspace(scanner)
          scanner.getch if scanner.peek(1) == ';'
          return true
        else
          # Incomplete braces, rewind
          scanner.pos = start_pos
          return false
        end
      when '"', "'"
        skip_c_string(scanner, char)
      when '/'
        if scanner.peek(2) =~ %r{^(/[/*])}
          skip_comment(scanner)
        else
          scanner.getch
        end
      else
        scanner.getch
      end
      
      # Don't scan too far
      return false if scanner.pos - start_pos > 10000
    end
    
    # Incomplete declaration, rewind
    scanner.pos = start_pos
    false
  end
  
  # Deadspace = Whitespace, comments, preprocessor directives, and variable declarations
  def skip_deadspace(scanner)
    loop do
      initial = scanner.pos
      
      # Skip whitespace
      scanner.skip(/\s+/)
      
      # Skip comments
      skip_comment(scanner) if scanner.check(%r{/[/*]})
      
      # Skip preprocessor directives
      skip_preprocessor_directive(scanner) if scanner.check(/#/)
      
      # Skip variable declarations
      skip_variable_declaration(scanner) if scanner.check(/\w/)
      
      # If nothing was skipped, we're done
      break if scanner.pos == initial
    end
  end
end
