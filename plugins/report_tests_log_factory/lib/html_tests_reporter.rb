# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'tests_reporter'

class HtmlTestsReporter < TestsReporter

  def setup()
    super( default_filename: 'tests_report.html' )
  end

  def header(results:, stream:)
    stream.puts <<~HTML
      <!DOCTYPE html>
      <html lang="en">
      <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <meta http-equiv="X-UA-Compatible" content="ie=edge">
      <title>Ceedling Test Suite Report</title>
      <style>

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

      /* Ring chart cell: vertically centered, horizontally centered SVG. */
      table.summary td.chart-cell { vertical-align: middle; text-align: center; }

      /* Pass-percentage cell to the right of the ring chart. */
      table.summary td.pct-cell { vertical-align: middle; text-align: center; padding: 8px 20px; }

      /* "Passing" label above the large percentage number. */
      table.summary .pct-label { font-size: 0.9em; color: #777777; }

      /* Large, bold pass percentage. */
      table.summary .pct-value { font-size: 2.4em; font-weight: bold; color: #333333; line-height: 1.1; }

      /* Timestamp footer row: small, muted, centered across all columns. */
      table.summary td.datetime-row { font-size: 0.9em; color: #777777; text-align: center; padding: 3px 15px; }

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

      </style>
      </head>
      <body>
    HTML
  end

  def body(results:, stream:)
    write_summary(results[:counts], stream)
    write_failures(results[:failures], stream)
    write_ignores(results[:ignores], stream)
    write_successes(results[:successes], stream)
  end

  def footer(results:, stream:)
    stream.puts <<~HTML
      </body>
      </html>
    HTML
  end

  ### Private

  private

  # Returns a <td> HTML string for an assertion message.
  # Empty messages render an em-dash placeholder. Messages over 150 characters
  # are hidden behind a <details> disclosure widget to avoid overwhelming the
  # table layout.
  def message_cell(message)
    msg = message.to_s
    return '<td class="col-message">—</td>' if msg.empty?
    return "<td class=\"col-message\"><details><summary>Message hidden due to long length.</summary>#{msg}</details></td>" if msg.length > 150
    "<td class=\"col-message\">#{msg}</td>"
  end

  # Generates an inline SVG donut/ring chart showing the proportion of passed,
  # failed, and ignored tests. Returns an empty string when there are no tests.
  #
  # Each colored arc is a <circle> element whose visible portion is controlled
  # by stroke-dasharray (segment length vs. gap) and stroke-dashoffset (where
  # along the circumference the dash pattern starts). A positive dashoffset
  # shifts the start counterclockwise, so circumference/4 moves the first
  # segment's start from the default 3 o'clock position to 12 o'clock.
  # Each subsequent segment's offset is reduced by the arc lengths already drawn.
  # Segments with a zero count are omitted so no invisible zero-length arcs
  # create rendering artifacts between adjacent colored segments.
  def ring_chart_svg(passed, failed, ignored)
    total = passed + failed + ignored
    return '' if total == 0

    r             = 36
    stroke_width  = 20
    circumference = 2 * Math::PI * r

    # Order determines visual sequence going clockwise from 12 o'clock.
    segments = [
      { count: passed,  color: '#27ae60' },
      { count: failed,  color: '#c0392b' },
      { count: ignored, color: '#e67e22' },
    ].reject { |s| s[:count] == 0 }

    circles    = ''
    cumulative = 0.0

    segments.each do |seg|
      len    = (seg[:count].to_f / total) * circumference
      offset = circumference / 4.0 - cumulative
      circles += %(<circle cx="50" cy="50" r="#{r}" fill="none" ) +
                 %(stroke="#{seg[:color]}" stroke-width="#{stroke_width}" ) +
                 %(stroke-dasharray="#{len.round(3)} #{(circumference - len).round(3)}" ) +
                 %(stroke-dashoffset="#{offset.round(3)}"/>\n)
      cumulative += len
    end

    %(<svg viewBox="0 0 100 100" width="90" height="90" xmlns="http://www.w3.org/2000/svg">\n) +
    circles +
    %(</svg>)
  end

  # Emits the compact summary table: count rows (Total/Passed/Failed/Ignored),
  # a ring chart, a pass percentage, and a UTC timestamp.
  # The chart and percentage cells use rowspan="4" to span all four count rows,
  # and the timestamp row uses colspan="4" to span all columns.
  def write_summary(counts, stream)
    passed    = counts[:total] - counts[:ignored] - counts[:failed]
    chart     = ring_chart_svg( passed, counts[:failed], counts[:ignored] )
    pct       = counts[:total] > 0 ? ("%.1f%%" % (passed.to_f / counts[:total] * 100)) : "—"
    timestamp = Time.now.utc.strftime( "%B %d, %Y  %H:%M:%S UTC" )
    stream.puts <<~HTML
      <table class="summary">
        <thead><tr><th colspan="4">#{@report_name}</th></tr></thead>
        <tbody>
          <tr><td>Total</td><td>#{counts[:total]}</td><td rowspan="4" class="chart-cell">#{chart}</td><td rowspan="4" class="pct-cell"><div class="pct-label">Passing</div><div class="pct-value">#{pct}</div></td></tr>
          <tr><td>Passed</td><td>#{passed}</td></tr>
          <tr><td>Failed</td><td>#{counts[:failed]}</td></tr>
          <tr><td>Ignored</td><td>#{counts[:ignored]}</td></tr>
          <tr><td colspan="4" class="datetime-row">#{timestamp}</td></tr>
        </tbody>
      </table>
    HTML
  end

  # Emits the Failed Tests table. Each test file becomes a separate <tbody>
  # so that nth-child zebra striping resets per file. The row count increments
  # continuously across all file groups within this table. The empty col-count
  # <td> in filepath rows aligns the filepath with the test case name column.
  def write_failures(results, stream)
    return if results.empty?

    stream.puts <<~HTML
      <table class="failed">
        <thead>
          <tr><th class="col-count"></th><th>Failing test cases</th><th class="col-line">Line</th><th>Message</th></tr>
        </thead>
    HTML

    count = 0
    results.each do |result|
      filepath = result[:source][:file]
      stream.puts "  <tbody class=\"file-group\">"
      stream.puts "    <tr class=\"filepath-row\"><td class=\"col-count\"></td><td colspan=\"3\"><i>#{filepath}</i></td></tr>"
      result[:collection].each do |item|
        count += 1
        stream.puts "    <tr><td class=\"col-count\">#{count}</td><td class=\"col-shrink\"><code>#{item[:test]}</code></td><td class=\"col-line\">#{item[:line]}</td>#{message_cell(item[:message])}</tr>"
      end
      stream.puts "  </tbody>"
    end

    stream.puts "</table>"
  end

  # Emits the Ignored Tests table. Structure mirrors write_failures except
  # there is no Line column (ignored test items do not carry a line number).
  def write_ignores(results, stream)
    return if results.empty?

    stream.puts <<~HTML
      <table class="ignored">
        <thead>
          <tr><th class="col-count"></th><th>Ignored test cases</th><th>Message</th></tr>
        </thead>
    HTML

    count = 0
    results.each do |result|
      filepath = result[:source][:file]
      stream.puts "  <tbody class=\"file-group\">"
      stream.puts "    <tr class=\"filepath-row\"><td class=\"col-count\"></td><td colspan=\"2\"><i>#{filepath}</i></td></tr>"
      result[:collection].each do |item|
        count += 1
        stream.puts "    <tr><td class=\"col-count\">#{count}</td><td class=\"col-shrink\"><code>#{item[:test]}</code></td>#{message_cell(item[:message])}</tr>"
      end
      stream.puts "  </tbody>"
    end

    stream.puts "</table>"
  end

  # Emits the Passed Tests table. Only test case names are shown; no line
  # number or message columns (passing results carry neither). The test case
  # column is full-width because it is the only data column.
  def write_successes(results, stream)
    return if results.empty?

    stream.puts <<~HTML
      <table class="success">
        <thead>
          <tr><th class="col-count"></th><th>Passing test cases</th></tr>
        </thead>
    HTML

    count = 0
    results.each do |result|
      filepath = result[:source][:file]
      stream.puts "  <tbody class=\"file-group\">"
      stream.puts "    <tr class=\"filepath-row\"><td class=\"col-count\"></td><td><i>#{filepath}</i></td></tr>"
      result[:collection].each do |item|
        count += 1
        stream.puts "    <tr><td class=\"col-count\">#{count}</td><td><code>#{item[:test]}</code></td></tr>"
      end
      stream.puts "  </tbody>"
    end

    stream.puts "</table>"
  end

end
