# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Diff coverage, the share of a pull request's changed Ruby lines that tests execute.
#
# The changed lines come from `git diff --unified=0`, whose hunk headers alone name
# every added line. The hits come from the combined SimpleCov result, one entry per
# source line, where nil marks a line Ruby never counts (a comment, a blank, an `end`).
# Only the Ruby Ceedling ships is measured, the same scope its coverage tracks.
module CiSummary
  module DiffCoverage

    SHIPPED = %w[lib/ bin/ plugins/].freeze

    HUNK = /^@@ -\S+ \+(\d+)(?:,(\d+))? @@/

    module_function

    # Added line numbers per file, keyed by the path each `+++` line names
    def changed_lines(diff)
      changed, path = {}, nil

      diff.each_line do |line|
        next path = diff_target( line ) if line.start_with?( '+++ ' )

        lines = hunk_lines( line )
        (changed[path] ||= []).concat( lines ) unless path.nil? or lines.empty?
      end

      return changed
    end

    # Covered and relevant changed lines, plus each file's uncovered lines as ranges
    def measure(changed:, line_hits:)
      files = changed.filter_map { |path, lines| file_coverage( path, lines, line_hits[path] ) }

      return {
        covered:   files.sum { |file| file[:covered] },
        relevant:  files.sum { |file| file[:relevant] },
        uncovered: files.reject { |file| file[:missed].empty? }.to_h { |file| [file[:path], ranges( file[:missed] )] }
      }
    end

    # Sorted line numbers collapsed into `first-last` runs.
    def ranges(lines)
      return lines.sort.slice_when { |a, b| b != a + 1 }.map do |run|
        run.size == 1 ? run.first.to_s : "#{run.first}-#{run.last}"
      end
    end

    # The file a diff's `+++` line names, or nil for a deletion
    def diff_target(line)
      target = line.chomp.delete_prefix( '+++ ' )
      return target == '/dev/null' ? nil : target.delete_prefix( 'b/' )
    end

    # The added lines a hunk header names. Its `+start,count` gives them, and a missing
    # count means one line.
    def hunk_lines(line)
      hunk = line.match( HUNK )
      return [] if hunk.nil?

      start = hunk[1].to_i
      return (start...(start + (hunk[2] || 1).to_i)).to_a
    end

    # One file's changed-line coverage. A file coverage never tracked is skipped rather
    # than counted as uncovered.
    def file_coverage(path, lines, hits)
      return nil if hits.nil? or !shipped_ruby?( path )

      tracked = lines.reject { |line| hits[line - 1].nil? }
      missed  = tracked.select { |line| hits[line - 1].zero? }
      return { path: path, relevant: tracked.size, covered: tracked.size - missed.size, missed: missed }
    end

    def shipped_ruby?(path)
      return path.end_with?( '.rb' ) && path.start_with?( *SHIPPED )
    end

  end
end
