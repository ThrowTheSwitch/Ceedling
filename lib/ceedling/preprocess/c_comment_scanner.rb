# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'stringio'
require 'strscan'

class CCommentScanner

  PRESERVE_LINES = :preserve_lines unless const_defined?( :PRESERVE_LINES )
  COMPACT = :compact unless const_defined?( :COMPACT )

  # Describes a single C comment found within source or preprocessor text.
  #
  # position      - Byte offset of the first comment character (the leading /)
  # length        - Byte count of the complete comment text
  # lines_removed - Number of \n characters within the comment text; equals the
  #                 number of source lines eliminated when the comment is replaced
  #                 by a single space (e.g. a // comment with no continuation → 0;
  #                 a /* ... */ comment spanning 3 physical lines → 2)
  CommentInfo = Struct.new(:position, :length, :lines_removed, keyword_init: true) do
    def initialize(position: nil, length: nil, lines_removed: 0)
      super
    end
  end


  # Given the Array<CommentInfo> from scan, return a copy of
  # content with every comment replaced according to mode:
  #
  #   :compact (default) — every comment replaced by a single space character.
  #   :preserve_lines    — single-line comments (lines_removed == 0) replaced by a
  #                        single space; multi-line comments replaced by
  #                        lines_removed newlines so the total line count is unchanged.
  #
  # Array<CommentInfo> is processed in descending position order (i.e. backwards)
  # to ensure each comment removal does not disturb earlier comments in the content
  # with respect to `CommentInfo` details.
  def remove(content, comment_infos, mode: COMPACT)
    result = content.dup
    # Process in descending position order so earlier byte positions remain valid
    comment_infos.sort_by { |info| -info.position }.each do |info|
      replacement = ' '
      if (mode == PRESERVE_LINES && info.lines_removed > 0)
        replacement = "\n" * info.lines_removed        
      end

      result[info.position, info.length] = replacement
    end
    return result
  end

  # Scan an IO stream (File or StringIO) and return all C comments found.
  # Returns an Array<CommentInfo> in ascending position order.
  #
  # Uses StringScanner for a single-pass scan.  Recognises string/character
  # literals and prevents comment detection inside them.
  #
  # Records:
  #   - // single-line comments (with optional backslash continuation lines)
  #   - /* ... */ block comments (including multiline; unterminated at EOF)
  def scan(io:)
    content = io.read
    return [] if content.nil? || content.empty?

    scanner  = StringScanner.new(content)
    comments = []

    until scanner.eos?
      ch = scanner.peek(1)

      case ch
      when '"', "'"
        # Skip string or character literal -- any // or /* */ inside is not a comment
        skip_string_literal(scanner, ch)

      when '/'
        two = scanner.peek(2)

        if two == '//'
          start = scanner.pos
          scan_line_comment(scanner)
          len = scanner.pos - start
          comments << CommentInfo.new(
            position:      start,
            length:        len,
            lines_removed: content[start, len].count("\n")
          )

        elsif two == '/*'
          start = scanner.pos
          scan_block_comment(scanner)
          len = scanner.pos - start
          comments << CommentInfo.new(
            position:      start,
            length:        len,
            lines_removed: content[start, len].count("\n")
          )

        else
          scanner.getch
        end

      else
        scanner.getch
      end
    end

    return comments
  end


  private

  # Advance the scanner past a string or character literal.
  # Called when the scanner is positioned at the opening quote character.
  # Handles escape sequences so an escaped quote does not close the literal.
  def skip_string_literal(scanner, quote)
    scanner.getch  # consume opening quote
    until scanner.eos?
      ch = scanner.getch
      if ch == '\\'
        scanner.getch unless scanner.eos?  # skip one escaped character
      elsif ch == quote
        break
      end
    end
  end


  # Advance the scanner past a // line comment.
  #
  # A backslash followed by optional spaces or tabs and then a newline is a line
  # continuation -- the comment extends onto the next physical line.  A bare
  # newline (without a preceding backslash) ends the comment; that newline is left
  # unconsumed so that the caller's line-number tracking remains correct.
  #
  # // inside a /* */ block is not a line-comment start -- this method is only
  # called when we are in :normal state.
  def scan_line_comment(scanner)
    scanner.skip(/\/\//)  # consume //

    loop do
      # Skip bulk of non-special characters efficiently
      scanner.skip(/[^\\\n]+/)
      break if scanner.eos?

      if scanner.scan(/\\[ \t]*\n/)
        # Backslash + optional whitespace + newline: line continuation
        next
      elsif scanner.check(/\n/)
        # Bare newline: end of comment; leave it unconsumed
        break
      else
        # Lone backslash (not before whitespace+newline) or any other character
        scanner.getch
      end
    end
  end


  # Advance the scanner past a /* ... */ block comment.
  # Handles unterminated comments by advancing to the end of the stream.
  # // sequences inside a block comment are not line-comment starts.
  def scan_block_comment(scanner)
    scanner.skip(/\/\*/)  # consume /*
    unless scanner.skip_until(%r{\*/})
      scanner.terminate   # unterminated block comment: consume to EOF
    end
  end

end
