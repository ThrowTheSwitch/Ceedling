# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# The CI summary's markdown, the body of a pull request's sticky comment and of the
# CI run's own job summary.
#
# A reviewer reads it top down. The header states the verdict; warnings and failing
# jobs follow, then the reference leg's test counts and the coverage, each compared
# with the base branch. Every leg and job sits in collapsed detail at the bottom.
#
# Pending counts differ between legs by design, since some specs skip on hosts that
# lack a tool or a platform feature. Each leg is therefore compared only with the same
# leg on the baseline, where a rise means a leg silently stopped running specs.
require_relative 'format'

module CiSummary
  module Renderer

    REFERENCE_LEG   = 'Linux 3.3'
    SUITES          = %w[units integration system].freeze
    COVERAGE_SUITES = %w[units integration system combined].freeze
    FAILED          = %w[failure cancelled timed_out].freeze
    UNCOVERED_LIMIT = 20

    extend Format

    module_function

    def render(sha:, jobs:, legs:, coverage:, diff_coverage:, baseline:)
      run = finished( jobs )

      sections = [
        header( sha, run, baseline ), warnings( legs, baseline ), failing_jobs( run ),
        tests_table( legs[REFERENCE_LEG], baseline&.dig( 'legs', REFERENCE_LEG ) ),
        coverage_table( coverage, baseline&.fetch( 'coverage', nil ) ),
        diff_coverage_line( diff_coverage ), legs_details( legs ), jobs_details( run )
      ]
      return sections.compact.join( "\n" )
    end

    # A skipped job ran nothing, and a job without a conclusion is still running
    def finished(jobs)
      return jobs.reject { |job| job['conclusion'].nil? or job['conclusion'] == 'skipped' }
    end

    ### Sections ###

    def header(sha, run, baseline)
      failed  = run.count { |job| FAILED.include?( job['conclusion'] ) }
      verdict = failed.zero? ? "✅ #{run.size}/#{run.size} jobs passed" : "❌ #{failed} of #{run.size} jobs failed"

      return "### CI summary · #{sha[0, 7]} · #{verdict} · #{baseline_label( baseline )}\n"
    end

    def baseline_label(baseline)
      return 'no baseline' if baseline.nil?

      name = "baseline #{baseline['sha'][0, 7]} (#{baseline['branch']})"
      return baseline['nearest'] ? "nearest #{name}" : name
    end

    def warnings(legs, baseline)
      return nil if baseline.nil?

      lines = baseline['legs'].flat_map { |leg, suites| leg_warnings( leg, suites, legs[leg] ) }
      return lines.empty? ? nil : lines.map { |line| "⚠️ #{line}\n" }.join
    end

    def leg_warnings(leg, base_suites, suites)
      return ["#{leg}: no results"] if suites.nil?

      return base_suites.filter_map do |suite, base|
        current = suites[suite]
        next "#{leg} #{suite}: no results" if current.nil?
        next "#{leg} #{suite}: pending #{base['pending']} → #{current['pending']}" if current['pending'] > base['pending']
      end
    end

    def failing_jobs(run)
      failed = run.select { |job| FAILED.include?( job['conclusion'] ) }
      return failed.empty? ? nil : failed.map { |job| "- ❌ #{job_link( job )}\n" }.join
    end

    def tests_table(suites, base_suites)
      return "**Tests (#{REFERENCE_LEG}):** no results\n" if suites.nil?

      rows = SUITES.filter_map do |suite|
        next if (counts = suites[suite]).nil?

        examples = "#{counts['examples']}#{count_delta( counts['examples'], base_suites&.dig( suite, 'examples' ) )}"
        "| #{suite} | #{examples} | #{counts['failures']} | #{counts['pending']} |\n"
      end

      return "| Tests (#{REFERENCE_LEG}) | Examples | Failures | Pending |\n|---|---:|---:|---:|\n#{rows.join}"
    end

    def coverage_table(coverage, base_coverage)
      return "**Coverage:** unavailable\n" if coverage.nil? or coverage.empty?

      rows = COVERAGE_SUITES.filter_map do |suite|
        next if (lines = coverage[suite]).nil?

        base = base_coverage&.fetch( suite, nil )
        "| #{suite} | #{format( '%.2f', percent( lines ) )}% | #{percent_delta( lines, base )} |\n"
      end

      return "| Coverage | Lines | Δ |\n|---|---:|---:|\n#{rows.join}"
    end

    def diff_coverage_line(diff)
      return "**Diff coverage:** unavailable\n" if diff.nil?
      return "**Diff coverage:** no changed lines tracked\n" if diff[:relevant].zero?

      line = "**Diff coverage:** #{format( '%.2f', 100.0 * diff[:covered] / diff[:relevant] )}% " \
             "(#{diff[:covered]}/#{diff[:relevant]} changed lines)."
      uncovered = diff[:uncovered].flat_map { |path, ranges| ranges.map { |range| "`#{path}:#{range}`" } }

      return uncovered.empty? ? "#{line}\n" : "#{line} Uncovered: #{capped_list( uncovered )}\n"
    end

    # A pull request comment has a size limit, so a long list stops at a count
    def capped_list(items)
      shown = items.first( UNCOVERED_LIMIT ).join( ', ' )
      return items.size > UNCOVERED_LIMIT ? "#{shown}, and #{items.size - UNCOVERED_LIMIT} more" : shown
    end

    def legs_details(legs)
      rows = legs.sort.map do |leg, suites|
        cells = SUITES.map { |suite| (counts = suites[suite]) ? counts.values_at( 'examples', 'failures', 'pending' ).join( ' / ' ) : '—' }
        "| #{leg} | #{cells.join( ' | ' )} |\n"
      end

      return details( 'All legs (examples / failures / pending)',
                      "| Leg | #{SUITES.join( ' | ' )} |\n|---|#{'---:|' * SUITES.size}\n#{rows.join}" )
    end

    def jobs_details(run)
      lines = run.map { |job| "- #{FAILED.include?( job['conclusion'] ) ? '❌' : '✅'} #{job_link( job )}\n" }
      return details( 'Jobs', lines.join )
    end

  end
end
