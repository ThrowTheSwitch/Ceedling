# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'report_tests_stdout_plugin'
require 'ide_report_lines'

# Parent class loads template from plugin assets directory and runs the reporting hooks
class ReportTestsIdeStdout < ReportTestsStdoutPlugin

  # `Plugin` setup()
  def setup
    super

    @report_lines = IdeReportLines.load( @ceedling[:setupinator].config_hash[:report_tests_ide_stdout] )
  end

  # The lines for one failed or ignored test. The plugin's template calls this through its
  # system object, so every context rendering results here gets the same lines.
  def problem(file, item, outcome)
    return @report_lines.lines( file, item, outcome )
  end

end
