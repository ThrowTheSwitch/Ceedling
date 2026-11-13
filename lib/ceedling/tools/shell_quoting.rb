# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'

# Reads the quoting in one piece of a command line as the shell running it will.
#
# A tool's command reaches the shell as one string, so a quote one piece leaves open pairs
# with a quote in a later piece and the command's words shift. A typographic quote looks
# like a quote but is an ordinary character to every shell.
module ShellQuoting

  TYPOGRAPHIC = %w[“ ” „ ‟ ‘ ’ ‚ ‛ « » ‹ ›].freeze

  # Each alternative consumes one escaped character or one closed span, in that order, so a
  # quote matched alone is one that never closes. A backslash escapes the character after
  # it, except inside single quotes.
  SPANS = /\\.|"(?:\\.|[^"\\])*"|'[^']*'|["']/m

  # cmd.exe treats a single quote as an ordinary character
  WINDOWS_SPANS = /\\.|"(?:\\.|[^"\\])*"|"/m

  # The quote character `text` leaves open, or nil when every quote closes
  def self.unclosed(text, windows:)
    return scannable( text ).scan( windows ? WINDOWS_SPANS : SPANS ).find { |span| span == '"' or span == "'" }
  end

  # The distinct typographic quotes in `text`, in the order they first appear
  def self.typographic(text)
    return scannable( text ).each_char.select { |char| TYPOGRAPHIC.include?( char ) }.uniq
  end

  # `text` with invalid bytes replaced and everything from its first Ruby expansion through
  # its last removed, since an expansion's own quotes are Ruby's, not the shell's. A quote
  # between two expansions goes unread, so a mistake there is missed rather than invented.
  def self.scannable(text)
    return text.scrub.gsub( PATTERNS::RUBY_STRING_REPLACEMENT, '' )
  end
  private_class_method :scannable

end
