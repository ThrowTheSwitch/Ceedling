# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'json'
require 'ceedling/exceptions'

# The reports a build context's sanitizer findings can be written as. Each renders a
# context's finding records, each a test and its finding, as a file's contents and names
# that file's extension. The text log is the default; JSON and SARIF are structured
# reports for other tools to read.
module SanitizeReports

  LABELS = { address: 'AddressSanitizer', undefined: 'UndefinedBehaviorSanitizer', leak: 'LeakSanitizer' }.freeze

  # A finding's sanitizer, kind, and location in one line. UBSan names every finding
  # undefined behavior, so its message says what happened instead.
  def self.headline(finding)
    location = finding.file ? " at #{finding.file}:#{finding.line}" : ''
    what     = finding.sanitizer == :undefined ? finding.message : finding.kind
    return "#{LABELS[finding.sanitizer]} #{what}#{location}"
  end

  # Each report as the sanitizer printed it, under its test. A context without findings has
  # no log.
  class Text
    def extension = 'log'
    def write_empty? = false

    def render(_context, records)
      return records.map { |record| "#{record[:test]}: #{SanitizeReports.headline( record[:finding] )}\n#{record[:finding].text}\n" }.join
    end
  end

  # Ceedling's own JSON layout: a context and its findings' parsed fields. A context without
  # findings is still written, saying so.
  class Json
    def extension = 'json'
    def write_empty? = true

    def render(context, records)
      findings = records.map { |record| { test: record[:test] }.merge( record[:finding].to_h.except( :text ) ) }
      return JSON.pretty_generate( { context: context.to_s, findings: findings } ) + "\n"
    end
  end

  # SARIF 2.1.0, the OASIS standard for analysis results, as one run by Ceedling per build
  # context. Every finding is an error. A context without findings is a run with no results,
  # which tells a code scanning service that earlier results are gone.
  class Sarif
    SCHEMA = 'https://json.schemastore.org/sarif-2.1.0.json'.freeze

    def initialize(version)
      @version = version
    end

    def extension = 'sarif'
    def write_empty? = true

    def render(context, records)
      rules = records.map { |record| rule_id( record[:finding] ) }.uniq.map { |id| { id: id } }
      run   = {
        tool:              { driver: { name: 'Ceedling', version: @version, informationUri: 'https://www.throwtheswitch.org/ceedling', rules: rules } },
        automationDetails: { id: "#{context}/" },
        results:           records.map { |record| result( record ) }
      }
      return JSON.pretty_generate( { '$schema': SCHEMA, version: '2.1.0', runs: [run] } ) + "\n"
    end

    private

    def rule_id(finding)
      return "#{finding.sanitizer}/#{finding.kind}"
    end

    def result(record)
      finding = record[:finding]
      result  = { ruleId: rule_id( finding ), level: 'error', message: { text: "#{record[:test]}: #{finding.message}" } }
      result[:locations]  = [location( finding )] if finding.file
      result[:properties] = { test: record[:test], text: finding.text }
      return result
    end

    def location(finding)
      region = { startLine: finding.line }
      region[:startColumn] = finding.column if finding.column
      return { physicalLocation: { artifactLocation: artifact( finding.file ), region: region } }
    end

    # A relative path is relative to the project, which SARIF names %SRCROOT%, and loses any
    # leading `./` that would keep it from matching the project's file. An absolute path,
    # POSIX or Windows, is a file URI.
    def artifact(file)
      path = file.tr( '\\', '/' ).sub( %r{\A(?:\./)+}, '' )
      return { uri: "file://#{encode( path )}" } if path.start_with?( '/' )
      return { uri: "file:///#{encode( path )}" } if path.match?( %r{\A[A-Za-z]:/} )

      return { uri: encode( path ), uriBaseId: '%SRCROOT%' }
    end

    def encode(path)
      return path.gsub( %r{[^A-Za-z0-9\-._~/:]} ) { |char| char.bytes.map { |byte| format( '%%%02X', byte ) }.join }
    end
  end

  NAMES = %i[text json sarif].freeze

  # The configured reports, each once, in the order given. Entries are symbols or strings in
  # any letter case, and none configured is the text log alone.
  def self.load(entries, version:)
    names = Array( entries ).map { |entry| name( entry ) }.uniq
    names = [:text] if names.empty?

    return names.map do |name|
      case name
      when :text  then Text.new
      when :json  then Json.new
      when :sarif then Sarif.new( version )
      end
    end
  end

  def self.name(entry)
    report = entry.to_s.downcase.to_sym
    return report if (entry.is_a?( String ) || entry.is_a?( Symbol )) && NAMES.include?( report )

    choices = NAMES.map( &:inspect ).join( ', ' )
    raise CeedlingException.new( ":sanitize ↳ :reports entry `#{entry}` is not a report. Choose from #{choices}." )
  end
  private_class_method :name

end
