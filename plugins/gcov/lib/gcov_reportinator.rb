# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Abstract base class that formalises the gcov reportinator interface.
#
# Subclasses must:
#   - Define a NAME string constant and implement name() to return it.
#   - Set @artifacts_path in initialize (nil for console-only reportinators)
#     and expose it via attr_reader.
#   - Implement generate_reports(opts) and return a summary string or nil.
#
class GcovReportinator

  def name
    raise NotImplementedError.new("#{self.class} must implement name()")
  end

  def artifacts_path
    raise NotImplementedError.new("#{self.class} must implement artifacts_path()")
  end

  def generate_reports(opts)
    raise NotImplementedError.new("#{self.class} must implement generate_reports()")
  end

end
