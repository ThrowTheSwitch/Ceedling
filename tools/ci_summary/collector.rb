# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'json'
require 'fileutils'
require_relative 'results'
require_relative 'diff_coverage'
require_relative 'renderer'

# The CI summary's file handling, everything the pure modules beside it leave out.
#
# The CI workflow gathers every input as a file before this runs: each leg's results
# artifact in its own directory, the run's job list from the GitHub API, the base
# branch's baseline, and the pull request's zero-context diff. Reading only files keeps
# this free of network calls and shell commands. Any input may be missing, since a
# failed leg uploads partial results and a first run has no baseline; each absence
# renders as such rather than stopping the summary.
module CiSummary
  class Collector

    def initialize(results_dir:, jobs_path:, baseline_path:, diff_path:, merge_base:)
      @results_dir   = results_dir
      @jobs_path     = jobs_path
      @baseline_path = baseline_path
      @diff_path     = diff_path
      @merge_base    = merge_base
    end

    # Per-leg suite counts, keyed by leg name, from each leg's own artifact directory
    def legs
      @legs ||= artifacts.each_with_object( {} ) do |artifact, legs|
        leg = Results.leg_name( artifact )
        next if leg.nil?

        legs[leg] = Renderer::SUITES.each_with_object( {} ) do |suite, suites|
          rspec = read_json( File.join( @results_dir, artifact, "#{suite}.json" ) )
          suites[suite] = Results.counts( rspec ) unless rspec.nil?
        end
      end
    end

    # Coverage comes from the reference leg alone, the one leg that measures it
    def coverage
      return read_json( reference_path( 'coverage.json' ) )
    end

    def baseline
      base = read_json( @baseline_path )
      return base.nil? ? nil : base.merge( 'nearest' => base['sha'] != @merge_base )
    end

    def diff_coverage
      line_hits = read_json( reference_path( 'line_hits.json' ) )
      return nil if line_hits.nil? or !File.exist?( @diff_path.to_s )

      changed = DiffCoverage.changed_lines( File.read( @diff_path, encoding: 'UTF-8' ) )
      return DiffCoverage.measure( changed: changed, line_hits: line_hits )
    end

    def jobs
      return (read_json( @jobs_path ) || {}).fetch( 'jobs', [] ).map do |job|
        { 'name' => job['name'], 'conclusion' => job['conclusion'], 'url' => job['html_url'] }
      end
    end

    def write_summary(path, sha:)
      markdown = Renderer.render(
        sha: sha, jobs: jobs, legs: legs, coverage: coverage, diff_coverage: diff_coverage, baseline: baseline
      )
      File.write( path, markdown )
    end

    # This run's counts and coverage, for later pull requests to compare against
    def write_baseline(path, sha:, branch:)
      File.write( path, JSON.pretty_generate( 'sha' => sha, 'branch' => branch, 'legs' => legs, 'coverage' => coverage ) )
    end

    private

    def reference_path(name)
      artifact = artifacts.find { |entry| Results.leg_name( entry ) == Renderer::REFERENCE_LEG }
      return artifact.nil? ? nil : File.join( @results_dir, artifact, name )
    end

    # A run whose legs all failed before uploading leaves no results directory at all
    def artifacts
      return Dir.exist?( @results_dir ) ? Dir.children( @results_dir ).sort : []
    end

    def read_json(path)
      return nil if path.nil? or !File.exist?( path )

      return JSON.parse( File.read( path, encoding: 'UTF-8' ) )
    end

  end
end
