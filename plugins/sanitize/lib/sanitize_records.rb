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
# Tests run in parallel, so recording is synchronized.
class SanitizeRecords

  def initialize(file_wrapper:, loginator:, reports:)
    @file_wrapper = file_wrapper
    @loginator    = loginator
    @reports      = reports
    @records      = []
    @mutex        = Mutex.new
  end

  def empty? = @records.empty?

  def self.log_filepath(context, test)
    return File.join( SANITIZE_ARTIFACTS_PATH, context.to_s, "#{test}.log" )
  end

  # Writes a test's sanitizer reports to its own log and logs each finding
  def record(context, test, findings)
    log = SanitizeRecords.log_filepath( context, test )

    @file_wrapper.mkdir( File.dirname( log ) )
    @file_wrapper.write( log, findings.map( &:text ).join( "\n" ) )

    @mutex.synchronize { findings.each { |finding| @records << { context: context, test: test, finding: finding } } }
    findings.each do |finding|
      @loginator.log( "#{test}: #{SanitizeReports.headline( finding )} ➡️ see #{log}", Verbosity::ERRORS, LogLabels::ERROR )
    end
  end

  def write_reports(context)
    records   = @records.select { |record| record[:context] == context }
    directory = File.join( SANITIZE_ARTIFACTS_PATH, context.to_s )

    @reports.each do |report|
      next if records.empty? && !report.write_empty?

      @file_wrapper.mkdir( directory )
      @file_wrapper.write( File.join( directory, "#{SANITIZE_ROOT_NAME}.#{report.extension}" ), report.render( context, records ) )
    end
  end

  # Counts by sanitizer and kind
  def log_tally
    return if empty?

    tally = @records.map { |record| "#{SanitizeReports::LABELS[record[:finding].sanitizer]} #{record[:finding].kind}" }.tally
    lines = tally.map { |kind, count| " - #{kind}: #{count}" }
    @loginator.log( "Sanitizer findings:\n#{lines.join( "\n" )}", Verbosity::NORMAL )
  end

  def failure_message
    tests = @records.map { |record| record[:test] }.uniq.size
    return "Sanitizers found #{pluralize( @records.size, 'problem' )} in #{pluralize( tests, 'test' )}"
  end

  private

  def pluralize(count, word)
    return "#{count} #{word}#{count == 1 ? '' : 's'}"
  end

end
