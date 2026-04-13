# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

class CExtractorPreprocessing

  # Directive type symbols for use with filter_directive()
  MACRO_DEFINITION = :macro_definition

  constructor :c_extractor_code_text

  # Scan `scanner` for calls to any macro in `macro_names` and return them as a
  # flat Array of cleaned strings in order of appearance. Each string is the full
  # macro call with its argument list on a single line, runs of whitespace
  # (including embedded newlines) collapsed to a single space.
  #
  # - Macro calls inside C line or block comments are skipped.
  # - String literals (including those containing commas, parens, or a macro name)
  #   are collected verbatim and do not cause false positives or broken extraction.
  #
  # @param scanner [StringScanner] positioned anywhere in the source text
  # @param macro_names [Array<String>] macro names to search for
  # @return [Array<String>] cleaned macro call strings
  def try_extract_macro_calls(scanner, macro_names)
    results = []
    pattern = _build_pattern(macro_names)

    until scanner.eos?
      # Skip comments — macro names inside are not extracted
      if scanner.check( %r{/[/*]} )
        @c_extractor_code_text.skip_comment(scanner)

      # Skip string/char literals — macro names inside are not extracted
      elsif (ch = scanner.peek(1)) == '"' || ch == "'"
        @c_extractor_code_text.skip_c_string(scanner, ch)

      # Found a macro name followed by '(' — collect its argument list.
      # Guard against matching a suffix of a longer identifier (e.g., FOO inside NOTFOO).
      # Note: `\b` and lookbehinds are unreliable in StringScanner because the engine
      # only sees the remaining suffix; we inspect the original string manually instead.
      elsif scanner.scan(pattern)
        macro_name  = scanner[1]
        match_start = scanner.pos - scanner.matched.length
        if match_start > 0 && scanner.string[match_start - 1] =~ /\w/
          _collect_balanced_args(scanner)  # consume and discard — part of a longer identifier
        else
          args = _collect_balanced_args(scanner)
          results << _clean_whitespace("#{macro_name}(#{args})") if args
        end

      else
        scanner.getch
      end
    end

    return results
  end

  # Parse a single macro call string (as returned by `try_extract_macro_calls`) into its
  # macro name and an array of individual parameter strings.
  #
  # Top-level commas (not nested inside `()`, `[]`, `{}`, or string literals) are
  # treated as argument separators. Each returned parameter is trimmed of leading
  # and trailing whitespace.
  #
  # @param call_str [String] a cleaned macro call string, e.g. "FOO(a, b, [c, d])"
  # @return [Array(String, Array<String>)] two-element array of [macro_name, params]
  #   where macro_name is nil and params is [] if the string is malformed
  def parse_macro_call(call_str)
    scanner = StringScanner.new( call_str )

    # Extract macro name — everything before the opening '('
    macro_name = scanner.scan( /[^(]+/ )&.strip
    return [nil, []] if macro_name.nil? || !scanner.scan( /\(/ )

    return [macro_name, _split_params(scanner)]
  end

  # Try to extract a C preprocessing directive from the scanner.
  # Called as a feature extractor by CExtractor#extract_next_feature.
  # Returns every directive found as raw text — callers filter by type as needed.
  #
  # @param scanner [StringScanner] positioned at the start of potential directive
  # @return [Array(Boolean, String)]
  #   [true,  '#define FOO 42\n'] — directive text (any directive type)
  #   [false, nil               ] — no # at current position; nothing consumed
  def try_extract_directive(scanner)
    text = _collect_directive(scanner)
    return [false, nil] if text.nil?

    [true, text]
  end

  # Filter a directive string by type, returning the text only if it matches the requested type.
  # This allows callers to selectively collect specific directive types while still ensuring
  # all directives are consumed from the input.
  #
  # @param directive [String] raw directive text (as returned by try_extract_directive)
  # @param type [Symbol] the directive type to match; see MACRO_DEFINITION and other constants
  # @return [String, nil] the directive text if it matches the requested type, nil otherwise
  def filter_directive(directive, type)
    case type
    when MACRO_DEFINITION
      directive.match?(/\A#\s*define\b/) ? directive : nil
    end
  end

  # Try to extract a C typedef declaration from the scanner.
  # Called as a feature extractor by CExtractor#extract_next_feature.
  # Collects everything from the `typedef` keyword through the terminating `;`
  # (handling nested braces for struct/union/enum bodies, string literals,
  # and comments) and returns it as a raw string including any trailing newline.
  #
  # @param scanner [StringScanner] positioned at the start of potential typedef
  # @return [Array(Boolean, String)]
  #   [true,  "typedef struct { int x; } Point;\n"] — full typedef text
  #   [false, nil                                  ] — no typedef keyword here; nothing consumed
  def try_extract_typedef(scanner)
    return [false, nil] unless scanner.check(/typedef\b/)

    text  = +''
    depth = 0   # brace nesting — typedef body terminates only at depth == 0

    until scanner.eos?
      ch = scanner.peek(1)

      if ch == '"' || ch == "'"
        # Capture string/char literals verbatim — a ';' inside must not terminate
        before = scanner.pos
        @c_extractor_code_text.skip_c_string(scanner, ch)
        text << scanner.string[before...scanner.pos]

      elsif scanner.check(%r{/[/*]})
        # Capture comments verbatim — a ';' inside must not terminate
        before = scanner.pos
        @c_extractor_code_text.skip_comment(scanner)
        text << scanner.string[before...scanner.pos]

      elsif scanner.scan(/\{/)
        depth += 1
        text  << '{'

      elsif scanner.scan(/\}/)
        depth -= 1
        text  << '}'

      elsif depth == 0 && scanner.scan(/;/)
        text << ';'
        text << (scanner.scan(/[ \t]*\n/) || '')  # absorb optional trailing newline
        return [true, text]

      else
        text << scanner.getch
      end
    end

    [false, nil]   # EOF without finding ';'
  end

  ### Private ###

  private

  # Build a Regexp matching any of the given macro names followed by optional
  # whitespace and '('. Capture group 1 = matched name.
  # Whether the match starts inside a longer identifier is checked in the caller
  # by inspecting the original string, since StringScanner lookbehinds and `\b`
  # only see the remaining suffix and cannot inspect characters before scanner.pos.
  def _build_pattern(macro_names)
    escaped = macro_names.map { |n| Regexp.escape(n) }
    Regexp.new("(#{escaped.join('|')})\\s*\\(")
  end

  # Collect argument text of a macro call whose opening '(' has already been
  # consumed. Tracks paren depth to find the matching ')'. String literals and
  # comments inside the argument list are handled without breaking depth tracking.
  # Returns the argument string (without the outer parens) or nil on malformed input.
  def _collect_balanced_args(scanner)
    depth  = 1
    buffer = +''

    until scanner.eos?
      ch = scanner.peek(1)

      # Capture string/char literals verbatim — commas, parens, macro names inside
      # strings must not affect argument parsing
      if ch == '"' || ch == "'"
        before = scanner.pos
        @c_extractor_code_text.skip_c_string(scanner, ch)
        buffer << scanner.string[before...scanner.pos]

      # Comments inside args are consumed and replaced with a space
      elsif scanner.check( %r{/[/*]} )
        @c_extractor_code_text.skip_comment(scanner)
        buffer << ' '

      elsif scanner.scan( /\(/ )
        depth  += 1
        buffer << '('

      elsif scanner.scan( /\)/ )
        depth -= 1
        return buffer if depth == 0
        buffer << ')'

      else
        buffer << scanner.getch
      end
    end

    return nil  # unbalanced — malformed input
  end

  # Split parameter text of a macro call whose opening '(' has already been consumed.
  # Splits on top-level commas only — commas inside `()`, `[]`, `{}`, or string
  # literals are not treated as separators. Returns an array of trimmed parameters.
  def _split_params(scanner)
    params    = []
    buffer    = +''
    d_paren   = 0
    d_bracket = 0
    d_brace   = 0

    until scanner.eos?
      ch = scanner.peek(1)

      # String/char literals are captured verbatim — commas and delimiters inside
      # must not affect depth tracking or param splitting
      if ch == '"' || ch == "'"
        before = scanner.pos
        @c_extractor_code_text.skip_c_string( scanner, ch )
        buffer << scanner.string[before...scanner.pos]

      elsif scanner.scan( /\(/ ) ; d_paren   += 1 ; buffer << '('
      elsif scanner.scan( /\[/ ) ; d_bracket += 1 ; buffer << '['
      elsif scanner.scan( /\{/ ) ; d_brace   += 1 ; buffer << '{'
      elsif scanner.scan( /\]/ ) ; d_bracket -= 1 ; buffer << ']'
      elsif scanner.scan( /\}/ ) ; d_brace   -= 1 ; buffer << '}'

      elsif scanner.scan( /\)/ )
        if d_paren == 0
          # Closing outer paren — end of argument list
          params << buffer.strip unless buffer.strip.empty?
          break
        end
        d_paren -= 1
        buffer << ')'

      elsif d_paren == 0 && d_bracket == 0 && d_brace == 0 && scanner.scan( /,/ )
        params << buffer.strip
        buffer = +''

      else
        buffer << scanner.getch
      end
    end

    return params
  end

  # Collect and return the full text of a preprocessing directive starting at '#'.
  # Returns nil if not positioned at '#'. Handles backslash-newline continuations.
  def _collect_directive(scanner)
    return nil unless scanner.check(/#/)

    text = scanner.scan(/#/)

    loop do
      text += scanner.scan(/[^\n\\]*/) || ''

      if scanner.scan(/\\\n/)
        text += "\\\n"
      elsif scanner.scan(/\n/)
        text += "\n"
        break
      else
        break  # EOS — no trailing newline
      end
    end

    text
  end

  # Collapse any run of whitespace (spaces, tabs, newlines) to a single space
  # and strip leading/trailing whitespace.
  def _clean_whitespace(text)
    text.gsub( /\s+/, ' ' ).strip
  end

end
