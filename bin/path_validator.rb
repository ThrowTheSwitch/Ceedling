# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/filesystem/project_paths'

class PathValidator

  constructor :file_wrapper, :loginator

  # Logs why each of `paths` fails as a `type` (:filepath or :directory), and whether none did
  def validate(paths:, source:, type: :filepath)
    problems = paths.filter_map { |path| path_problem( path, type ) }
    problems.each { |problem| @loginator.log( "#{source} #{problem}", Verbosity::ERRORS ) }

    return problems.empty?
  end

  # Each path spelled as configuration spells it (ProjectPaths.standardize): forward slashes,
  # `~` as the home directory, no trailing separator. Returns new values in the same order as
  # the arguments given, rather than mutating the caller's own String objects in place.
  def standardize_paths( *paths )
    paths.map do |path|
      next path if path.nil? or path.strip.empty?
      ProjectPaths.standardize( path )
    end
  end


  def filepath?(str)
    # If argument includes a file extension or a path separator, it's a filepath
    return (!File.extname( str ).empty?) || (str.include?( File::SEPARATOR ))
  end

  ### Private ###

  private

  # Why `path` fails as a `type`, or nil
  def path_problem(path, type)
    return 'contains an empty path' if path.empty?
    return "'#{path}' does not exist as a directory in the filesystem" if (type == :directory) and !@file_wrapper.directory?( path )
    return "'#{path}' does not exist in the filesystem" if (type == :filepath) and !@file_wrapper.exist?( path )

    return nil
  end

end
