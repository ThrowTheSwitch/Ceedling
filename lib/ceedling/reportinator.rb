# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'unicode/display_width'
require 'ceedling/constants'

##
# Pretifies reports
class Reportinator

  # Generate human readable string of days, hours, minutes, seconds (and
  # milliseconds) from a floating-point count of seconds. The optional
  # +precision+ keyword controls decimal places on the sub-minute seconds
  # field (default: 2). When +abbreviate+ is true, "hour", "minute", and
  # "second" are shortened to "hr", "min", and "sec" (pluralized as normal).
  def self.generate_duration_string(seconds_s, precision: 2, abbreviate: false)
    # Calculate duration as integer milliseconds
    duration_ms = (seconds_s * 1000).to_i

    # Collect human readable time string tidbits
    duration = []

    # Singular/plural unit label, with optional abbreviation for hr/min/sec
    unit = ->(count, full, abbrev = nil) {
      word = (abbreviate && abbrev) ? abbrev : full
      "#{count} #{word}#{'s' if count > 1}"
    }

    # Singular / plural whole days
    if duration_ms >= DurationCounts::DAY_MS
      days = duration_ms / DurationCounts::DAY_MS
      duration << unit.call(days, 'day')
      duration_ms -= (days * DurationCounts::DAY_MS)
      # End duration string if remainder is less than 1 second (e.g. no 2 days 13 milliseconds)
      duration_ms = 0 if duration_ms < 1000
    end

    # Singular / plural whole hours
    if duration_ms >= DurationCounts::HOUR_MS
      hours = duration_ms / DurationCounts::HOUR_MS
      duration << unit.call(hours, 'hour', 'hr')
      duration_ms -= (hours * DurationCounts::HOUR_MS)
      # End duration string if remainder is less than 1 second (e.g. no 2 days 13 milliseconds)
      duration_ms = 0 if duration_ms < 1000
    end

    # Singular / plural whole minutes
    if duration_ms >= DurationCounts::MINUTE_MS
      minutes = duration_ms / DurationCounts::MINUTE_MS
      duration << unit.call(minutes, 'minute', 'min')
      duration_ms -= (minutes * DurationCounts::MINUTE_MS)
      # End duration string if remainder is less than 1 second (e.g. no 2 days 13 milliseconds)
      duration_ms = 0 if duration_ms < 1000
    end

    # Plural fractional seconds (rounded to requested precision)
    if duration_ms >= DurationCounts::SECOND_MS
      seconds = (duration_ms.to_f / 1000.0).round(precision)
      duration << "#{seconds} #{abbreviate ? 'secs' : 'seconds'}"
      # End duration string
      duration_ms = 0
    end

    # Singular / plural whole milliseconds (only if original duration less than 1 second)
    if duration_ms > 0
      duration << unit.call(duration_ms, 'millisecond')
    end

    return duration.join(' ')
  end

  # Generate human readable string of days, hours, minutes, seconds (and
  # milliseconds) from a start count of seconds and end count of seconds.
  def self.generate_duration_from_interval(start_time_s:, end_time_s:, precision: 2, abbreviate: false)
    return '' if start_time_s.nil? || end_time_s.nil?
    Reportinator.generate_duration_string( end_time_s - start_time_s, precision: precision, abbreviate: abbreviate )
  end

  # Default headings for each guidance section, as [plural, singular]
  GUIDANCE_HEADINGS = {
    causes:  ['HOW THIS HAPPENS', 'HOW THIS HAPPENS'],
    notes:   ['NOTES', 'NOTE'],
    options: ['OPTIONS', 'OPTIONS']
  }.freeze

  # Builds guidance text in Ceedling's one layout for explaining a failure or a limit.
  # Blocks come in the order lead, causes, notes, options and closing, one blank line apart.
  # Causes and notes are bullets and options are numbered. A section with one item collapses
  # to one line: a cause or a note keeps its heading inline, and a lone option stands alone.
  # Nil items drop out, so a caller writes a conditional item as `(text if condition)`.
  # An empty section is left out. +lead+ is a String or an Array of lines. +headings+ gives a
  # section's [plural, singular] headings, or one String for both. Items are never wrapped.
  def self.generate_guidance(lead: nil, causes: [], notes: [], options: [], closing: nil, headings: {})
    validate_guidance_headings( headings )

    sections = { causes: causes, notes: notes, options: options }.map do |section, items|
      guidance_section( section, Array( items ).compact, headings )
    end

    blocks = [Array( lead ).compact.join( "\n" ), *sections, closing.to_s].map( &:rstrip ).reject( &:empty? )

    return blocks.empty? ? '' : "#{blocks.join( "\n\n" )}\n"
  end

  # Heading overrides name only the sections the layout has
  def self.validate_guidance_headings(headings)
    unknown = headings.keys - GUIDANCE_HEADINGS.keys
    raise ::ArgumentError, "Unknown guidance section #{unknown.map( &:inspect ).join( ', ' )}" unless unknown.empty?
  end

  # One guidance section as a block of text, or '' when it has no items
  def self.guidance_section(section, items, headings)
    plural, singular = Array( headings[section] || GUIDANCE_HEADINGS[section] )

    return '' if items.empty?
    return ((section == :options) ? items.first : "#{singular || plural}: #{items.first}") if items.size == 1

    lines = items.each_with_index.map { |item, index| "#{guidance_marker( section, index )} #{item}" }
    return "#{plural}:\n#{lines.join( "\n" )}"
  end

  # A numbered option's number, or a bullet for any other section's item
  def self.guidance_marker(section, index)
    return (section == :options) ? "#{index + 1}." : '•'
  end
  private_class_method :validate_guidance_headings, :guidance_section, :guidance_marker

  def generate_duration_string(seconds_s, precision: 2, abbreviate: false)
    return Reportinator.generate_duration_string( seconds_s, precision: precision, abbreviate: abbreviate )
  end

  def generate_duration_from_interval(start_time_s:, end_time_s:, precision: 2, abbreviate: false)
    return Reportinator.generate_duration_from_interval( start_time_s: start_time_s, end_time_s: end_time_s, precision: precision, abbreviate: abbreviate )
  end

  ##
  # Generates a banner for a message based on the length of the message or a
  # given width.
  # ==== Attributes
  #
  # * _message_:  The message to put.
  # * _width_:    The width of the message. If nil the size of the banner is
  # determined by the length of the message.
  #
  # ==== Examples
  #
  #    rp = Reportinator.new
  #    rp.generate_banner("Hello world!") => "------------\nHello world!\n------------\n" 
  #    rp.generate_banner("Hello world!", 3) => "---\nHello world!\n---\n" 
  #
  #
  def generate_banner(message, width=nil)
    # ---------
    # <Message>
    # ---------
    dash_count = ((width.nil?) ? Unicode::DisplayWidth.of( message.strip ) : width)
    return "#{'-' * dash_count}\n#{message}\n#{'-' * dash_count}\n"
  end

  def generate_heading(message)
    # <Message>
    # ---------
    return "\n#{message}\n#{'-' * Unicode::DisplayWidth.of( message.strip )}"
  end

  def generate_progress(message)
    # <Message>...
    return "#{message}..."
  end

  def generate_module_progress(module_name:, filename:, operation:)
    # <Operation [module_name::]filename>..."

    # Sanitze -- ensure it's a string and strip any filename extension
    _module_name = module_name.to_s().ext('')

    # If filename is the module name, don't add the module label. A test's name is
    # its path from the project root (e.g. `test/adc/TestFoo`), so only its last
    # segment is weighed against filename's bare basename.
    label = (File.basename(filename).ext('') == File.basename(_module_name)) ? '' : "#{_module_name}::"
    return generate_progress("#{operation} #{label}#{filename}")
  end

  # States, in one line, how many targets a build step left untouched because
  # nothing about them needed attention this run -- shared by every build stage
  # that skips individual targets (test and release alike), so this wording and
  # its singular/plural handling live in exactly one place. Returns nil when
  # nothing was skipped, so a full rebuild's output isn't cluttered with zero
  # counts; callers only log when a message comes back.
  def generate_skip_summary(task:, count:, noun:, reason: "nothing changed")
    return nil if count == 0
    singular_noun = noun.sub(/s$/, '')
    generate_progress( "Skipping #{task} for #{count} #{count == 1 ? singular_noun : noun} (#{reason})" )
  end

  def generate_config_walk(keys, depth=0)
    # :key ↳ :key ↳ :key

    _keys = keys.clone
    _keys = _keys.slice(0, depth) if depth > 0
    _keys.reject! { |key| key.nil? }
    return _keys.map{|key| ":#{key}"}.join(' ↳ ')
  end

end
