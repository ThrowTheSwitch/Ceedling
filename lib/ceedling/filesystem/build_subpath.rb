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
# installation ships, outside the project, goes under `_ceedling_`. Given a table of
# shortened roots (see BuildRoots), a path below one of them goes under the root's
# `_<name>_<hash>` marker instead, keeping its path below the root. A directory of a path
# that is itself named like any of these gains a leading `_`, so `decode` inverts `encode`
# exactly.
module BuildSubpath

  PARENT_SEGMENT    = '_up_'
  ABSOLUTE_SEGMENT  = '_abs_'
  UNC_SEGMENT       = '_unc_'
  INSTALLED_SEGMENT = '_ceedling_'

  # A segment of a path named like a marker, perhaps already led by more `_`, in any case,
  # since macOS and Windows file systems fold it
  MARKER_NAMED = /\A_+(?:up|abs|unc|ceedling)_\z/i

  # A segment of a path shaped like a shortened root's marker (see BuildRoots::MARKER),
  # perhaps already led by more `_`, in any case
  ROOT_MARKER_NAMED = /\A_+[^\/]*_[0-9a-f]{8}\z/i

  # A segment shaped like a marker itself, which only `encode` writes: escaping leads every
  # look-alike with at least two `_`. Kept in step with BuildRoots::MARKER.
  ROOT_MARKER = /\A_[^_\/][^\/]*_[0-9A-F]{8}\z/

  # The running Ceedling installation, above lib/ceedling/filesystem/
  INSTALLATION_ROOT = File.expand_path( '../../..', __dir__ )

  # The directories of an installation holding what Ceedling ships. A project may itself sit
  # elsewhere in an installation, as in a development checkout, and its files are its own.
  INSTALLED_DIRS = %w[assets bin lib plugins vendor].map { |dir| File.join( INSTALLATION_ROOT, dir ) }.freeze

  @lock     = Mutex.new
  @subpaths = {}

  # The build subpath that places a file of `path` by its path from the project root, or
  # below the marker of the shortened root in `roots` that holds it
  def self.encode(path, roots: nil)
    full = ProjectPaths.absolute( path )
    return outside_segments( full, roots ).join( '/' ) unless ProjectPaths.contains?( ProjectPaths.working_dir, full )

    root = roots&.containing( full )
    return root_segments( roots, root, full ).join( '/' ) unless root.nil?

    return relative_segments( ProjectPaths.relative( full ) ).join( '/' )
  end

  # The path, in intake's spelling, that `encode` made `subpath` from, or nil for a root
  # marker that `roots` does not hold
  def self.decode(subpath, roots: nil)
    segments = ProjectPaths.segments( subpath )
    rest     = unescaped( segments.drop( 1 ) )

    return decoded_root( roots, segments.first, rest ) if segments.first.to_s.match?( ROOT_MARKER )

    return decoded_marker( segments, rest ) || segments.map { |segment| segment == PARENT_SEGMENT ? '..' : unescape( segment ) }.join( '/' )
  end

  # `encode` for a directory, memoized per table of roots, since a build places many files
  # from each directory. The working directory itself encodes as ''.
  def self.of_directory(dir, roots: nil)
    key = [ProjectPaths.working_dir, roots&.digest, dir.to_s]
    return @lock.synchronize { @subpaths[key] ||= encode( dir, roots: roots ) }
  end

  # A path outside the project, a climb or another drive: a file Ceedling ships goes below
  # `_ceedling_`, before any root, since it is already placed briefly
  def self.outside_segments(full, roots)
    return installed_segments( full ) if installed?( full )

    root = roots&.containing( full )
    return root_segments( roots, root, full ) unless root.nil?

    return relative_segments( ProjectPaths.relative( full ) )
  end

  # A relative path's segments with each `..` as `_up_`, or an absolute one's below `_abs_`
  # or `_unc_`
  def self.relative_segments(rel)
    return absolute_segments( rel ) if ProjectPaths.absolute?( rel )

    return ProjectPaths.segments( rel ).map { |segment| segment == '..' ? PARENT_SEGMENT : escape( segment ) }
  end

  # The path a leading `_ceedling_`, `_unc_`, or `_abs_` marker stands for, or nil
  def self.decoded_marker(segments, rest)
    case segments.first
    when INSTALLED_SEGMENT then return ProjectPaths.relative( File.join( INSTALLATION_ROOT, *rest ) )
    when UNC_SEGMENT       then return "//#{rest.join( '/' )}"
    when ABSOLUTE_SEGMENT  then return "#{segments[1]}:/#{rest.drop( 1 ).join( '/' )}"
    end

    return nil
  end

  def self.installed?(full)
    return INSTALLED_DIRS.any? { |dir| ProjectPaths.contains?( dir, full ) }
  end

  def self.installed_segments(full)
    return [INSTALLED_SEGMENT] + ProjectPaths.segments( full[INSTALLATION_ROOT.length..] ).map { |segment| escape( segment ) }
  end

  def self.escape(segment)
    return marker_named?( segment ) ? "_#{segment}" : segment
  end

  def self.unescape(segment)
    return marker_named?( segment ) && segment.start_with?( '__' ) ? segment[1..] : segment
  end

  def self.marker_named?(segment)
    return segment.match?( MARKER_NAMED ) || segment.match?( ROOT_MARKER_NAMED )
  end

  # A path below a shortened root: the root's marker, then the path below the root
  def self.root_segments(roots, root, full)
    below = ProjectPaths.subdir_below( ProjectPaths.absolute( root ), full )
    return [roots.marker_for( root )] + ProjectPaths.segments( below ).map { |segment| escape( segment ) }
  end

  def self.decoded_root(roots, marker, rest)
    root = roots&.root_for( marker )
    return nil if root.nil?

    return rest.empty? ? root : File.join( root, *rest )
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

  private_class_method :installed?, :installed_segments, :absolute_segments, :escape, :unescape, :unescaped,
                       :marker_named?, :root_segments, :decoded_root, :outside_segments, :relative_segments, :decoded_marker

end
