# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

class PathValidator

  constructor :file_wrapper, :loginator

  def validate(paths:, source:, type: :filepath)
    validated = true

    paths.each do |path|
      # Error out on empty paths
      if path.empty?
        validated = false
        @loginator.log( "#{source} contains an empty path", Verbosity::ERRORS )
        next
      end

      # Error out if path is not a directory / does not exist
      if (type == :directory) and !@file_wrapper.directory?( path )
        validated = false
        @loginator.log( "#{source} '#{path}' does not exist as a directory in the filesystem", Verbosity::ERRORS )
      end

      # Error out if filepath does not exist
      if (type == :filepath) and !@file_wrapper.exist?( path )
        validated = false
        @loginator.log( "#{source} '#{path}' does not exist in the filesystem", Verbosity::ERRORS )
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


  def filepath?(str)
    # If argument includes a file extension or a path separator, it's a filepath
    return (!File.extname( str ).empty?) || (str.include?( File::SEPARATOR ))
  end

end