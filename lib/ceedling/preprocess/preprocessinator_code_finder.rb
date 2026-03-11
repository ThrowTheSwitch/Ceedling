# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'stringio'

class PreprocessinatorCodeFinder

  # Open a GCC preprocessor output file and search it for code.
  # Returns the 1-indexed source line number of the match, or nil if not found.
  # Intended for production use where preprocessor output resides on disk.
  def find_in_file(filepath, code)
    File.open( filepath, 'r' ) do |file|
      return find( io: file, search: code )
    end
  end


  # Wrap a GCC preprocessor output string in a StringIO and search it for code.
  # Returns the 1-indexed source line number of the match, or nil if not found.
  # Intended for test use so that specs require no temporary files.
  def find_in_string(content, code)
    buffer = StringIO.new( content )
    return find( io: buffer, search: code )
  end

  private

  # Search a GCC preprocessor output IO stream for an exact match of search.
  #
  # GCC preprocessor output intersperses the expanded source text with line
  # markers of the form:
  #   # <linenum> "<filename>" [flags]
  #
  # Each marker declares that the source line immediately following it
  # corresponds to line linenum in the named file.  Subsequent non-marker lines
  # increment the source line count by one each.
  #
  # The method locates search as a substring of the full stream content, then
  # walks backwards through the line markers that precede the match to find the
  # most recent one.  The source line number is computed as:
  #   last_marker_linenum + (newlines between marker end and match start)
  #
  # Returns nil when search is not present in the stream or no line marker
  # precedes the match (which indicates malformed preprocessor output).
  def find(io:, search:)
    content = io.read
    return nil if content.nil? || content.empty?

    # Locate the exact search string within the preprocessor output
    match_pos = content.index(search)
    return nil if match_pos.nil?

    # Examine only the content before the match for GCC line markers.
    # Line markers have the form: # <linenum> "<filename>" [optional flags]
    # The linenum in each marker refers to the source line immediately following it.
    prefix = content[0, match_pos]

    last_marker_num = nil
    last_marker_end = 0   # byte position in content after the last marker's newline

    prefix.scan(/^#\s+(\d+)\s+"[^"]+"[^\n]*\n/) do |captures|
      last_marker_num = captures[0].to_i
      last_marker_end = $~.end(0)
    end

    if last_marker_num.nil?
      # No line marker precedes the match -- something is wrong
      return nil
    end

    # Each newline between the end of the last line marker line and the match start
    # advances the source line by one. The marker's linenum is the base.
    newlines_after_marker = content[last_marker_end, match_pos - last_marker_end].count("\n")
    
    return last_marker_num + newlines_after_marker
  end
end
