
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
  def write(filepath:, results:)
    File.open( filepath, 'w' ) do |f|
      header( results: results, stream: f )
      body( results: results, stream: f )
      footer( results: results, stream: f )
    end
  end

  def header(results:, stream:)
    # Override in subclass to do something
  end

  def body(results:, stream:)
    # Override in subclass to do something
  end

  def footer(results:, stream:)
    # Override in subclass to do something
  end

  ### Private

  private

  def update_filename(default_filename)
    filename = fetch_config_value(:filename)

    # Otherwise, use default filename
    return filename.nil? ? default_filename : filename
  end

  def fetch_config_value(*keys)
    result = @config_walkinator.fetch_value( @config, *keys )
    return result[:value] if !result[:value].nil?
    return nil
  end

end