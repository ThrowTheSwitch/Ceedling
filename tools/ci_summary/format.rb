# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Markdown and number formatting the CI summary's renderer shares across its sections
module CiSummary
  module Format

    def details(summary, body)
      return "<details><summary>#{summary}</summary>\n\n#{body}\n</details>\n"
    end

    def job_link(job)
      return "[#{job['name']}](#{job['url']})"
    end

    def percent(lines)
      return lines['total'].zero? ? 0.0 : 100.0 * lines['covered'] / lines['total']
    end

    def count_delta(current, base)
      return '' if base.nil? or current == base

      return format( ' (%+d)', current - base )
    end

    def percent_delta(lines, base)
      return '—' if base.nil?

      delta = (percent( lines ) - percent( base )).round( 2 )
      return '±0.00' if delta.zero?

      return format( '%s%.2f', delta.positive? ? '▲' : '▼', delta.abs )
    end

  end
end
