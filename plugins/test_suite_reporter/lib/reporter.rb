
class Reporter

  # Dependency injection
  attr_writer :config_walkinator

  # Setup value injection
  attr_writer :handle, :config

  # Publicly accessible filename for the resulting report
  attr_reader :filename

  def initialize()
    # Safe default value in case a user custom subclass forgets to call setup()
    # FooBarReporter => foo_bar.report
    
    # Start with class name
    @filename = self.class.name.dup()

    # Remove 'Reporter' from end of class name
    @filename.chomp!( 'Reporter' )

    # Replace each capital letter with _lowercase ('A' => '_a')
    @filename.gsub!( /([A-Z])/ ) {|match| '_' + match.downcase()}

    # Remove leading underscore
    @filename.gsub!( /^_/, '')

    # Add a file extension
    @filename += '.report'
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