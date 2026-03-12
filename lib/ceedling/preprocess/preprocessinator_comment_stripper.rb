# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'stringio'
require 'ceedling/exceptions'

class PreprocessinatorCommentStripper

  constructor :c_comment_scanner


  # Strip all C comments from a file. The file is unchanged if no comments 
  # are found. The routine returns `true` if changes are made, `false` otherwise.
  #
  # Every single-line comment is replaced by a single space. Every multi-line
  # comment is replaced by an equivalent number of newlines.
  def strip_file(filepath)
    stripped = ''
    changed = false

    begin
      File.open(filepath) do |buffer|
        stripped = strip(buffer)  
        changed = !stripped.nil?
      end
    rescue => e
      raise CeedlingException.new("Failed to read '#{filepath}' for comment stripping ⏩️ #{e}")
    end

    # No change
    return changed unless changed

    begin
      File.write(filepath, stripped)
    rescue => e
      raise CeedlingException.new("Failed to rewrite '#{filepath}' after comment stripping ⏩️ #{e}")
    end

    return true
  end

  # Strip all C comments from a string content and return the cleaned content 
  # as a String. The string is unchanged if no comments are found.
  #
  # Every single-line comment is replaced by a single space. Every multi-line
  # comment is replaced by an equivalent number of newlines.
  def strip_string(content)
    buffer = StringIO.new(content)
    stripped = strip(buffer)

    return content if stripped.nil?

    return stripped
  end

  private

  def strip(buffer)
    # Search buffer for comments
    comment_infos = @c_comment_scanner.scan(io: buffer)
    return nil if comment_infos.empty?

    # Reset buffer
    buffer.rewind

    # Remove comments from content of buffer
    return @c_comment_scanner.remove(
      buffer.read,
      comment_infos,
      mode: CCommentScanner::PRESERVE_LINES
    )
  end

end
