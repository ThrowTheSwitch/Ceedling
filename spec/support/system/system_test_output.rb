# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Wraps Ceedling command output to control how it appears in RSpec assertion failure messages.
# RSpec formats the "actual" value via #inspect. For large outputs this class returns a
# sentinel string so failures show only the expected pattern/substring, not thousands of lines.
# For small outputs (≤1000 characters or ≤12 lines) the real content is shown inline so
# short failures are immediately readable without consulting a log file.
# All RSpec string matchers (match, include) continue to work unchanged at every call site.
class SystemTestOutput
  def initialize(output)
    @output = output
  end

  def match(pattern) = @output.match(pattern)
  def include?(str)  = @output.include?(str)
  def to_s           = @output
  def to_str         = @output
  def inspect
    # Show actual output when it is small enough to read inline; suppress it otherwise.
    return @output.inspect if @output.length <= 1000 || @output.count("\n") <= 12
    '(<Ceedling build output> -- See log file)'
  end
end
