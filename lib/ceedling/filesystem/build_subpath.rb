# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/filesystem/project_paths'

# Where a build places a file of a path: by its path from the project root, so two files
# never share a build file and none lands outside the build directory. `..` becomes `_up_`,
# a path on another drive goes under `_abs_` or `_unc_`, and a file the running Ceedling
# installation ships, outside the project, goes under `_ceedling_`. A directory of a path
# that is itself named like one of these gains a leading `_`, so `decode` inverts `encode`
# exactly.
module BuildSubpath

  PARENT_SEGMENT    = '_up_'
  ABSOLUTE_SEGMENT  = '_abs_'
  UNC_SEGMENT       = '_unc_'
  INSTALLED_SEGMENT = '_ceedling_'

  # A segment of a path named like a marker, perhaps already led by more `_`, in any case,
  # since macOS and Windows file systems fold it
  MARKER_NAMED = /\A_+(?:up|abs|unc|ceedling)_\z/i

  # The running Ceedling installation, above lib/ceedling/filesystem/
  INSTALLATION_ROOT = File.expand_path( '../../..', __dir__ )

  # The directories of an installation holding what Ceedling ships. A project may itself sit
  # elsewhere in an installation, as in a development checkout, and its files are its own.
  INSTALLED_DIRS = %w[assets bin lib plugins vendor].map { |dir| File.join( INSTALLATION_ROOT, dir ) }.freeze

  @lock     = Mutex.new
  @subpaths = {}

  # The build subpath that places a file of `path` by its path from the project root
  def self.encode(path)
    full = ProjectPaths.absolute( path )
    rel  = ProjectPaths.relative( full )

    # Another drive, with no relative path to the project, lies outside it as a climb does
    beyond = !ProjectPaths.contains?( ProjectPaths.working_dir, full )
    return installed_segments( full ).join( '/' ) if beyond && installed?( full )
    return absolute_segments( rel ).join( '/' ) if ProjectPaths.absolute?( rel )

    return ProjectPaths.segments( rel ).map { |segment| segment == '..' ? PARENT_SEGMENT : escape( segment ) }.join( '/' )
  end

  # The path, in intake's spelling, that `encode` made `subpath` from
  def self.decode(subpath)
    segments = ProjectPaths.segments( subpath )
    rest     = unescaped( segments.drop( 1 ) )

    case segments.first
    when INSTALLED_SEGMENT then return ProjectPaths.relative( File.join( INSTALLATION_ROOT, *rest ) )
    when UNC_SEGMENT       then return "//#{rest.join( '/' )}"
    when ABSOLUTE_SEGMENT  then return "#{segments[1]}:/#{rest.drop( 1 ).join( '/' )}"
    end

    return segments.map { |segment| segment == PARENT_SEGMENT ? '..' : unescape( segment ) }.join( '/' )
  end

  # `encode` for a directory, memoized, since a build places many files from each directory.
  # The working directory itself encodes as ''.
  def self.of_directory(dir)
    key = [ProjectPaths.working_dir, dir.to_s]
    return @lock.synchronize { @subpaths[key] ||= encode( dir ) }
  end

  def self.installed?(full)
    return INSTALLED_DIRS.any? { |dir| ProjectPaths.contains?( dir, full ) }
  end

  def self.installed_segments(full)
    return [INSTALLED_SEGMENT] + ProjectPaths.segments( full[INSTALLATION_ROOT.length..] ).map { |segment| escape( segment ) }
  end

  def self.escape(segment)
    return segment.match?( MARKER_NAMED ) ? "_#{segment}" : segment
  end

  def self.unescape(segment)
    return segment.match?( MARKER_NAMED ) && segment.start_with?( '__' ) ? segment[1..] : segment
  end

  def self.unescaped(segments)
    return segments.map { |segment| unescape( segment ) }
  end

  # An absolute path's segments below `_abs_`, a drive letter as a plain segment, or below
  # `_unc_` for a share
  def self.absolute_segments(path)
    return [UNC_SEGMENT] + ProjectPaths.segments( path ).map { |segment| escape( segment ) } if ProjectPaths.unc?( path )

    parts = ProjectPaths.segments( path )
    return [ABSOLUTE_SEGMENT] + parts.each_with_index.map { |part, index| index.zero? ? part.delete_suffix( ':' ) : escape( part ) }
  end

  private_class_method :installed?, :installed_segments, :absolute_segments, :escape, :unescape, :unescaped

end
