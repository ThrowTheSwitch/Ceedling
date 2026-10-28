# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/project_paths'

# Where a build places a file of a path: by its path from the project root, so two files
# never share a build file and none lands outside the build directory. `..` becomes `_up_`,
# a path on another drive goes under `_abs_` or `_unc_`, and a file of the running Ceedling
# installation outside the project goes under `_ceedling_`. `decode` inverts `encode` exactly.
module BuildSubpath

  PARENT_SEGMENT    = '_up_'
  ABSOLUTE_SEGMENT  = '_abs_'
  UNC_SEGMENT       = '_unc_'
  INSTALLED_SEGMENT = '_ceedling_'

  # The running Ceedling installation, above lib/ceedling/
  INSTALLATION_ROOT = File.expand_path( '../..', __dir__ )

  @lock     = Mutex.new
  @subpaths = {}

  # The build subpath that places a file of `path` by its path from the project root
  def self.encode(path)
    full = ProjectPaths.absolute( path )
    rel  = ProjectPaths.relative( full )

    return installed_segments( full ).join( '/' ) if outside?( rel ) && installed?( full )
    return absolute_segments( rel ).join( '/' ) if ProjectPaths.absolute?( rel )

    return ProjectPaths.segments( rel ).map { |segment| segment == '..' ? PARENT_SEGMENT : segment }.join( '/' )
  end

  # The path, in intake's spelling, that `encode` made `subpath` from
  def self.decode(subpath)
    segments = ProjectPaths.segments( subpath )

    case segments.first
    when INSTALLED_SEGMENT then return ProjectPaths.relative( File.join( INSTALLATION_ROOT, *segments.drop( 1 ) ) )
    when UNC_SEGMENT       then return "//#{segments.drop( 1 ).join( '/' )}"
    when ABSOLUTE_SEGMENT  then return "#{segments[1]}:/#{segments.drop( 2 ).join( '/' )}"
    end

    return segments.map { |segment| segment == PARENT_SEGMENT ? '..' : segment }.join( '/' )
  end

  # `encode` for a directory, memoized, since a build places many files from each directory.
  # The working directory itself encodes as ''.
  def self.of_directory(dir)
    key = [ProjectPaths.working_dir, dir.to_s]
    return @lock.synchronize { @subpaths[key] ||= encode( dir ) }
  end

  def self.outside?(relative)
    return relative == '..' || relative.start_with?( '../' )
  end

  def self.installed?(full)
    return ProjectPaths.same?( INSTALLATION_ROOT, full ) || ProjectPaths.starts_with?( full, "#{INSTALLATION_ROOT}/" )
  end

  def self.installed_segments(full)
    return [INSTALLED_SEGMENT] + ProjectPaths.segments( full[INSTALLATION_ROOT.length..] )
  end

  # An absolute path's segments below `_abs_`, a drive letter as a plain segment, or below
  # `_unc_` for a share
  def self.absolute_segments(path)
    return [UNC_SEGMENT] + ProjectPaths.segments( path ) if ProjectPaths.unc?( path )

    parts = ProjectPaths.segments( path )
    return [ABSOLUTE_SEGMENT] + parts.each_with_index.map { |part, index| index.zero? ? part.delete_suffix( ':' ) : part }
  end

  private_class_method :outside?, :installed?, :installed_segments, :absolute_segments

end
