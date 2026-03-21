# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

class CExtractorMacros

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
  def try_extract_calls(scanner, macro_names)
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

  # Collapse any run of whitespace (spaces, tabs, newlines) to a single space
  # and strip leading/trailing whitespace.
  def _clean_whitespace(text)
    text.gsub( /\s+/, ' ' ).strip
  end

end
