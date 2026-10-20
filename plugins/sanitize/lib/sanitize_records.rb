# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'sanitize_constants'
require 'sanitize_reports'

# The findings a run's instrumented builds turn up, each with its build context and test.
# Tests run in parallel, so recording is synchronized. A crashed test's backtrace reruns
# reproduce the main run's finding and can reach findings it never did, so a finding
# recorded again is counted once.
class SanitizeRecords

  def initialize(file_wrapper:, loginator:, reports:)
    @file_wrapper = file_wrapper
    @loginator    = loginator
    @reports      = reports
    @records      = []
    @logged_tests = []
    @written      = []
    @mutex        = Mutex.new
  end

  def empty? = @records.empty?

  def self.log_filepath(context, test)
    return File.join( SANITIZE_ARTIFACTS_PATH, context.to_s, "#{test}.log" )
  end

  # A crash's explanation, in the keys of the explain_test_crash hook
  def self.explanation(context, test, finding)
    return {
      explanation_heading: 'was stopped by a sanitizer finding',
      explanation:         SanitizeReports.headline( finding ),
      explanation_details: ["Boom log: #{log_filepath( context, test )}"]
    }
  end

  # Adds a test's new findings to its own log and logs each, except one a crash's notice names
  def record(context, test, findings, explained: nil)
    added = @mutex.synchronize { add_new( context, test, findings ) }
    return if added.empty?

    log = SanitizeRecords.log_filepath( context, test )
    write_log( log, added )
    added.each do |finding|
      next if explained && key( finding ) == key( explained )

      @loginator.log( "#{test}: #{SanitizeReports.headline( finding )} ➡️ see #{log}", Verbosity::ERRORS, LogLabels::ERROR )
    end
  end

  def write_reports(context)
    records   = @records.select { |record| record[:context] == context }
    directory = File.join( SANITIZE_ARTIFACTS_PATH, context.to_s )

    @reports.each do |report|
      next if records.empty? && !report.write_empty?

      filepath = File.join( directory, "#{SANITIZE_ROOT_NAME}.#{report.extension}" )
      @file_wrapper.mkdir( directory )
      @file_wrapper.write( filepath, report.render( context, records ) )
      @written << filepath
    end
  end

  # Names the reports written, grouped by build context directory
  def failure_message
    tests   = @records.map { |record| record[:test] }.uniq.size
    message = "Sanitizers found #{pluralize( @records.size, 'problem' )} in #{pluralize( tests, 'test' )}"
    return message if @written.empty?

    return "#{message}. See the reports in #{written_by_directory}."
  end

  private

  def written_by_directory
    groups = @written.uniq.group_by { |path| File.dirname( path ) }
    return groups.map { |dir, paths| "#{dir}: #{paths.map { |path| File.basename( path ) }.join( ', ' )}" }.join( '; ' )
  end

  # The findings not yet recorded for this test, now recorded
  def add_new(context, test, findings)
    added = findings.reject { |finding| @records.any? { |record| same?( record, context, test, finding ) } }.uniq { |finding| key( finding ) }
    added.each { |finding| @records << { context: context, test: test, finding: finding } }
    return added
  end

  def same?(record, context, test, finding)
    return record[:context] == context && record[:test] == test && key( record[:finding] ) == key( finding )
  end

  def key(finding)
    return [finding.sanitizer, finding.kind, finding.file, finding.line]
  end

  # A build's first report for a test replaces the last build's log, and later ones follow it
  def write_log(log, findings)
    first = @mutex.synchronize { !@logged_tests.include?( log ) && @logged_tests << log }
    text  = findings.map( &:text ).join( "\n" )

    @file_wrapper.mkdir( File.dirname( log ) )
    @file_wrapper.write( log, first ? text : "\n#{text}", first ? 'w' : 'a' )
  end

  def pluralize(count, word)
    return "#{count} #{word}#{count == 1 ? '' : 's'}"
  end

end
