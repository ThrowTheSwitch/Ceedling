# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/tools/shell_quoting'

# Finds the quoting problems in a tool definition, one entry at a time.
#
# Each entry that reaches the shell must close its own quotes, since a quote left open pairs
# with one in a later entry. A typographic quote is only a warning, since it may be meant
# literally, as in a string a define holds.
module ToolQuoting

  # `error` is false for a warning
  Finding = Struct.new( :field, :message, :error, keyword_init: true ) do
    # An executable whose quote is unclosed names no file that can be looked for
    def unclosed_executable?
      return (error and field == :executable)
    end
  end

  # The findings for `tool`'s :executable and arguments, in order
  def self.findings(tool, name:, windows:)
    return entries( tool ).filter_map { |field, text| finding( name, field, text, windows ) }
  end

  # Each [field, text] pair the command line is built from
  def self.entries(tool)
    arguments = [tool[:arguments]].flatten.flat_map { |element| expanded( element ) }
    entries   = [[:executable, tool[:executable]]] + arguments.map { |argument| [:arguments, argument] }

    return entries.select { |_, text| text.is_a?( String ) }
  end

  # The text one argument contributes, as ToolExecutor expands it. A string is itself the
  # text. A hash contributes its first key, the substitution string, and each string among
  # that key's values. Anything else adds nothing to the command line.
  def self.expanded(element)
    return [element] if element.is_a?( String )
    return [] unless element.is_a?( Hash ) and element.any?

    substitution, values = element.first
    return [substitution.to_s, *[values].flatten.grep( String )]
  end

  def self.finding(name, field, text, windows)
    location    = "#{name} ↳ :#{field} ➡️ `#{text}`"
    quote       = ShellQuoting.unclosed( text, windows: windows )
    typographic = ShellQuoting.typographic( text )

    return unclosed( location, field, quote, typographic ) if quote
    return nil if typographic.empty?

    message = "#{location} holds #{phrase( typographic )} Use \" or ' unless the characters are meant literally."
    return Finding.new( field: field, message: message, error: false )
  end

  # An unclosed quote's error names any typographic quote as its likely cause
  def self.unclosed(location, field, quote, typographic)
    subject = (field == :executable) ? 'executable' : 'argument'
    message = "#{location} leaves a #{quote} quote unclosed. Enclose the #{subject} with #{quote} quotes."
    message += " It holds #{phrase( typographic )} Replace it with #{quote}." if typographic.any?

    return Finding.new( field: field, message: message, error: true )
  end

  # The typographic quotes found, and what a shell makes of them
  def self.phrase(typographic)
    return "#{typographic.first}, a typographic quote that a shell treats as an ordinary character." if typographic.one?

    return "#{typographic.join( ' ' )}, typographic quotes that a shell treats as ordinary characters."
  end

  private_class_method :entries, :expanded, :finding, :unclosed, :phrase

end
