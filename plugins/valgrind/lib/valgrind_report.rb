# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'cgi'

# The first memory error in a Valgrind report, named by its description and the first
# stack frame that has a source location
module ValgrindReport

  # In a text log, an error's description line is followed at once by its first frame.
  # Valgrind's header and termination notices are not.
  TEXT_ERROR = /^==\d+== (\S[^\n]*)\n((?:==\d+==\s+(?:at|by) 0x\h+:[^\n]*\n)+)/
  TEXT_FRAME = /\(([^()\s]+:\d+)\)$/

  def self.first_error(contents, xml:)
    return xml ? from_xml( contents ) : from_text( contents )
  end

  def self.from_text(contents)
    match = contents.match( TEXT_ERROR )
    return nil if match.nil?

    frame = match[2].lines.map { |line| line.chomp[TEXT_FRAME, 1] }.compact.first
    return describe( match[1], frame )
  end

  # A leak's description sits in <xwhat><text> where other errors use <what>
  def self.from_xml(contents)
    error = contents[%r{<error>.*?</error>}m]
    return nil if error.nil?

    what  = error[%r{<what>(.*?)</what>}m, 1] || error[%r{<xwhat>\s*<text>(.*?)</text>}m, 1]
    frame = error.scan( %r{<frame>(.*?)</frame>}m ).flatten.map { |body| xml_location( body ) }.compact.first
    return what && describe( CGI.unescapeHTML( what ), frame )
  end

  def self.xml_location(frame)
    file = frame[%r{<file>(.*?)</file>}m, 1]
    line = frame[%r{<line>(\d+)</line>}m, 1]
    return file && line && "#{file}:#{line}"
  end

  def self.describe(what, location)
    return location ? "#{what} at #{location}" : what
  end

  private_class_method :from_text, :from_xml, :xml_location, :describe
end
