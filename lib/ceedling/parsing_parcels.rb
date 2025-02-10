# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/encodinator'

# This is a collection of parsing aids to be used in other modules
class ParsingParcels

  # This parser accepts a collection of lines which it will sweep through and tidy, giving the purified
  # lines to the block (one line at a time) for further analysis. It analyzes a single line at a time, 
  # which is far more memory efficient and faster for large files. However, this requires it to also 
  # handle backslash line continuations as a single line at this point.
  def code_lines(input)
    comment_block = false
    full_line = ''
    input.each_line do |line|
      m = line.match /(.*)\\\s*$/
      if (!m.nil?)
          full_line += m[1]
      elsif full_line.empty?
        _line, comment_block = clean_code_line( line, comment_block )
        yield( _line )
      else
        _line, comment_block = clean_code_line( full_line + line, comment_block )
        yield( _line )
        full_line = ''
      end
    end    
  end

  private ######################################################################

  def clean_code_line(line, comment_block)
    _line = line.clean_encoding

    # Remove line comments
    _line.gsub!(/\/\/.*$/, '')

    # Handle end of previously begun comment block
    if comment_block
      if _line.include?( '*/' )
        # Turn off comment block handling state
        comment_block = false
        
        # Remove everything up to end of comment block
        _line.gsub!(/^.*\*\//, '')
      else
        # Ignore contents of the line if its entirely within a comment block
        return '', comment_block        
      end

    end

    # Block comments inside a C string are valid C, but we remove to simplify other parsing.
    # No code we care about will be inside a C string.
    # Note that we're not attempting the complex case of multiline string enclosed comment blocks
    _line.gsub!(/"\s*\/\*.*"/, '')

    # Remove single-line block comments
    _line.gsub!(/\/\*.*\*\//, '')

    # Handle beginning of any remaining multiline comment block
    if _line.include?( '/*' )
      comment_block = true

      # Remove beginning of block comment
      _line.gsub!(/\/\*.*/, '')
    end

    return _line, comment_block
  end

end
