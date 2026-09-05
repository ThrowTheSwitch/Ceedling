# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'cgi'
require 'stringio'

class TestsReporter

  # Dependency injection
  attr_writer :config_walkinator

  # Setup value injection
  attr_writer :config

  # Dependency injection -- write() renders into an in-memory buffer and
  # hands the finished content to this in one call, rather than opening a
  # real file itself, so a report can be fully exercised in a test without
  # ever touching disk.
  attr_writer :file_wrapper

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
    buffer = StringIO.new
    header( stream: buffer, name: name, results: results, duration_s: duration_s )
    body( stream: buffer, name: name, results: results, duration_s: duration_s )
    footer( stream: buffer, name: name, results: results, duration_s: duration_s )
    @file_wrapper.write( filepath, buffer.string )
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

  # Escapes text for safe use inside an XML attribute or element body.
  # Returns a NEW string -- a reporter must never mutate a test name or
  # message in place, since the very same results structure this value came
  # from is handed unmodified to every other configured reporter in turn.
  def xml_escape(str)
    str.to_s.gsub(/[&<>"']/, '&' => '&amp;', '<' => '&lt;', '>' => '&gt;', '"' => '&quot;', "'" => '&apos;')
  end

  # Escapes text for safe interpolation into HTML. CGI.escapeHTML already
  # covers the same characters HTML needs escaped, so this reuses it rather
  # than hand-rolling a second near-identical table.
  def html_escape(str)
    CGI.escapeHTML(str.to_s)
  end

end