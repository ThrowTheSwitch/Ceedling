# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# The name a merged coverage report gives the runs it combines.
#
# SimpleCov names a merged result with every run's own name, comma-joined. The system
# suite records one run per child process, hundreds in all, and the HTML report prints
# that name in the footer of every source file view, where it buries the source. This
# names each suite instead, with a count of its runs where it has many.
module CoverageReportLabel

  # Suites measured in one run per child process, whose run count varies
  COUNTED = %w[system].freeze

  # `runs` maps each suite, in order, to the number of resultsets merged from it
  def self.for(runs)
    return runs.reject { |_suite, count| count.zero? }.map do |suite, count|
      COUNTED.include?( suite ) ? "#{suite} (#{count} #{count == 1 ? 'run' : 'runs'})" : suite
    end.join( ', ' )
  end

end
