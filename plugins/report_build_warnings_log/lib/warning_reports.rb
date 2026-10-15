# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'json'
require 'ceedling/exceptions'

# The reports a build context's warnings can be written as. Each renders a context's
# warning records as a file's contents and names that file's extension. The plain text
# log is the default; SARIF and JSON are structured reports for other tools to read.
module WarningReports

  # The tools' own output, each warning as printed. A context without warnings has no log.
  class Text
    def extension = 'log'
    def write_empty? = false

    def render(_context, warnings)
      return warnings.map( &:text ).join
    end
  end

  # Ceedling's own JSON layout: a context and its warnings' parsed fields. A context
  # without warnings is still written, saying so.
  class Json
    def extension = 'json'
    def write_empty? = true

    def render(context, warnings)
      fields = warnings.map { |warning| warning.to_h.slice( :file, :line, :column, :severity, :flag, :message, :context, :text ) }
      return JSON.pretty_generate( { context: context.to_s, warnings: fields } ) + "\n"
    end
  end

  # SARIF 2.1.0, the OASIS standard for static analysis results, as one run by Ceedling
  # per build context. A context without warnings is a run with no results, which tells a
  # code scanning service that earlier results are gone.
  class Sarif
    SCHEMA = 'https://json.schemastore.org/sarif-2.1.0.json'.freeze
    LEVELS = { 'fatal error' => 'error', 'error' => 'error', 'warning' => 'warning', 'note' => 'note', 'remark' => 'note' }.freeze

    def initialize(version)
      @version = version
    end

    def extension = 'sarif'
    def write_empty? = true

    # The driver's rules are the warnings' distinct flags, which code scanning services
    # expect to find for each result's rule
    def render(context, warnings)
      rules = warnings.filter_map( &:flag ).uniq.map { |flag| { id: flag } }
      run   = {
        tool:              { driver: { name: 'Ceedling', version: @version, informationUri: 'https://www.throwtheswitch.org/ceedling', rules: rules } },
        automationDetails: { id: "#{context}/" },
        results:           warnings.map { |warning| result( warning ) }
      }
      return JSON.pretty_generate( { '$schema': SCHEMA, version: '2.1.0', runs: [run] } ) + "\n"
    end

    private

    # A warning without a parsed diagnostic is a message alone. SARIF's default level is
    # warning, so an unknown severity leaves it out.
    def result(warning)
      result = {}
      result[:ruleId]    = warning.flag if warning.flag
      result[:level]     = LEVELS[warning.severity] if warning.severity
      result[:message]   = { text: warning.message }
      result[:locations] = [location( warning )] if warning.file
      result[:properties] = { context: warning.context, text: warning.text }
      return result
    end

    def location(warning)
      region = { startLine: warning.line }
      region[:startColumn] = warning.column if warning.column
      return { physicalLocation: { artifactLocation: artifact( warning.file ), region: region } }
    end

    # A relative path is relative to the project, which SARIF names %SRCROOT%, and loses
    # any leading `./` that would keep it from matching the project's file. An absolute
    # path, POSIX or Windows, is a file URI.
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

  NAMES = %i[text sarif json].freeze

  # The configured reports, each once, in the order given. Entries are symbols or strings
  # in any letter case, and none configured is the text log alone.
  def self.load(entries, version:)
    names = Array( entries ).map { |entry| name( entry ) }.uniq
    names = [:text] if names.empty?

    return names.map do |name|
      case name
      when :text  then Text.new
      when :sarif then Sarif.new( version )
      when :json  then Json.new
      end
    end
  end

  # The configured filename without its extension, which each report supplies
  def self.basename(filename)
    return filename.delete_suffix( File.extname( filename ) )
  end

  def self.name(entry)
    unless entry.is_a?( String ) or entry.is_a?( Symbol )
      raise CeedlingException.new( ":report_build_warnings_log ↳ :reports entry `#{entry}` is not a symbol or string." )
    end

    name = entry.to_s.downcase.to_sym
    return name if NAMES.include?( name )

    choices = NAMES.map( &:inspect ).join( ', ' )
    raise CeedlingException.new( ":report_build_warnings_log ↳ :reports entry `#{entry}` is not a report. Choose from #{choices}." )
  end
  private_class_method :name

end
