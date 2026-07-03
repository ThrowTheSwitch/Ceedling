# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

class TestsReporter

  # Dependency injection
  attr_writer :config_walkinator

  # Setup value injection
  attr_writer :config

  # Publicly accessible filename for the resulting report
  attr_reader :filename

  def initialize(handle:)
    @handle = handle

    # Safe default filename in case user's custom subclass forgets to call 
    # setup() with a default filename.
    # If the report is named 'foo_bar' in project configuration, the 
    # fallback filename is 'foo_bar.report'
    @filename = "#{handle}.report"
  end

  def setup(default_filename:)
    @filename = update_filename( default_filename )
  end

  # Write report contents to file
  def write(name:, filepath:, results:, duration_s:nil)
    File.open( filepath, 'w' ) do |f|
      header( stream: f, name: name, results: results, duration_s: duration_s )
      body( stream: f, name: name, results: results, duration_s: duration_s )
      footer( stream: f, name: name, results: results, duration_s: duration_s )
    end
  end

  def header(stream:, name:, results:, duration_s:)
    # Override in subclass to do something
  end

  def body(stream:, name:, results:, duration_s:)
    # Override in subclass to do something
  end

  def footer(stream:, name:, results:, duration_s:)
    # Override in subclass to do something
  end

  ### Private

  private

  def update_filename(default_filename)
    # Fetch configured filename if it exists, otherwise return default filename
    filename, _ = @config_walkinator.fetch_value( :filename, hash:@config, default:default_filename )
    return filename
  end

  # Handy convenience method for subclasses
  def fetch_config_value(*keys)
    result, _ = @config_walkinator.fetch_value( *keys, hash:@config )
    return result
  end

end