# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'gcov_reportinator'

class ConsoleReportinator < GcovReportinator

  NAME = 'Gcov Console'

  def name; NAME; end

  attr_reader :artifacts_path  # nil — console output only, no filesystem artifacts

  def initialize(system_objects)
    @loginator           = system_objects[:loginator]
    @plugin_reportinator = system_objects[:plugin_reportinator]
    @test_invoker        = system_objects[:test_invoker]
    @tool_executor       = system_objects[:tool_executor]
  end

  def generate_reports(opts, untested_sources: [])
    banner = @plugin_reportinator.generate_banner( "#{GCOV_ROOT_NAME.upcase}: CODE COVERAGE SUMMARY" )
    @loginator.log( "\n" + banner )

    # Iterate over each test run and its list of source files
    @test_invoker.each_test_with_sources do |test, sources|
      @loginator.log( @plugin_reportinator.generate_heading( test ) )

      _sources = remap_partial_sources( sources )
      _sources.each do |source|
        results = run_gcov_summary( test, source, opts )
        next if results.nil?
        gcov_source = extract_gcov_source_path( results, test, source )
        log_coverage_report( test, source, results, gcov_source )
      end
    end

    log_untested_sources_section( untested_sources ) unless untested_sources.empty?
  end

  ### Private ###

  private

  def log_untested_sources_section(untested_sources)
    @loginator.log( @plugin_reportinator.generate_heading("Untested Source Files") )

    untested_sources.sort_by { |f| File.basename(f) }.each do |source|
      @loginator.log( "#{File.basename(source)} | No tests executed — 0% coverage" )
    end
  end

  def remap_partial_sources(sources)
    # Remap sources: if Partial files are present, remove the original source file they replace.
    # Coverage is then reported against the Partial implementation rather than the original module.
    partials = sources.select { |s| File.basename(s).match?(PATTERNS::PARTIAL_IMPL_FILENAME) }
    return sources if partials.empty?

    # Extract module names covered by Partials (strip prefix and _impl suffix)
    partialized = partials.map { |p|
      File.basename(p, '.*').delete_prefix(PARTIAL_FILENAME_PREFIX).delete_suffix('_impl')
    }
    # Drop any original source file whose module is now covered by a Partial
    sources.reject { |s| partialized.include?( File.basename(s, '.*') ) }
  end

  def run_gcov_summary(test, source, opts)
    filename = File.basename(source)

    # Run gcov to extract the coverage summary
    command = @tool_executor.build_command_line(
      TOOLS_GCOV_SUMMARY,
      # Conditionally include -g flag for MC/DC coverage
      (opts[:gcov_mcdc] ? ['-g'] : []),
      # Argument replacement
      filename, # .c source file compiled with coverage
      File.join(GCOV_BUILD_OUTPUT_PATH, test) # <build>/gcov/out/<test name> for coverage data files
    )

    # Do not raise an exception if `gcov` terminates with a non-zero exit code, just note it and move on.
    # Recent releases of `gcov` have become more strict and vocal about errors and exit codes.
    command[:options][:boom] = false

    # Run the gcov tool and collect the raw coverage report
    shell_results = @tool_executor.exec( command )
    results       = shell_results[:output].strip

    # Handle errors instead of raising a shell exception
    if shell_results[:exit_code] != 0
      @loginator.lazy( Verbosity::DEBUG, LogLabels::ERROR ) do
        "gcov error (#{shell_results[:exit_code]}) while processing #{filename}... #{results}"
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
  def log_coverage_report(test, source, results, gcov_source)
    filename = File.basename(source)

    # If gcov results include intended source (comparing absolute paths), report coverage details summaries.
    # For Partial files, #line directives remap to the original source so path comparison never matches;
    # produce the report for any Partial that returned non-empty gcov output.
    if gcov_source == File.expand_path(source) || File.basename(source).match?(PATTERNS::PARTIAL_IMPL_FILENAME)
      # For Partials, use the original source name from gcov output (gcov_source) rather than the Partial filename.
      report_name = gcov_source.empty? ? filename : File.basename(gcov_source)

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
        report        = section.map { |line| report_name + ' | ' + line }.join('')
        @loginator.log( report )
      end

    # Otherwise, found no coverage results
    else
      @loginator.lazy( Verbosity::COMPLAIN ) do
        "Found no coverage results for #{test}::#{File.basename(source)}"
      end
    end
  end

end
