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

  # Try to extract a C11 _Static_assert or C23 static_assert statement from the scanner.
  # Called as a feature extractor by CExtractor#extract_next_feature.
  # The statement is consumed and the full text returned, but callers discard it —
  # static asserts are not collected into CModule.
  #
  # Handles all three forms:
  #   _Static_assert(expr, "message");   # C11 — message required
  #   static_assert(expr);               # C23 — message optional
  #   static_assert(expr, "message");    # C23 — with message
  #
  # The expression argument may contain arbitrarily nested parentheses
  # (e.g. sizeof(struct S) == 8) which are handled by collect_balanced().
  #
  # @param scanner [StringScanner] positioned at potential static assert
  # @return [Array(Boolean, String|nil)]
  #   [true,  '_Static_assert(sizeof(S) == 4, "msg");\n'] — full statement text
  #   [false, nil                                        ] — not a static assert; scanner unchanged
  def try_extract_static_assert(scanner)
    return [false, nil] unless scanner.check(/(?:_Static_assert|static_assert)\b/)

    text = +''

    # Consume keyword
    # Pattern (?:_Static_assert|static_assert) ensures that a longer identifier (e.g. `not_static_assert`) does not match
    text << scanner.scan(/(?:_Static_assert|static_assert)/)

    # Consume optional whitespace between keyword and '('
    text << (scanner.scan(/[ \t]*/) || '')

    # Consume the balanced argument list — handles all nested parens, strings, comments
    success, args = @c_extractor_code_text.collect_balanced(scanner, '(', ')')
    return [false, nil] unless success
    text << args

    # Consume optional whitespace before ';'
    text << (scanner.scan(/[ \t]*/) || '')

    # Consume the required terminating ';'
    return [false, nil] unless scanner.scan(/;/)
    text << ';'

    # Absorb optional trailing newline (mirrors try_extract_typedef convention)
    text << (scanner.scan(/[ \t]*\n/) || '')

    [true, text]
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
  # consumed by the scan pattern in try_extract_macro_calls. Steps back one
  # position so collect_balanced() can start at '(' and strips the outer parens
  # from the result. Returns nil on malformed (unbalanced) input.
  def _collect_balanced_args(scanner)
    # The outer scan pattern consumed the opening '(' — step back one position
    # so collect_balanced() can start at it.
    scanner.pos -= 1
    success, text = @c_extractor_code_text.collect_balanced(scanner, '(', ')')
    success ? text[1..-2] : nil  # strip outer parens; nil on unbalanced input
  end

  # Tracks paren, bracket, and brace depth simultaneously for comma-splitting — not suitable for collect_balanced()
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
