# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Parses gcc's `-M`/`-MM`/`-MMD` Makefile-dialect dependency output into a plain
# `{ target => [dep, dep, ...] }` mapping. Pure string processing -- no filesystem
# access, so it works identically whether the content came from a real `.d` file
# or an in-memory string handed to it directly (e.g. from a test, or a caller
# that already has the content in hand).
#
# Handles:
# - Backslash-newline line continuations (`\` at end of line joins with the next).
# - Multiple targets in one blob, including `-MP` phony no-prerequisite targets
#   (`some_header.h:` with nothing after the colon).
# - Multiple targets sharing one prerequisite list on a single logical line
#   (`a.o b.o: common.h`), valid Make syntax though gcc rarely emits it directly.
# - Escaped spaces in paths (`\ ` -> literal space), as gcc emits for paths
#   containing spaces.
# - Windows drive-letter paths (`C:\foo\bar.h`): the drive-letter colon is not
#   mistaken for the target/prerequisite separator because a real separator
#   colon must be followed by whitespace or end-of-line, while a drive-letter
#   colon is immediately followed by `\` or `/`.
class GccDependencyParser

  # A logical line's target/prerequisite separator: a colon immediately
  # followed by whitespace or end-of-line. A colon immediately followed by
  # `\` or `/` (a Windows drive letter) does not match and is skipped over.
  SEPARATOR_RE = /\A(.*?):(?=[ \t]|\z)[ \t]*(.*)\z/ unless const_defined?(:SEPARATOR_RE, false)

  # A token is a maximal run of "escaped character" or "non-whitespace"
  # sequences -- this keeps an escaped space (`\ `) glued to its token instead
  # of splitting on it as a token boundary.
  TOKEN_RE = /(?:\\.|\S)+/ unless const_defined?(:TOKEN_RE, false)

  # Parses `content` (a String) and returns `{ target => [dep, ...] }`.
  # Returns `{}` for nil/blank content. Never raises on malformed input --
  # lines that don't contain a recognizable target/prerequisite separator are
  # skipped rather than treated as an error, since a `.d` file may have been
  # truncated by an interrupted build or hand-edited.
  def parse(content)
    targets = {}
    return targets if content.nil?

    join_line_continuations( content ).each_line do |line|
      line = line.strip
      next if line.empty?

      m = line.match( SEPARATOR_RE )
      next if m.nil?

      target_tokens = tokenize( m[1] )
      dep_tokens    = tokenize( m[2] )

      target_tokens.each do |target|
        (targets[target] ||= []).concat( dep_tokens )
      end
    end

    targets.transform_values { |deps| deps.uniq }
  end

  ### Private ###
  private

  def join_line_continuations(content)
    content.gsub( /\\\r?\n/, ' ' )
  end

  def tokenize(text)
    return [] if text.nil?
    text.scan( TOKEN_RE ).map { |token| unescape( token ) }
  end

  # gcc escapes only spaces and `#` (Makefile comment character) with a
  # backslash in its dependency output. Backslashes are otherwise significant
  # and literal -- most notably as Windows path separators (`C:\proj\foo.c`)
  # -- so only these two specific escapes are unescaped; any other backslash
  # is left exactly as-is.
  def unescape(token)
    token.gsub( /\\([ #])/ ) { $1 }
  end

end
