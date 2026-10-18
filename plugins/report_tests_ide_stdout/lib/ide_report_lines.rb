# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/exceptions'

# The lines a report gives one failed or ignored test, each ending in a newline
class IdeReportLines

  # Each format a project can name, with the path form it gets when :absolute_paths is
  # unset and the path forms it allows. An IDE's name stands for the gcc configuration that
  # IDE reads.
  PROFILES = {
    gcc:     { format: :gcc,    absolute_paths: false, allowed: [true, false] },
    legacy:  { format: :legacy, absolute_paths: false, allowed: [true, false] },
    vscode:  { format: :gcc,    absolute_paths: false, allowed: [true, false] },
    eclipse: { format: :gcc,    absolute_paths: false, allowed: [true, false] },
    # CLion's output filters find only absolute paths
    clion:   { format: :gcc,    absolute_paths: true,  allowed: [true] }
  }.freeze

  SEVERITIES = { failed: 'error', ignored: 'warning' }.freeze

  # Unity reports a test's line but no column, and the gcc shape needs one
  COLUMN = 1

  # Sets a message's continuation lines under its test's problem in the console
  INDENT = '    '

  def self.load(config)
    name    = profile_name( config[:format] )
    profile = PROFILES[name]

    return new( format: profile[:format], absolute_paths: absolute_paths( config[:absolute_paths], name, profile ) )
  end

  def self.profile_name(entry)
    unless entry.is_a?( String ) or entry.is_a?( Symbol )
      raise CeedlingException.new( ":report_tests_ide_stdout ↳ :format `#{entry.inspect}` is not a symbol or string." )
    end

    name = entry.to_s.downcase.to_sym
    return name if PROFILES.key?( name )

    choices = PROFILES.keys.map( &:inspect ).join( ', ' )
    raise CeedlingException.new( ":report_tests_ide_stdout ↳ :format `#{entry}` is not a format. Choose from #{choices}." )
  end

  # Unset takes the format's own path form
  def self.absolute_paths(value, name, profile)
    return profile[:absolute_paths] if value.nil?
    return value if profile[:allowed].include?( boolean( value ) )

    raise CeedlingException.new(
      ":report_tests_ide_stdout ↳ :absolute_paths cannot be #{value.to_s.upcase} with :format #{name.inspect}. " +
      "Remove :absolute_paths or set it #{(!value).to_s.upcase}."
    )
  end

  # A quoted 'true' would otherwise read as a setting it is not
  def self.boolean(value)
    return value if [true, false].include?( value )

    raise CeedlingException.new( ":report_tests_ide_stdout ↳ :absolute_paths must be TRUE or FALSE, not `#{value.inspect}`." )
  end
  private_class_method :profile_name, :absolute_paths, :boolean

  def initialize(format:, absolute_paths:)
    @format         = format
    @absolute_paths = absolute_paths
  end

  # Paths expand against the working directory, which is the project's root
  def lines(file, item, outcome)
    path = @absolute_paths ? File.expand_path( file ) : file

    return (@format == :gcc) ? gcc( path, item, outcome ) : legacy( path, item )
  end

  private

  # The shape of a GCC diagnostic, which IDEs read as a problem without configuration. The
  # message's first line goes with the test's location, and the rest follow indented.
  def gcc(path, item, outcome)
    first, *rest = item[:message].each_line( chomp: true ).to_a
    problem = [ item[:test], first ].reject { |part| part.to_s.empty? }.join( ': ' )

    located = "#{path}:#{item[:line]}:#{COLUMN}: #{SEVERITIES[outcome]}: #{problem}\n"
    return located + rest.map { |line| "#{INDENT}#{line}\n" }.join
  end

  # Every line of a message carries the test's file, line, and name, so each stays a link
  def legacy(path, item)
    prefix = "#{path}:#{item[:line]}:#{item[:test]}"
    return "#{prefix}\n" if item[:message].empty?

    return %(#{prefix}: "#{item[:message].each_line( chomp: true ).to_a.join( "\n#{prefix}: " )}"\n)
  end

end
