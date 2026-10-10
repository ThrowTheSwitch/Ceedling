# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'cgi'
require 'stringio'

class TestsReporter

  # The report name when a project names none. A report may title itself differently
  # for it, so it is shared here.
  DEFAULT_REPORT_NAME = 'Ceedling Test Suite'

  # Dependency injection
  attr_writer :config_walkinator

  # Setup value injection
  attr_writer :config

  # Dependency injection. A report renders in memory and reaches disk only through this,
  # so a test can exercise a whole report without touching the filesystem.
  attr_writer :file_wrapper

  # Publicly accessible filename for the resulting report
  attr_reader :filename

  # A custom subclass that never calls setup() still gets a usable filename, e.g.
  # 'foo_bar.report' for a report named 'foo_bar'
  def initialize(handle:)
    @handle = handle
    @filename = "#{handle}.report"
  end

  def setup(default_filename:)
    @filename = update_filename( default_filename )
  end

  # Renders the report's sections in order, then writes the whole report in one call
  def write(name:, filepath:, results:, duration_s:nil)
    buffer = StringIO.new
    [:header, :body, :footer].each do |section|
      public_send( section, stream: buffer, name: name, results: results, duration_s: duration_s )
    end
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

  # The configured filename, or the subclass's default
  def update_filename(default_filename)
    filename, _ = @config_walkinator.fetch_value( :filename, hash:@config, default:default_filename )
    return filename
  end

  # Handy convenience method for subclasses
  def fetch_config_value(*keys)
    result, _ = @config_walkinator.fetch_value( *keys, hash:@config )
    return result
  end

  # Escapes text for an XML attribute or element body. Every reporter receives the same
  # results, so this returns a new string and never alters a name or message in place.
  def xml_escape(str)
    str.to_s.gsub( /[&<>"']/, '&' => '&amp;', '<' => '&lt;', '>' => '&gt;', '"' => '&quot;', "'" => '&apos;' )
  end

  # Escapes text for HTML. Like xml_escape, it returns a new string.
  def html_escape(str)
    CGI.escapeHTML( str.to_s )
  end

end
