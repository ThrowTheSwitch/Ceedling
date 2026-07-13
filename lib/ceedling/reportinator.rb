# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'unicode/display_width'

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

    # If filename is the module name, don't add the module label
    label = (File.basename(filename).ext('') == _module_name) ? '' : "#{_module_name}::"
    return generate_progress("#{operation} #{label}#{filename}")
  end

  def generate_config_walk(keys, depth=0)
    # :key ↳ :key ↳ :key

    _keys = keys.clone
    _keys = _keys.slice(0, depth) if depth > 0
    _keys.reject! { |key| key.nil? }
    return _keys.map{|key| ":#{key}"}.join(' ↳ ')
  end

end
