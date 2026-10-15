# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/exceptions'

# The warnings in one build step's tool output, each with the context lines that explain
# it.
#
# GCC and Clang print each diagnostic as a `file:line: kind: message` line, preceded by
# context such as `In function` or `In file included from` lines and followed by the
# source line and a caret. Each such diagnostic becomes one group, and a `note:` joins the
# group before it. A group is a warning when its diagnostic line matches a pattern, by
# default any mention of "warning". Output in any other format is taken a line at a time.
# Summary lines counting warnings (`2 warnings generated.`) are never warnings.
#
# Each warning is a Record of its full text and, for a GCC-style diagnostic, its parsed
# location, severity, message, flag, and context lines. Output in another format has only
# its text and message.
#
# A warning's identity leaves out its context lines, so a header's warning reached
# through several files is one warning.
class WarningCollector

  Record = Struct.new( :file, :line, :column, :severity, :message, :flag, :context, :text, keyword_init: true )

  DEFAULT_PATTERNS = [/warning/i].freeze

  DIAGNOSTIC = /\A\S[^\n]*?:\d+(?::\d+)?:\s+(?:fatal error|error|warning|note|remark)\b/i
  NOTE       = /\A\S[^\n]*?:\d+(?::\d+)?:\s+note\b/i
  CONTEXT    = /\A(?:In file included from |\s+from |\S[^\n]*: (?:In (?:function|member function|instantiation)|At (?:top level|global scope)))/
  # A diagnostic line's parts. A Windows drive letter's colon is not followed by digits, so
  # the lazy file match passes it. The flag is a trailing bracketed option such as
  # `[-Wunused-variable]`; other bracketed text stays in the message.
  PARTS      = /\A(?<file>.+?):(?<line>\d+)(?::(?<column>\d+))?:\s+(?<severity>fatal error|error|warning|note|remark):?\s*
                (?<message>.*?)(?:\s+\[(?<flag>-[^\]]+)\])?\s*\z/xi
  SUMMARY    = /\A\d+ (?:warnings?|errors?)(?: and \d+ (?:warnings?|errors?))? generated\.\s*\z/

  # Regular expressions from configured strings. An entry that is not a valid expression
  # stops the build, naming `setting` and the entry.
  def self.compile(entries, setting:)
    return Array( entries ).map do |entry|
      raise CeedlingException.new( "#{setting} entry `#{entry}` is not a string." ) unless entry.is_a?( String )

      Regexp.new( entry )
    rescue RegexpError => e
      raise CeedlingException.new( "#{setting} entry `#{entry}` is not a valid regular expression: #{e.message}" )
    end
  end

  # `patterns` replaces the default warning match; `excludes` drops any warning whose text
  # matches one of them
  def initialize(patterns: nil, excludes: [])
    @patterns = (patterns.nil? or patterns.empty?) ? DEFAULT_PATTERNS : patterns
    @excludes = excludes
  end

  def warnings(output)
    return groups( output ).select { |group| warning?( group ) }.map { |group| record( group ) }.reject { |warning| excluded?( warning.text ) }
  end

  # A warning without the context lines before it, for recognizing one already collected.
  # Those lines vary with the file that included a header and with whatever GCC reported
  # just before, as its `At top level` line does; the diagnostic line itself names where
  # the warning is.
  def identity(warning)
    return warning.text.lines.reject { |line| line.match?( CONTEXT ) }.join
  end

  private

  # Diagnostics with their context, and every other line on its own. Each group's first
  # diagnostic line, or its only line, decides whether it is a warning.
  def groups(output)
    state = { groups: [], context: [], open: nil }
    output.each_line { |line| place( line, state ) }
    return state[:groups]
  end

  # Context lines wait for the diagnostic they introduce, a diagnostic opens a group,
  # a note or any other line joins the open group, and a summary closes it
  def place(line, state)
    case kind( line )
    when :context then state[:context] << line
    when :summary then nil
    when :diagnostic then return open_group( line, state )
    else return (state[:open] ? state[:open] << line : state[:groups] << [line])
    end

    state[:open] = nil
  end

  def open_group(line, state)
    return state[:open] << line if line.match?( NOTE ) and state[:open]

    state[:groups] << (state[:open] = state[:context] + [line])
    state[:context] = []
  end

  def kind(line)
    return :context    if line.match?( CONTEXT )
    return :diagnostic if line.match?( DIAGNOSTIC )
    return :summary    if line.match?( SUMMARY )

    return :other
  end

  def warning?(group)
    return @patterns.any? { |pattern| deciding( group ).match?( pattern ) }
  end

  def deciding(group)
    return group.find { |line| line.match?( DIAGNOSTIC ) } || group.first
  end

  # A group's text, with its deciding line's parts when that line is a diagnostic
  def record(group)
    line  = deciding( group )
    parts = line.match?( DIAGNOSTIC ) ? line.chomp.match( PARTS ) : nil
    return Record.new( message: line.strip, context: [], text: group.join ) if parts.nil?

    context = group.take_while { |each| each.match?( CONTEXT ) }.map( &:chomp )
    return Record.new( **fields( parts ), context: context, text: group.join )
  end

  def fields(parts)
    return {
      file: parts[:file], line: parts[:line].to_i, column: parts[:column]&.to_i, severity: parts[:severity].downcase,
      message: parts[:message], flag: parts[:flag]
    }
  end

  def excluded?(text)
    return @excludes.any? { |pattern| text.match?( pattern ) }
  end

end
