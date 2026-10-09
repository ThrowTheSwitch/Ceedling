# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'tests_reporter'
require 'ceedling/reportinator'

# The report's stylesheet, kept apart from the reporter so the class holds only behavior
HTML_TESTS_REPORT_STYLE = <<~CSS.freeze

  /* Global baseline: sans-serif font, border-box sizing, and a slight
     letter-spacing throughout for improved legibility. */
  * { font-family: sans-serif; box-sizing: border-box; letter-spacing: 0.03em; }

  /* Base table layout shared by all four tables (summary, failed,
     ignored, success). border-radius + overflow:hidden clips the corners
     of the colored header row. */
  table {
    border-collapse: collapse;
    width: 99%;
    margin: 0 0 25px 7px;
    font-size: 0.9em;
    min-width: 400px;
    border-radius: 5px 5px 0 0;
    overflow: hidden;
    box-shadow: 0 0 22px rgba(0, 0, 0, 0.2);
  }

  /* --- Summary table ------------------------------------------------- */

  /* Override the full-width default; summary is a compact info block. */
  table.summary { width: auto; min-width: 200px; }

  /* Right-align and bold the numeric count values (second column). */
  table.summary td:nth-child(2) { text-align: right; font-weight: bold; }

  /* Tighter vertical padding for summary body rows than the global default. */
  table.summary tbody td { padding: 4px 15px; }

  /* Extra top padding on the first body row to separate it from the header bar. */
  table.summary tbody tr:first-child td { padding-top: 10px; }

  /* Ring chart cell: vertically centered, horizontally centered SVG. */
  table.summary td.chart-cell { vertical-align: middle; text-align: center; }

  /* Pass-percentage cell to the right of the ring chart. */
  table.summary td.pct-cell { vertical-align: middle; text-align: center; padding: 8px 20px; }

  /* "Passing" label above the large percentage number. */
  table.summary .pct-label { font-size: 1.0em; color: #777777; }

  /* Large, bold pass percentage. */
  table.summary .pct-value { font-size: 2.4em; font-weight: bold; color: #333333; line-height: 1.1; }

  /* Timestamp footer row: small, muted, centered across all columns. */
  table.summary td.datetime-row { font-size: 0.9em; color: #777777; text-align: center; padding: 8px 15px; }

  /* --- Table title rows ---------------------------------------------- */

  /* All <thead> rows: white text, left-aligned, bold. Individual table
     classes below apply traffic-light background colors. */
  thead tr { color: #ffffff; text-align: left; font-weight: bold; }

  /* Traffic-light title colors. :first-child targets only the title row
     so that any secondary header rows are not colored. */
  table.summary thead tr:first-child { background-color: #555555; }
  table.failed  thead tr:first-child { background-color: #c0392b; }
  table.success thead tr:first-child { background-color: #27ae60; }
  table.ignored thead tr:first-child { background-color: #e67e22; }

  /* Bottom accent line matching each table's header color. border-bottom is
     defeated by border-collapse:collapse, so box-shadow is used instead. */
  table.summary { box-shadow: 0 0 22px rgba(0,0,0,0.2), 0 2px 0 0 #555555; }
  table.failed  { box-shadow: 0 0 22px rgba(0,0,0,0.2), 0 2px 0 0 #c0392b; }
  table.success { box-shadow: 0 0 22px rgba(0,0,0,0.2), 0 2px 0 0 #27ae60; }
  table.ignored { box-shadow: 0 0 22px rgba(0,0,0,0.2), 0 2px 0 0 #e67e22; }

  /* --- Cell padding defaults ----------------------------------------- */

  /* Default padding for all th and td cells. */
  table th, td { padding: 12px 15px; }

  /* The count <th> in each category table title row is intentionally empty.
     Zeroing its padding collapses it so the title text starts flush with
     the table's left edge rather than indented by the count column. */
  thead tr th.col-count { padding: 0; }

  /* --- File-group tbody rows ----------------------------------------- */

  /* Zebra-stripe alternating rows within each per-file <tbody> group.
     nth-child resets per <tbody>, so striping restarts for each file. */
  tbody.file-group tr:nth-child(odd)  { background-color: #ffffff; }
  tbody.file-group tr:nth-child(even) { background-color: #f3f3f3; }

  /* Filepath header row for each file group: medium gray, darker than the
     zebra stripe, visually separating one file's tests from the next. */
  table.failed  tbody.file-group tr.filepath-row { background-color: #d8d8d8; color: #333333; }
  table.success tbody.file-group tr.filepath-row { background-color: #d8d8d8; color: #333333; }
  table.ignored tbody.file-group tr.filepath-row { background-color: #d8d8d8; color: #333333; }

  /* Extra tracking on the italic filepath text. Targeting <i> directly
     is required because the global * rule sets letter-spacing on every
     element, which would otherwise override an inherited value from <td>. */
  tbody.file-group tr.filepath-row i { letter-spacing: 0.07em; }

  /* Left-align all data cells (overrides browser default center for <td>
     in some contexts). */
  tbody.file-group td { text-align: left; }

  /* --- Column utility classes ---------------------------------------- */

  /* Shrink a column to fit its content width with no line-wrapping.
     Used for the test case name column so the message column gets the
     remaining table width. */
  .col-shrink { width: 1%; white-space: nowrap; }

  /* Fixed-width count column sized for up to 4 digits. A more specific
     descendant rule below enforces right-alignment for data cells only,
     since tbody.file-group td overrides class-level text-align. */
  .col-count  { width: 4em; white-space: nowrap; }
  tbody.file-group td.col-count { text-align: right; }

  /* Line-number column: shrinks to content, right-aligned. Same
     specificity pattern as col-count to override the global td rule. */
  .col-line   { width: 1%; white-space: nowrap; }
  tbody.file-group td.col-line { text-align: right; }
  thead tr th.col-line { text-align: right; }

  /* Message column: allow long assertion strings to break anywhere so
     they do not widen the table. */
  .col-message { word-break: break-all; }

  /* Monospace font for test case identifiers. overflow-wrap handles
     identifiers that are longer than the available column width. */
  code { font-family: monospace; font-size: 1.2em; overflow-wrap: break-word; }

  details summary { cursor: pointer; }
CSS

# The report document up to its body, filled by name with its title and stylesheet
HTML_TESTS_REPORT_HEAD = <<~HTML.freeze
  <!DOCTYPE html>
  <html lang="en">
  <head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="X-UA-Compatible" content="ie=edge">
  <title>%{title}</title>
  <style>
  %{style}
  </style>
  </head>
  <body>
HTML

# The report's summary table, filled by name from the run's counts and timing. The chart
# and percentage cells span all four count rows, and the timing row spans every column.
HTML_TESTS_REPORT_SUMMARY = <<~HTML.freeze
  <table class="summary">
    <thead><tr><th colspan="4">%{name}</th></tr></thead>
    <tbody>
      <tr>
        <td>Total</td><td>%{total}</td>
        <td rowspan="4" class="chart-cell">%{chart}</td>
        <td rowspan="4" class="pct-cell">
          <div class="pct-label">Passing</div>
          <div class="pct-value">%{percentage}</div>
        </td>
      </tr>
      <tr><td>Passed</td><td>%{passed}</td></tr>
      <tr><td>Failed</td><td>%{failed}</td></tr>
      <tr><td>Ignored</td><td>%{ignored}</td></tr>
      <tr><td colspan="4" class="datetime-row">%{timing}</td></tr>
    </tbody>
  </table>
HTML

# An inline SVG ring chart of the proportions of passed, failed, and ignored tests.
#
# Each colored arc is a <circle> whose visible portion is set by stroke-dasharray (segment
# length, then gap) and stroke-dashoffset (where along the circumference the dash starts).
# A positive offset shifts the start counterclockwise, so a quarter circumference moves
# the first segment from 3 o'clock to 12 o'clock. Each later segment's offset is reduced
# by the arcs already drawn.
module HtmlRingChart

  RADIUS        = 36
  CIRCUMFERENCE = 2 * Math::PI * RADIUS

  # Segment colors in clockwise order from 12 o'clock
  COLORS = [ '#27ae60', '#c0392b', '#e67e22' ].freeze

  # Empty when there are no tests. A zero count draws no segment, since an invisible
  # zero-length arc leaves rendering artifacts between its neighbors.
  def self.svg(passed, failed, ignored)
    total = passed + failed + ignored
    return '' if total == 0

    drawn   = 0.0
    circles = [ passed, failed, ignored ].zip( COLORS ).reject { |count, _| count == 0 }.map do |count, color|
      length = (count.to_f / total) * CIRCUMFERENCE
      circle = self.circle( length, (CIRCUMFERENCE / 4.0) - drawn, color )
      drawn += length
      circle
    end

    return %(<svg viewBox="0 0 100 100" width="90" height="90" xmlns="http://www.w3.org/2000/svg">\n#{circles.join}</svg>)
  end

  def self.circle(length, offset, color)
    return %(<circle cx="50" cy="50" r="#{RADIUS}" fill="none" stroke="#{color}" stroke-width="20" ) +
           %(stroke-dasharray="#{length.round(3)} #{(CIRCUMFERENCE - length).round(3)}" ) +
           %(stroke-dashoffset="#{offset.round(3)}"/>\n)
  end

end

class HtmlTestsReporter < TestsReporter

  def setup()
    super( default_filename: 'tests_report.html' )
  end

  def header(stream:, name:, **)
    stream.puts( format( HTML_TESTS_REPORT_HEAD, title: title( name ), style: HTML_TESTS_REPORT_STYLE ) )
  end

  def body(stream:, name:, results:, duration_s:)
    write_summary( name, results[:counts], duration_s, stream )
    TABLES.each { |category, table| write_table( results[category], table, stream ) }
  end

  def footer(stream:, **)
    stream.puts <<~HTML
      </body>
      </html>
    HTML
  end

  # Each results table, in report order: its CSS class, its title, and whether its rows
  # carry a line number and a message. Passing results carry neither.
  TABLES = {
    failures:  { css: 'failed',  title: 'Failing test cases', line: true,  message: true  },
    ignores:   { css: 'ignored', title: 'Ignored test cases', line: false, message: true  },
    successes: { css: 'success', title: 'Passing test cases', line: false, message: false }
  }.freeze

  ### Private

  private

  # The default report name gets a plain title. A project's own name follows the suite.
  def title(name)
    return 'Ceedling Test Suite Report' if name == DEFAULT_REPORT_NAME
    return "Ceedling Test Suite: #{html_escape( name )}"
  end

  def write_summary(name, counts, duration_s, stream)
    stream.puts( format( HTML_TESTS_REPORT_SUMMARY, **counts,
      name:       html_escape( name ),
      chart:      HtmlRingChart.svg( counts[:passed], counts[:failed], counts[:ignored] ),
      percentage: pass_percentage( counts ),
      timing:     timing( duration_s )
    ) )
  end

  def pass_percentage(counts)
    return '—' if counts[:total] == 0
    return '%.1f%%' % (counts[:passed].to_f / counts[:total] * 100)
  end

  # When the report was written, after the build's duration when that is known
  def timing(duration_s)
    timestamp = Time.now.utc.strftime( '%B %d, %Y %H:%M:%S UTC' )
    return timestamp if duration_s.nil?
    return Reportinator.generate_duration_string( duration_s, precision: 0, abbreviate: true ) + ' ⏱️ ' + timestamp
  end

  # Emits one results table, or nothing for an empty category. Each test file is its own
  # <tbody>, so zebra striping restarts per file, while the row count runs on across the
  # whole table.
  def write_table(results, table, stream)
    return if results.empty?

    stream.puts( %(<table class="#{table[:css]}">) )
    stream.puts( "  <thead>\n    <tr>#{header_cells( table )}</tr>\n  </thead>" )

    counter = (1..).each
    results.each { |result| write_file_group( result, table, counter, stream ) }

    stream.puts( '</table>' )
  end

  def write_file_group(result, table, counter, stream)
    stream.puts( '  <tbody class="file-group">' )
    stream.puts( "    #{filepath_row( result[:source][:file], table )}" )
    result[:collection].each { |item| stream.puts( "    <tr>#{row_cells( item, counter.next, table )}</tr>" ) }
    stream.puts( '  </tbody>' )
  end

  # A filepath row spans every column after the count
  def filepath_row(filepath, table)
    columns = 1 + [ table[:line], table[:message] ].count( true )
    span    = columns > 1 ? %( colspan="#{columns}") : ''
    return %(<tr class="filepath-row"><td class="col-count"></td><td#{span}><i>#{html_escape( filepath )}</i></td></tr>)
  end

  def header_cells(table)
    cells = %(<th class="col-count"></th><th>#{table[:title]}</th>)
    cells += %(<th class="col-line">Line</th>) if table[:line]
    cells += %(<th>Message</th>) if table[:message]
    return cells
  end

  # A name shrinks to fit only beside a message column, which takes the remaining width
  def row_cells(item, count, table)
    name  = table[:message] ? %(<td class="col-shrink">) : '<td>'
    cells = %(<td class="col-count">#{count}</td>#{name}<code>#{html_escape( item[:test] )}</code></td>)
    cells += %(<td class="col-line">#{item[:line]}</td>) if table[:line]
    cells += message_cell( item[:message] ) if table[:message]
    return cells
  end

  # Returns a <td> HTML string for an assertion message.
  # Empty messages render an em-dash placeholder. Messages over 150 characters
  # are hidden behind a <details> disclosure widget to avoid overwhelming the
  # table layout.
  def message_cell(message)
    msg = message.to_s
    return '<td class="col-message">—</td>' if msg.empty?
    # Truncation threshold is checked against the raw message length, before
    # escaping -- escaping can only lengthen the string, never shorten it,
    # so checking pre-escaping keeps the threshold meaning "this many actual
    # characters of message text" rather than "this many characters once
    # some fraction of them have been expanded into HTML entities."
    truncate = msg.length > 150
    msg = html_escape(msg)
    return "<td class=\"col-message\"><details><summary>Message hidden due to long length.</summary>#{msg}</details></td>" if truncate
    "<td class=\"col-message\">#{msg}</td>"
  end

end
