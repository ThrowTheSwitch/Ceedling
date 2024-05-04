# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'unicode/display_width'

##
# Pretifies reports
class Reportinator

  # Generate human readable string of days, hours, minutes, seconds (and 
  # milliseconds) from a start count of seconds and end count of seconds.
  def self.generate_duration(start_time_s:, end_time_s:)
    return '' if start_time_s.nil? or end_time_s.nil?

    # Calculate duration as integer milliseconds
    duration_ms = ((end_time_s - start_time_s) * 1000).to_i

    # Collect human readable time string tidbits
    duration = []

    # Singular / plural whole days
    if duration_ms >= DurationCounts::DAY_MS
      days = duration_ms / DurationCounts::DAY_MS
      duration << "#{days} day#{'s' if days > 1}"
      duration_ms -= (days * DurationCounts::DAY_MS)
      # End duration string if remainder is less than 1 second (e.g. no 2 days 13 milliseconds)
      duration_ms = 0 if duration_ms < 1000
    end

    # Singular / plural whole hours
    if duration_ms >= DurationCounts::HOUR_MS
      hours = duration_ms / DurationCounts::HOUR_MS
      duration << "#{hours} hour#{'s' if hours > 1}"
      duration_ms -= (hours * DurationCounts::HOUR_MS)
      # End duration string if remainder is less than 1 second (e.g. no 2 days 13 milliseconds)
      duration_ms = 0 if duration_ms < 1000
    end

    # Singular / plural whole minutes
    if duration_ms >= DurationCounts::MINUTE_MS
      minutes = duration_ms / DurationCounts::MINUTE_MS
      duration << "#{minutes} minute#{'s' if minutes > 1}"
      duration_ms -= (minutes * DurationCounts::MINUTE_MS)
      # End duration string if remainder is less than 1 second (e.g. no 2 days 13 milliseconds)
      duration_ms = 0 if duration_ms < 1000
    end

    # Plural fractional seconds (rounded)
    if duration_ms >= DurationCounts::SECOND_MS
      seconds = (duration_ms.to_f() / 1000.0).round(2)
      duration << "#{seconds} seconds"
      # End duration string
      duration_ms = 0
    end

    # Singular / plural whole milliseconds (only if orginal duration less than 1 second)
    if duration_ms > 0
      duration << "#{duration_ms} millisecond#{'s' if duration_ms > 1}"
    end

    return duration.join(' ')
  end

  def generate_duration(start_time_s:, end_time_s:)
    return Reportinator.generate_duration( start_time_s: start_time_s, end_time_s: end_time_s )
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

    # If filename is the module name, don't add the module label
    label = (File.basename(filename).ext('') == module_name.to_s) ? '' : "#{module_name}::"
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
