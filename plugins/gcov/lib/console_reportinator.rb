# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/path_mirror'
require 'gcov_reportinator'

class ConsoleReportinator < GcovReportinator

  NAME = 'Gcov Console'

  def name; NAME; end

  attr_reader :artifacts_path  # nil — console output only, no filesystem artifacts

  def initialize(system_objects, config)
    super(config)

    @configurator         = system_objects[:configurator]
    @loginator            = system_objects[:loginator]
    @plugin_reportinator  = system_objects[:plugin_reportinator]
    @test_invoker         = system_objects[:test_invoker]
    @tool_executor        = system_objects[:tool_executor]
    @file_path_utils      = system_objects[:file_path_utils]
  end

  def generate_reports(opts, untested_sources: [])
    banner = @plugin_reportinator.generate_banner( "#{GCOV_ROOT_NAME.upcase}: CODE COVERAGE SUMMARY" )
    @loginator.log( "\n" + banner )

    # Iterate over each test run and its list of source files
    @test_invoker.each_test_with_sources do |test, sources|
      @loginator.log( @plugin_reportinator.generate_heading( test ) )

      # Collected before any report is logged, because a label can only be made
      # unambiguous once every file this test reports on is known. The path a file is
      # reported under is gcov's own where it could be parsed -- for a Partial that is the
      # original module, which #line directives remap it to -- and the queried source
      # otherwise.
      reports = remap_partial_sources( sources ).filter_map do |source|
        results = run_gcov_summary( test, source, opts )
        next if results.nil?

        gcov_source = extract_gcov_source_path( results, test, source )

        { source: source, results: results, gcov_source: gcov_source }
      end

      labels = disambiguated_labels( reports.map { |report| reported_path( report ) } )

      reports.each do |report|
        log_coverage_report(
          test, report[:source], report[:results], report[:gcov_source],
          label: labels[ reported_path( report ) ]
        )
      end
    end

    log_untested_sources_section( untested_sources ) unless untested_sources.empty?
  end

  ### Private ###

  private

  # The path a file's coverage is reported under.
  def reported_path(report)
    return report[:gcov_source].empty? ? report[:source] : report[:gcov_source]
  end

  # A display label per path, each the shortest trailing path that distinguishes it from
  # every other path sharing its basename.
  #
  # A basename alone is ambiguous the moment one test reports on two modules of the same
  # name, which says nothing about which module a coverage line belongs to. Case is
  # preserved, unlike path matching elsewhere: these are read by a person.
  def disambiguated_labels(paths)
    paths.uniq.group_by { |path| File.basename( path ) }.each_with_object({}) do |(_basename, group), labels|
      depth = label_depth( group )

      group.each { |path| labels[path] = display_segments( path ).last( depth ).join( '/' ) }
    end
  end

  # The fewest trailing segments that tell every path in `group` apart. Falls back to the
  # longest path's own depth when even whole paths repeat, which cannot be improved on.
  def label_depth(group)
    return 1 if group.length < 2

    deepest = group.map { |path| display_segments( path ).length }.max

    (1..deepest).each do |depth|
      tails = group.map { |path| display_segments( path ).last( depth ) }

      return depth if tails.uniq.length == group.length
    end

    return deepest
  end

  def display_segments(path)
    return path.split( %r{[\\/]} ).reject(&:empty?)
  end

  def log_untested_sources_section(untested_sources)
    @loginator.log( @plugin_reportinator.generate_heading("Untested Source Files") )

    untested_sources.sort_by { |f| File.basename(f) }.each do |source|
      @loginator.log( "#{File.basename(source)} | No tests executed: 0% coverage" )
    end
  end

  # Remap sources: if Partial files are present, remove the original source file they replace.
  # Coverage is then reported against the Partial implementation rather than the original module.
  #
  # A Partial replaces one module, identified by its path. Generated Partials and real
  # sources sit below different roots, so neither path is a suffix of the other and the
  # two can only be related by the namespace they share. Each Partial therefore claims
  # the source it shares the longest trailing path with. Matching on basename alone would
  # drop every same-named module, and one nobody Partialized would lose its coverage
  # report entirely.
  def remap_partial_sources(sources)
    partials = sources.select { |s| File.basename(s).match?(PATTERNS::PARTIAL_IMPL_FILENAME) }
    return sources if partials.empty?

    originals = sources.reject { |s| File.basename(s).match?(PATTERNS::PARTIAL_IMPL_FILENAME) }
    replaced  = []

    partials.each do |partial|
      query = partial_module_segments( partial )

      scored = originals.map { |source| [source, common_suffix_length( query, source_segments( source ) )] }
                        .reject { |_source, length| length.zero? }

      next if scored.empty?

      best = scored.map { |_source, length| length }.max

      replaced += scored.select { |_source, length| length == best }.map(&:first)
    end

    return sources - replaced
  end

  # The module a generated Partial replaces, as path segments. The reversal itself belongs
  # to the same place that builds these filenames, so prefix and suffix knowledge stays in
  # one place; the mirrored subdirectory survives as the module's own path.
  def partial_module_segments(filepath)
    _module = @file_path_utils.module_from_partial_filename( filepath )

    return [] if _module.nil?

    return PathMirror.path_segments( _module )
  end

  def source_segments(filepath)
    return PathMirror.path_segments( filepath.sub( /\.[^.\/\\]*\z/, '' ) )
  end

  # How many trailing segments two paths have in common. Zero means even the basenames
  # differ, so the two cannot name the same module.
  def common_suffix_length(left, right)
    length = 0
    length += 1 while length < left.length && length < right.length &&
                      left[-(length + 1)] == right[-(length + 1)]
    return length
  end

  def run_gcov_summary(test, source, opts)
    filename = File.basename(source)

    # A module-under-test's object (and its accompanying .gcno/.gcda) mirrors its source's own
    # subdirectory below whichever configured root it came from -- the same convention its actual
    # compile step already follows -- so the directory gcov is told to search must include that
    # mirrored subdirectory too, not just the flat <build>/gcov/out/<test name> root.
    # A generated Partial sits below its own test's Partials build root rather than a
    # configured source root, so the source roots mirror nothing for it. Its own root is
    # what carries the module's subdirectory.
    roots =
      if File.basename(source).match?(PATTERNS::PARTIAL_IMPL_FILENAME)
        [File.join( @configurator.project_test_partials_path, test )]
      else
        @configurator.paths_source + @configurator.paths_support
      end

    subdir  = PathMirror.relative_subdir( source, roots )
    obj_dir = subdir.empty? ? File.join(GCOV_BUILD_OUTPUT_PATH, test) : File.join(GCOV_BUILD_OUTPUT_PATH, test, subdir)

    # Run gcov to extract the coverage summary
    command = @tool_executor.build_command_line(
      TOOLS_GCOV_SUMMARY,
      # Conditionally include -g flag for MC/DC coverage
      (opts[:gcov_mcdc] ? ['-g'] : []),
      # Argument replacement
      filename, # .c source file compiled with coverage
      obj_dir # <build>/gcov/out/<test name>[/mirrored subdir] for coverage data files
    )

    # Do not raise an exception if `gcov` terminates with a non-zero exit code, just note it and move on.
    # Recent releases of `gcov` have become more strict and vocal about errors and exit codes.
    command[:options][:boom] = false

    # Run the gcov tool and collect the raw coverage report
    shell_results = @tool_executor.exec( command )
    results       = shell_results[:output].strip

    # Handle errors instead of raising a shell exception
    if @tool_executor.failed?( shell_results )
      @loginator.lazy( Verbosity::DEBUG, LogLabels::ERROR ) do
        "gcov error (#{shell_results[:status]&.exitstatus}) while processing #{filename}... #{results}"
      end
      @loginator.lazy( Verbosity::COMPLAIN ) do
        "gcov was unable to process coverage for #{filename}"
      end
      return nil
    end

    # A source component may have been compiled with coverage but none of its code actually called in a test.
    # In this case, versions of gcov may not produce an error, only blank results.
    if results.empty?
      @loginator.lazy( Verbosity::COMPLAIN, LogLabels::NOTICE ) do
        "No functions called or code paths exercised by test for #{filename}"
      end
      return nil
    end

    results
  end

  def extract_gcov_source_path(results, test, source)
    filename_no_ext = File.basename(source, '.*')

    # Prefer the File header that specifically matches the queried source filename.
    # gcov may list instrumented system headers (e.g. _stdio.h pulled in via FILE*)
    # before the actual source file, so the first File entry is not always correct.
    matches = results.match(/File\s+'([^']*#{Regexp.escape(filename_no_ext)}[^']*)'/)

    # Fall back to the first File header for Partial implementations: their #line
    # directives remap gcov output to the original module name, so the Partial
    # filename itself will not appear in any File header.
    matches ||= results.match(/File\s+'(.+)'/)

    if matches.nil? || matches.length != 2
      @loginator.lazy( Verbosity::DEBUG, LogLabels::ERROR ) do
        "Could not extract filepath via regex from gcov results for #{test}::#{File.basename(source)}"
      end
      return ''
    end

    # Expand to full path from likely partial path to ensure correct matches on source component within gcov results
    File.expand_path( matches[1] )
  end

  # test         — test name (string); used in log messages to identify which test produced the results
  # source       — filepath of the source file as known to Ceedling (may be a Partial implementation file)
  # results      — raw stdout from `gcov`; may contain coverage data for multiple files
  # gcov_source  — absolute path extracted from the `File '...'` line in gcov output; for Partial files
  #                this is the original module source (due to #line remapping), not the Partial filepath;
  #                empty string ('') when the gcov File header could not be parsed
  def log_coverage_report(test, source, results, gcov_source, label: nil)
    filename = File.basename(source)

    # If gcov results include intended source (comparing absolute paths), report coverage details summaries.
    # For Partial files, #line directives remap to the original source so path comparison never matches;
    # produce the report for any Partial that returned non-empty gcov output.
    if gcov_source == File.expand_path(source) || File.basename(source).match?(PATTERNS::PARTIAL_IMPL_FILENAME)
      # For Partials, use the original source name from gcov output (gcov_source) rather than the Partial filename.
      report_name = gcov_source.empty? ? filename : File.basename(gcov_source)

      # The basename still matches gcov's own File header; only the printed label carries
      # the disambiguating path.
      report_label = label || report_name

      lines = results.lines
      # Find the File header line matching the queried source filename
      start_idx = lines.index { |l| l.start_with?('File') && l.include?(report_name) }

      if start_idx
        # Extract statistics lines between this File header and the next File header (or end of results).
        # Reformat each line labeled with the source filename.
        remaining     = lines[(start_idx + 1)..] || []
        next_file_idx = remaining.index { |l| l.start_with?('File') }
        section       = next_file_idx ? remaining[0...next_file_idx] : remaining
        # Filter out gcov informational messages emitted while inspecting coverage binary files
        section       = section.reject { |line| line.include?( File.basename( source,'.*') ) }
        report        = section.map { |line| report_label + ' | ' + line }.join('')
        @loginator.log( report )
      else
        # A Partial whose remapped name still doesn't match any File header in gcov's
        # output -- without this, a Partial's unparseable coverage silently produces no
        # report and no log at all, unlike the equivalent non-Partial case just below.
        @loginator.lazy( Verbosity::COMPLAIN ) do
          "Found no coverage results for #{test}::#{File.basename(source)}"
        end
      end

    # Otherwise, found no coverage results
    else
      @loginator.lazy( Verbosity::COMPLAIN ) do
        "Found no coverage results for #{test}::#{File.basename(source)}"
      end
    end
  end

end
