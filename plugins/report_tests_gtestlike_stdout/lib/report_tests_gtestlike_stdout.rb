# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'report_tests_stdout_plugin'
require 'gtestlike_report'

# Parent class loads template from plugin assets directory and runs the reporting hooks
class ReportTestsGtestlikeStdout < ReportTestsStdoutPlugin

  # Renders the GTest console report for a results hash. The plugin's template calls this
  # through its system object, so every context rendering results here gets the same report.
  def gtest_report(hash) = GtestlikeReport.new( hash[:results], context: hash[:context] ).render

end
