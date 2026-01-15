require 'strscan'
require 'stringio'

class CExtractinator
  CHUNK_SIZE = 256 * 1024 # 256 KB - enough for most functions
  MAX_FUNCTION_SIZE = 5 * 1024 * 1024 # 5 MB safety limit
  
  # Data class representing an extracted C function
  ExtractedFunction = Struct.new(
    :name,            # Function name only (e.g., "foo")
    :signature,       # Function signature (e.g., "int foo(void)")
    :body,            # Function body including containing braces
    :code_block,      # Complete function text (signature + body)
    :line_count,      # Total number of lines in code_block
    keyword_init: true
  )
  
  # Factory method for file-based extraction
  def self.from_file(filepath)
    new(File.open(filepath, 'r'), File.size(filepath))
  end
  
  # Factory method for string-based extraction (testing)
  def self.from_string(content)
    new(StringIO.new(content), content.bytesize)
  end
  
  def initialize(io, size)
    @io = io
    @file_size = size
  end
  
  def extract_functions
    functions = []
    
    @io.rewind
    until @io.eof?
      func = extract_next_function(@io)
      break unless func
      functions << func
    end
    
    return functions
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
      chunk = io.read(CHUNK_SIZE)
      break unless chunk  # EOF
      
      buffer << chunk
      
      # Try to extract a function from buffer
      scanner = StringScanner.new(buffer)
      
      skip_deadspace(scanner)
      next if scanner.eos?  # Only whitespace/comments, need more
      
      # Try to find and extract complete function
      if func = try_extract_function(scanner)
        # Rewind file to immediately after this function so next call starts at the right place
        io.seek(chunk_start_pos + scanner.pos)
        
        return func
      end
      
      # No complete function yet - need more data
      # Safety check: don't let buffer grow indefinitely
      if buffer.length > MAX_FUNCTION_SIZE
        raise "Function exceeds maximum size at position #{chunk_start_pos}"
      end
    end
    
    # Reached EOF without finding complete function
    nil
  end
  
  def try_extract_function(scanner)
    start_pos = scanner.pos
    
    # Look for function signature
    signature = extract_signature(scanner)
    return nil unless signature
    
    skip_deadspace(scanner)
    return nil unless scanner.peek(1) == '{'
    
    # Extract function body
    body_start = scanner.pos
    return nil unless extract_balanced_braces(scanner)
    
    code_block = scanner.string[start_pos...scanner.pos]
    
    ExtractedFunction.new(
      name: extract_function_name(signature),
      signature: signature,
      body: scanner.string[body_start...scanner.pos],
      code_block: code_block,
      line_count: code_block.count("\n") + 1
    )
  end
  
  def extract_function_name(signature)
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
  
  def extract_signature(scanner)
    sig_start = scanner.pos
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
        if paren_depth == 0 && found_paren
          skip_deadspace(scanner)
          next_char = scanner.peek(1)
          return scanner.string[sig_start...scanner.pos].strip if next_char == '{'
          return nil if next_char == ';'
        end
      when ';', '{'
        return nil
      when '"', "'"
        skip_c_string(scanner, char)
      when '/'
        skip_comment(scanner) if scanner.peek(2) =~ %r{^(/[/*])}
      else
        scanner.getch
      end
      
      # Don't scan too far for signature
      return nil if scanner.pos - sig_start > 10000
    end
    
    nil  # Incomplete signature
  end
  
  def extract_balanced_braces(scanner)
    return false unless scanner.getch == '{'
    
    depth = 1
    
    until scanner.eos?
      char = scanner.peek(1)
      
      case char
      when '{'
        depth += 1
        scanner.getch
      when '}'
        depth -= 1
        scanner.getch
        return true if depth == 0
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
    end
    
    false  # Incomplete braces
  end
  
  def skip_c_string(scanner, quote)
    scanner.getch  # Opening quote
    
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
