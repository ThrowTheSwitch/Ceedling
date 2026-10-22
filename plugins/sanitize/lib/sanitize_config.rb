# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/exceptions'

# The compile and link flags and the runtime environment a project's :sanitize settings
# call for on a platform, checked as they are read
class SanitizeConfig
  attr_reader :sanitizers, :compile_flags, :link_flags, :environment, :notices, :test_builds, :fail_build

  NAMES = %i[address undefined leak].freeze

  # Each sanitizer's runtime options variable, keyed as :runtime_options names them
  OPTION_VARIABLES = { asan: 'ASAN_OPTIONS', ubsan: 'UBSAN_OPTIONS', lsan: 'LSAN_OPTIONS' }.freeze

  LEAKS_UNSUPPORTED = 'Leak detection is not supported on macOS and has been disabled.'.freeze

  def initialize(config, platform:)
    @config   = config
    @platform = platform
    @notices  = []

    read_switches
    @sanitizers = sanitizer_list

    @compile_flags = compile_flags_list
    @link_flags    = ["-fsanitize=#{instrumented.join( ',' )}"] + Array( flags[:link] )
    @environment   = runtime_environment
  end

  private

  def read_switches
    @recover      = boolean( :recover )
    @detect_leaks = boolean( :detect_leaks )
    @test_builds  = boolean( :test_builds )
    @fail_build   = boolean( :fail_build )
  end

  def flags
    return @config[:flags] || {}
  end

  # LeakSanitizer is not supported on macOS, where ASan aborts if asked to check leaks
  def sanitizer_list
    names = Array( @config[:sanitizers] ).map { |entry| name( entry ) }.uniq
    raise CeedlingException.new( ':sanitize ↳ :sanitizers names no sanitizer.' ) if names.empty?
    return names unless @platform == :macos && (names.include?( :leak ) || (@detect_leaks && names.include?( :address )))

    @notices << LEAKS_UNSUPPORTED
    return names - [:leak]
  end

  def name(entry)
    sanitizer = entry.to_s.downcase.to_sym
    return sanitizer if (entry.is_a?( String ) || entry.is_a?( Symbol )) && NAMES.include?( sanitizer )

    choices = NAMES.map( &:inspect ).join( ', ' )
    raise CeedlingException.new( ":sanitize ↳ :sanitizers entry `#{entry}` is not a supported sanitizer. Choose from #{choices}." )
  end

  # ASan's runtime includes leak detection, so leaks need their own sanitizer only alone
  def instrumented
    return @sanitizers.include?( :address ) ? @sanitizers - [:leak] : @sanitizers
  end

  def compile_flags_list
    halting = @recover ? [] : ['-fno-sanitize-recover=all']
    return ["-fsanitize=#{instrumented.join( ',' )}"] + halting + ['-fno-omit-frame-pointer', '-g'] + Array( flags[:compile] )
  end

  # Findings come from each report, not from the exit code, so a sanitizer exits 0 and only
  # Unity's own exit code remains. A halt leaves Unity's summary missing, which reads as a
  # crash. A leak checked at exit leaves a clean summary.
  def runtime_environment
    return base_options.to_h { |key, values| [OPTION_VARIABLES[key], (values + Array( runtime_options[key] )).join( ':' )] }
  end

  def base_options
    halt = "halt_on_error=#{@recover ? 0 : 1}"
    options = {}
    options[:asan]  = [halt, 'exitcode=0'] + leak_option if @sanitizers.include?( :address )
    options[:ubsan] = [halt, 'print_stacktrace=1', 'exitcode=0'] if @sanitizers.include?( :undefined )
    options[:lsan]  = ['exitcode=0'] if instrumented.include?( :leak )
    return options
  end

  def leak_option
    return [] if @platform == :macos

    return ["detect_leaks=#{@detect_leaks ? 1 : 0}"]
  end

  def runtime_options
    return @config[:runtime_options] || {}
  end

  # A quoted 'false' would otherwise read as true
  def boolean(key)
    value = @config[key]
    return value if [true, false].include?( value )

    raise CeedlingException.new( ":sanitize ↳ :#{key} must be TRUE or FALSE, not `#{value.inspect}`." )
  end

end
