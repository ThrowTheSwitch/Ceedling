
class PathValidator

  constructor :file_wrapper, :streaminator

  def validate(paths:, source:, type: :filepath)
    validated = true

    paths.each do |path|
      # Error out on empty paths
      if path.empty?
        validated = false
        @streaminator.stream_puts( "ERROR: #{source} contains an empty path", Verbosity::ERRORS )
        next
      end

      # Error out if path is not a directory / does not exist
      if (type == :directory) and !@file_wrapper.directory?( path )
        validated = false
        @streaminator.stream_puts( "ERROR: #{source} '#{path}' does not exist as a directory in the filesystem", Verbosity::ERRORS )
      end

      # Error out if filepath does not exist
      if (type == :filepath) and !@file_wrapper.exist?( path )
        validated = false
        @streaminator.stream_puts( "ERROR: #{source} '#{path}' does not exist in the filesystem", Verbosity::ERRORS )
      end
    end

    return validated
  end

  # Ensure any Windows backslashes are converted to Ruby path forward slashes
  # Santization happens inline
  def standardize_paths( *paths )
    paths.each do |path|
      next if path.nil? or path.empty?
      path.gsub!( "\\", '/' )
    end
  end

end