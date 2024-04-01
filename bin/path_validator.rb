
class PathValidator

  constructor :file_wrapper, :logger

  def validate(paths:, source:, type: :filepath)
    validated = true

    paths.each do |path|
      # Error out on empty paths
      if path.empty?
        validated = false
        @logger.log( "ERROR: #{source} contains an empty path" )
        next
      end

      # Error out if path is not a directory / does not exist
      if (type == :directory) and !@file_wrapper.directory?( path )
        validated = false
        @logger.log( "ERROR: #{source} '#{path}' does not exist as a directory in the filesystem" )
      end

      # Error out if filepath does not exist
      if (type == :filepath) and !@file_wrapper.exist?( path )
        validated = false
        @logger.log( "ERROR: #{source} '#{path}' does not exist in the filesystem" )
      end
    end

    return validated
  end

  # Ensure any Windows backslashes are converted to Ruby path forward slashes
  def standardize_paths( *paths )
    paths.each do |path|
      next if path.nil? or path.empty?
      path.gsub!( "\\", '/' )
    end
  end

end