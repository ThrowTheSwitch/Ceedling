# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/exceptions'

# Compiles Ceedling's report templates into Ruby and evaluates them.
#
# This replaced ERB, whose gem was dropped as a Ceedling dependency. Ceedling used
# a small corner of ERB, so the template language supported here is deliberately
# narrow. Ruby lines introduced by a percent in column zero, and output tags of the
# form <%= expression %>. Comment tags and bare code tags are also compiled, since
# they cost nothing and a template author may reasonably reach for them.
#
# Behavior matches ERB's own `trim_mode: "%<>"` setting, which is what Ceedling
# passed. Two failure cases diverge on purpose. ERB responded to an unterminated
# tag by treating the remainder of the template as Ruby, which produced garbled
# output instead of an error. ERB also accepted a tag spanning lines. Both now
# raise and name the offending template line.
class Templateinator

  # Tags are matched non-greedily so several can share a line.
  TAG = /<%(=|\#)?(.*?)%>/

  # Finds a tag opening that TAG did not consume, which means it was never closed on
  # this line. The negative lookahead keeps an escaped <%% from being mistaken for one.
  UNCLOSED_TAG = /<%(?!%)/

  # Names the eval'd source so a template error reads as "(ceedling template):17"
  # and points at template line 17. The compiled source keeps one generated line per
  # template line to make that line number true.
  SOURCE_NAME = '(ceedling template)'

  BUFFER = '_ceedling_template_out'

  def render(template, context_binding)
    return eval( compile( template ), context_binding, SOURCE_NAME, 1 )
  end

  ### Private ###

  private

  def compile(template)
    lines = []

    template.each_line.with_index( 1 ) do |line, number|
      lines << compile_line( line, number )
    end

    return "#{BUFFER} = +''; #{BUFFER}" if lines.empty?

    # The buffer is set up on the first generated line and returned on a line of its
    # own after the last, so every template line still maps to the generated line of
    # the same number and reported error locations stay true.
    lines[0] = "#{BUFFER} = +''; #{lines[0]}"
    lines << BUFFER

    return lines.join( "\n" )
  end


  def compile_line(line, number)
    # A percent in column zero introduces Ruby. Stripping exactly one character
    # preserves whatever indentation follows, which Ceedling's templates rely on to
    # show nesting, and leaves a trailing Ruby comment as ordinary Ruby.
    if line.start_with?( '%' ) && !line.start_with?( '%%' )
      return line[1..].chomp
    end

    # An escaped percent at column zero yields one literal percent.
    line = line[1..] if line.start_with?( '%%' )

    body, terminator = split_terminator( line )

    statements = []
    offset = 0
    tag_count = 0
    opens_with_tag = false
    ends_with_tag = false

    while (match = TAG.match( body, offset ))
      literal = body[offset...match.begin( 0 )]
      opens_with_tag = true if match.begin( 0 ).zero? && offset.zero?
      tag_count += 1

      statements << append( literal ) unless literal.empty?

      kind, code = match.captures
      case kind
      when '=' then statements << "#{BUFFER} << (#{code}).to_s"
      when '#' then nil
      else          statements << code
      end

      offset = match.end( 0 )
      ends_with_tag = (offset == body.length)
    end

    remainder = body[offset..] || ''
    statements << append( remainder ) unless remainder.empty?

    guard_unclosed_tag( remainder, number )

    # ERB's "<>" trim: a line whose first tag opens it and whose last tag closes it
    # contributes no newline of its own. Text between the tags does not matter.
    trimmed = opens_with_tag && ends_with_tag && !terminator.empty?

    # A line carrying tags emits a bare newline rather than the terminator it
    # matched, so a template checked out with carriage returns renders the same as
    # one without. A line with no tags is passed through untouched, terminator and
    # all. ERB drew the distinction the same way, because only lines containing tags
    # went through its rewriting scanner.
    unless terminator.empty? || trimmed
      statements << append( tag_count.zero? ? terminator : "\n" )
    end

    return statements.join( '; ' )
  end


  def split_terminator(line)
    match = /\r?\n\z/.match( line )
    return [line, ''] if match.nil?
    return [line[0...match.begin( 0 )], match[0]]
  end


  def guard_unclosed_tag(remainder, number)
    return unless UNCLOSED_TAG.match?( remainder )

    raise CeedlingException.new(
      "Template line #{number} opens a tag that is never closed on the same line. " +
      "Ceedling templates allow one or more complete <% %> tags per line, and a tag may not span lines."
    )
  end


  def append(text)
    return "#{BUFFER} << #{text.dump}"
  end

end
