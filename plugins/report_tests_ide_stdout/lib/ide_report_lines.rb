# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# The lines a report gives one failed or ignored test, each ending in a newline
class IdeReportLines

  def lines(file, item, _outcome)
    return legacy( file, item )
  end

  private

  # Every line of a message carries the test's file, line, and name, so each stays a link
  def legacy(file, item)
    prefix = "#{file}:#{item[:line]}:#{item[:test]}"
    return "#{prefix}\n" if item[:message].empty?

    return %(#{prefix}: "#{item[:message].each_line( chomp: true ).to_a.join( "\n#{prefix}: " )}"\n)
  end

end
