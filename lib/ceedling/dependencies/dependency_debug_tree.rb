# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'yaml'
require 'time'
require 'ceedling/exceptions'

# Manages DependencyTracker's on-disk debug tree -- a directory, separate
# from the single hash-only JSON cache file, that exists only when a debug
# tier is active (or has been at some point) and mirrors every monitored
# real path (targets and dependencies alike) as its own nested directory,
# keyed purely by that path:
#
#   <debug_root>/Users/mkarlesky/project/build/test/out/foo.o/
#     snapshot.yml    -- captured at mark_fresh time (see #write_snapshot)
#     diagnosis.yml   -- written by DependencyTracker#diagnose, target paths only
#
# A path is mirrored by stripping any leading slash and any Windows drive
# letter's colon, so it reconstructs as a relative directory tree under
# `debug_root` without colliding with `debug_root`'s own path syntax.
#
# YAML (not JSON) specifically because this tree exists for a human to
# directly browse and read, not for the tracker to parse back at speed --
# block scalars make multi-line diffs and captured content vastly more
# readable than escaped JSON strings would.
class DependencyDebugTree

  SNAPSHOT_FILENAME  = 'snapshot.yml'
  DIAGNOSIS_FILENAME = 'diagnosis.yml'

  constructor :file_wrapper, :yaml_wrapper

  # Writes a snapshot for `path` (a target or a dependency) under
  # `debug_root`. `hash` is always recorded; `meta` (target-only; a
  # dependency has no meta of its own) and content-capture keywords
  # (`content:`, or `truncated:`/`size:` when content exceeded the capture
  # size cap -- see DependencyTracker::DEBUG_FULL_CAPTURE_SIZE_CAP) are
  # included only when the caller supplies them, so a :meta-tier snapshot
  # simply omits content entirely rather than recording it as empty/nil.
  def write_snapshot(debug_root, path, hash:, meta: nil, content: nil, truncated: false, size: nil)
    snapshot = { 'path' => path, 'captured_at' => timestamp(), 'hash' => hash }
    snapshot['meta'] = meta unless meta.nil?
    snapshot['content'] = content unless content.nil?
    if truncated
      snapshot['truncated'] = true
      snapshot['size'] = size
    end

    write_yaml( File.join( path_dir( debug_root, path ), SNAPSHOT_FILENAME ), snapshot )
  end

  # Reads back a previously-written snapshot for `path`, or nil if none
  # exists, is unreadable, or fails to parse -- callers treat a nil
  # snapshot as "no baseline available to diff against," never as an error.
  def read_snapshot(debug_root, path)
    read_yaml( File.join( path_dir( debug_root, path ), SNAPSHOT_FILENAME ) )
  end

  # Writes a target's diagnosis (see DependencyTracker#diagnose) under
  # `debug_root`.
  def write_diagnosis(debug_root, target, diagnosis)
    write_yaml( File.join( path_dir( debug_root, target ), DIAGNOSIS_FILENAME ), diagnosis )
  end

  # Removes `path`'s entire debug directory (snapshot, diagnosis, everything
  # under it), if any exists. Called when the corresponding cache entry is
  # pruned (either DependencyCacheStore's load-time existence pruning, or
  # DependencyTracker#flush(prune: true)), so the debug tree doesn't outlive
  # the cache data it exists to explain. Safe to call for a path that was
  # never captured at all.
  def prune(debug_root, path)
    dir = path_dir( debug_root, path )
    @file_wrapper.rm_rf( dir ) if @file_wrapper.exist?( dir )
  end

  # The exact file path `write_snapshot`/`read_snapshot` use for `path`, and
  # likewise for `write_diagnosis`. Public so callers that need to point a
  # human at the right file (or verify one exists, e.g. in specs) use the
  # same path-mirroring logic this class does internally, rather than an
  # independent reimplementation that can silently drift out of sync with
  # it -- notably around the Windows drive-letter handling in `mirror`.
  def snapshot_file(debug_root, path)
    File.join( path_dir( debug_root, path ), SNAPSHOT_FILENAME )
  end

  def diagnosis_file(debug_root, target)
    File.join( path_dir( debug_root, target ), DIAGNOSIS_FILENAME )
  end

  ### Private ###
  private

  def path_dir(debug_root, path)
    File.join( debug_root, mirror( path ) )
  end

  def mirror(path)
    normalized = path.to_s.gsub( '\\', '/' )
    normalized = normalized.sub( /\A([A-Za-z]):/, '\1' ) # C:/foo -> C/foo (Windows drive letter)
    normalized.sub( /\A\/+/, '' )                         # /foo/bar -> foo/bar (relative under debug_root)
  end

  def timestamp
    Time.now.utc.iso8601
  end

  def write_yaml(filepath, structure)
    @file_wrapper.mkdir( @file_wrapper.dirname( filepath ) )
    @file_wrapper.write( filepath, YAML.dump( structure ) )
  end

  # Reads and parses `filepath` via the injected FileWrapper (all disk I/O
  # stays mockable) and YamlWrapper#load_string (the same Psych-version-safe
  # parsing used for the main config/cache YAML elsewhere in Ceedling) --
  # but degrades to nil rather than raising, since a missing, unreadable, or
  # corrupt debug artifact is exactly the kind of "nothing to work with"
  # condition callers already handle gracefully (no snapshot captured yet).
  def read_yaml(filepath)
    return nil unless @file_wrapper.exist?( filepath )
    @yaml_wrapper.load_string( @file_wrapper.read( filepath ), source_label: filepath )
  rescue YamlLoadException
    nil
  end

end
