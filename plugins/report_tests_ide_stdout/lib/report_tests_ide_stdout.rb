# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'report_tests_stdout_plugin'

class ReportTestsIdeStdout < ReportTestsStdoutPlugin

  private

  # Use the Ceedling default template instead of a plugin-local template file
  def load_template
    return DEFAULT_TESTS_RESULTS_REPORT_TEMPLATE
  end

end
