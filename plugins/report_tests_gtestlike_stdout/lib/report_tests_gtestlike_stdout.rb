# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/exceptions'
require 'report_tests_stdout_plugin'
require 'gtestlike_report'

# Parent class loads template from plugin assets directory and runs the reporting hooks
class ReportTestsGtestlikeStdout < ReportTestsStdoutPlugin

  # `Plugin` setup()
  def setup
    super

    # Whether Unity ignored tests report as GTest skipped tests or are left out. Only a
    # true boolean is accepted, since a quoted 'false' would otherwise read as true.
    @ignored_as_skipped = @ceedling[:configurator].report_tests_gtestlike_stdout_ignored_as_skipped

    return if [true, false].include?( @ignored_as_skipped )

    raise CeedlingException.new(
      ":report_tests_gtestlike_stdout ↳ :ignored_as_skipped must be TRUE or FALSE, not nil."
    )
  end

  # Renders the GTest console report for a results hash. The plugin's template calls this
  # through its system object, so every context rendering results here gets the same report.
  def gtest_report(hash)
    return GtestlikeReport.new( hash[:results], context: hash[:context], ignored_as_skipped: @ignored_as_skipped ).render
  end

end
