# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

class PreprocessinatorCodeFinder

  constructor :file_wrapper

  LINE_MARKER_REGEX = /^#\s+(\d+)\s+"[^"]+"[^\n]*\n/ unless const_defined?(:LINE_MARKER_REGEX)

  # Regex-special-character-immune string
  WHITESPACE_MARKER = '<!@_ws_!@>' unless const_defined?(:WHITESPACE_MARKER)

  # Open a GCC preprocessor output file once and search it for each code block.
  # Returns each block's 1-indexed source line number, or nil where it isn't found.
  # One read serves every function a file holds. With nothing to find, no file is opened.
  def find_all_in_preprocessed_file(filepath, codes)
    return [] if codes.empty?

    # `filepath` is this same build's own gcc preprocessor output -- open_with_retry
    # rides out the file briefly not yet being visible right after the shell-out exits.
    @file_wrapper.open_with_retry( filepath, 'r' ) do |file|
      return find_all_in_preprocessed_content( file.read, codes )
    end
  end

  # Search a GCC preprocessor output string for code.
  # Returns the 1-indexed source line number of the match, or nil if not found.
  # Intended for test use so that specs require no temporary files.
  def find_in_preprocessed_string(content, code)
    return find_all_in_preprocessed_content( content, [code] ).first
  end

  # Open a C source file once and search it for each code block.
  # Returns each block's 1-indexed line number, or nil where it isn't found.
  # With nothing to find, no file is opened.
  def find_all_in_c_file(filepath, codes)
    return [] if codes.empty?

    @file_wrapper.open( filepath, 'r' ) do |file|
      return find_all_in_c_content( file.read, codes )
    end
  end

  # Search a C file content string for code.
  # Returns the 1-indexed source line number of the match, or nil if not found.
  # Partials searches file text it has already read this way.
  def find_in_c_string(content, code)
    return find_all_in_c_content( content, [code] ).first
  end

  private

  # Search GCC preprocessor output for an exact match of each code block.
  #
  # GCC preprocessor output intersperses the expanded source text with line
  # markers of the form:
  #   # <linenum> "<filename>" [flags]
  #
  # Each marker declares that the source line immediately following it
  # corresponds to line linenum in the named file. Subsequent non-marker lines
  # increment the source line count by one each.
  #
  # Each block is located as a substring of the whole content. Its source line is
  # the nearest marker ending at or before the match, plus the newlines between:
  #   marker_linenum + (newlines between marker end and match start)
  #
  # The markers are indexed once, on the first match, so every block after it
  # costs only its own search.
  #
  # A block's line is nil when the block is absent. It is also nil when no line
  # marker precedes the block, a sign of malformed preprocessor output.
  def find_all_in_preprocessed_content(content, searches)
    return Array.new( searches.size ) if content.nil? || content.empty?

    markers = nil
    return searches.map do |search|
      match_pos = whitespace_insensitive_search( content, search )
      next nil if match_pos.nil?

      markers ||= line_markers( content )
      preprocessed_line( content, markers, match_pos )
    end
  end

  # Each line marker's end position and the line number it names, in file order
  def line_markers(content)
    markers = []
    content.scan( LINE_MARKER_REGEX ) { markers << [$~.end( 0 ), $~[1].to_i] }
    return markers
  end

  # The source line of a match, from the last marker that ends at or before it
  def preprocessed_line(content, markers, match_pos)
    following = markers.bsearch_index { |(stop, _)| stop > match_pos } || markers.size
    return nil if following.zero?

    stop, line_num = markers[following - 1]
    return line_num + content[stop, match_pos - stop].count( "\n" )
  end

  # Search C code for an exact match of each code block. Returns each block's
  # 1-indexed line number, or nil where it isn't found.
  def find_all_in_c_content(content, searches)
    return Array.new( searches.size ) if content.nil? || content.empty?

    return searches.map do |search|
      match_pos = whitespace_insensitive_search( content, search )
      match_pos.nil? ? nil : content[0, match_pos].count( "\n" ) + 1
    end
  end

  def whitespace_insensitive_search(content, code)
    # Collapse whitespace to a unique token
    _code = code.gsub(/\s+/, WHITESPACE_MARKER)

    # Escape the code block to search for.
    # Note: Regexp#escape escapes each piece of whitespace and, so, we must take the preparation step above.
    _code = Regexp.escape( _code )

    # Replace the whitespace token with regex whitespace-insenstive matcher
    _code.gsub!(/#{WHITESPACE_MARKER}/, '\s+')

    # Code starting with a word can't start in the middle of one, so `int f(void);` never
    # matches inside `uint f(void);`
    _code = '(?<!\w)' + _code if code.match?( /\A\w/ )

    # Create the regex we'll use
    pattern = Regexp.new( _code )

    # Try to find the code block
    matched = pattern.match( content )

    # Failed to match
    return matched if matched.nil?

    # Return position of the match within `content`
    return matched.begin( 0 )
  end


end
