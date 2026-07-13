# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'strscan'
require 'ceedling/c_extractor/c_extractor_constants'

class CExtractorCodeText

  include CExtractorConstants

  # Collect the full text of a balanced delimiter pair starting AT open_char.
  # Nested pairs, string literals (verbatim), and comments (replaced with a
  # single space) are handled correctly.
  # Returns [true, text_including_delimiters] or [false, nil] on unbalanced input
  # or EOS before the matching close delimiter is found.
  #
  # Works for any single-character delimiter pair: '{}', '()', or '[]'.
  #
  # @param scanner    [StringScanner] positioned at open_char
  # @param open_char  [String] single-character opening delimiter
  # @param close_char [String] single-character closing delimiter
  # @return [Array(Boolean, String|nil)]
  def collect_balanced(scanner, open_char, close_char)
    return [false, nil] unless scanner.peek(1) == open_char

    text  = +scanner.getch  # consume and record open_char
    depth = 1

    until scanner.eos?
      ch = scanner.peek(1)

      if ch == '"' || ch == "'"
        before = scanner.pos
        skip_c_string(scanner, ch)
        text << scanner.string[before...scanner.pos]
      elsif scanner.check(%r{/[/*]})
        skip_comment(scanner)
        text << ' '
      elsif ch == open_char
        depth += 1
        text  << scanner.getch
      elsif ch == close_char
        depth -= 1
        text  << scanner.getch
        return [true, text] if depth == 0
      else
        text << scanner.getch
      end
    end

    [false, nil]
  end

  # Extract a balanced block of braces from the scanner.
  # Delegates to collect_balanced() — see its documentation for full details.
  #
  # @param scanner [StringScanner] positioned at the opening '{'
  # @return [Array(Boolean, String|nil)]
  def extract_balanced_braces(scanner)
    collect_balanced(scanner, '{', '}')
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

  # Skip consecutive semicolons and any intervening deadspace
  #
  # This method handles cases where multiple semicolons appear in sequence,
  # potentially separated by whitespace or comments.
  # This is valid C syntax (null statements) and can occur due to:
  #   - Macro expansions
  #   - Code generation
  #   - Coding mistakes that don't cause compilation errors
  #
  # The method repeatedly:
  #   1. Skips any deadspace (whitespace and comments)
  #   2. Checks for a semicolon
  #   3. If found, consumes it and continues
  #   4. If not found, restores position and exits
  #
  # Parameters:
  #   scanner: StringScanner positioned at potential semicolons/deadspace
  #
  # Returns: Nothing (void method)
  #
  # Side effects: Advances scanner position past all consecutive semicolons and deadspace
  #
  # Examples:
  #   ";;;"               -> skips all three semicolons
  #   "; ; ;"             -> skips semicolons and spaces
  #   "; /* comment */ ;" -> skips semicolons and comment
  #   "; code"            -> skips first semicolon, stops at "code"
  #   "code"              -> skips nothing
  def skip_semicolons(scanner)
    while !scanner.eos?
      start_pos = scanner.pos
      skip_deadspace(scanner)
      break if scanner.eos?
      
      # If we find a semicolon, consume it and continue
      if scanner.scan(/;/)
        next
      else
        # Not a semicolon, restore position and break
        scanner.pos = start_pos
        break
      end
    end
  end

  # Skip "deadspace" - non-code elements that should be ignored during extraction
  # Deadspace includes:
  #   - Whitespace (spaces, tabs, newlines, carriage returns)
  #   - Comments (both single-line // and multi-line /* */)
  #
  # NOTE: Preprocessing directives (lines starting with #) are NOT deadspace —
  # they are first-class features handled by CExtractorPreprocessing.
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
  #   "   \n// comment\ncode" -> skips to "code"
  #   "/* block */  \t\ncode" -> skips to "code"
  #   "code"                  -> skips 0 bytes (no deadspace)
  def skip_deadspace(scanner)
    start_pos = scanner.pos

    loop do
      initial = scanner.pos

      # Skip whitespace
      scanner.skip(/\s+/)

      # Skip comments
      skip_comment(scanner) if scanner.check(%r{/[/*]})

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

  # Skip a single compiler extension at the current scanner position.
  # Uses collect_balanced() for paren matching so all nesting depths are handled.
  # Returns true and advances the scanner if an extension is found; returns false without
  # moving if the current position is not the start of a known compiler extension.
  #
  # Handles:
  #   __word__(…) — any double-underscore attribute form, e.g. __attribute__((…))
  #   __declspec(…) — MSVC declaration specifier, including nested forms
  #   Bare MSVC calling-convention keywords (__cdecl, __stdcall, etc.)
  #
  # Does NOT skip __int64, __int32, or any non-extension __ identifiers.
  def skip_compiler_extension(scanner)
    if scanner.check(/__\w+__\s*\(/)
      scanner.skip(/__\w+__/)
      skip_deadspace(scanner)
      collect_balanced(scanner, '(', ')') if scanner.peek(1) == '('
      return true
    end

    if scanner.check(/__declspec\s*\(/)
      scanner.skip(/__declspec/)
      skip_deadspace(scanner)
      collect_balanced(scanner, '(', ')') if scanner.peek(1) == '('
      return true
    end

    MSVC_CALLING_CONVENTIONS.each do |kw|
      if scanner.check(/#{Regexp.escape(kw)}\b/)
        scanner.skip(/#{Regexp.escape(kw)}/)
        return true
      end
    end

    false
  end

  # Strip all compiler extensions from a string and return the cleaned result.
  # Uses an internal StringScanner plus collect_balanced() so all paren nesting depths
  # are handled correctly (e.g. __declspec(align(8)), __attribute__((format(printf,1,2)))).
  # Whitelist-based: only known forms are stripped; __int64, __int32, and any other
  # non-extension __ identifiers are preserved verbatim.
  # Whitespace is normalized to single spaces and the result is stripped.
  #
  # Handles:
  #   __word__(…) — any double-underscore attribute form
  #   __declspec(…) — MSVC declaration specifier (including nested parens)
  #   Bare MSVC calling conventions, MSVC inline hints, C11 specifier keywords
  def strip_compiler_extensions(text)
    scanner = StringScanner.new(text)
    result  = +""

    bare_strip = MSVC_CALLING_CONVENTIONS +
                 ['__forceinline', '__inline__', '__inline'] +
                 C11_SPECIFIER_KEYWORDS

    until scanner.eos?
      # __word__(…) — any double-underscore attribute form including __attribute__((…))
      if scanner.check(/__\w+__\s*\(/)
        scanner.skip(/__\w+__/)
        skip_deadspace(scanner)
        collect_balanced(scanner, '(', ')') if scanner.peek(1) == '('
        next
      end

      # __declspec(…) — handles nested forms like __declspec(align(8))
      if scanner.check(/__declspec\s*\(/)
        scanner.skip(/__declspec/)
        skip_deadspace(scanner)
        collect_balanced(scanner, '(', ')') if scanner.peek(1) == '('
        next
      end

      # Whitelisted bare keywords (calling conventions, inline hints, C11 specifiers)
      stripped = bare_strip.any? do |kw|
        if scanner.check(/#{Regexp.escape(kw)}\b/)
          scanner.skip(/#{Regexp.escape(kw)}/)
          true
        end
      end
      next if stripped

      result << scanner.getch
    end

    result.gsub!(/\s+/, ' ')
    result.strip!
    result
  end

end