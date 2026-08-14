# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Shared plumbing for DependencyTracker *system* specs: real FileWrapper,
# real SystemWrapper, real hashing, real JSON on a real temp directory on
# disk -- as opposed to the module's unit specs (spec/units/dependencies),
# which mock FileWrapper entirely. Only Loginator is a null-object double
# here: it never touches disk itself, and instantiating the real one drags
# in a background worker thread and $loginator global that these specs have
# no need of.

require 'fileutils'
require 'tmpdir'
require 'ceedling/file_wrapper'
require 'ceedling/system_wrapper'
require 'ceedling/yaml_wrapper'
require 'ceedling/dependencies/dependency_hasher'
require 'ceedling/dependencies/dependency_path_normalizer'
require 'ceedling/dependencies/dependency_cache_store'
require 'ceedling/dependencies/gcc_dependency_parser'
require 'ceedling/dependencies/dependency_debug_tree'
require 'ceedling/dependencies/dependency_differ'
require 'ceedling/dependencies/dependency_tracker'

module DependencyTrackerSystemHelper

  # Builds a fully real, opened DependencyTracker rooted at nothing in
  # particular -- `store_path` is the caller's responsibility, typically
  # somewhere under a per-example temp directory (see `in_temp_dir`).
  def build_dependency_tracker(store_path:, debug_tier: nil)
    loginator = double('loginator').as_null_object
    file_wrapper = FileWrapper.new({
      :loginator    => loginator,
      :verbosinator => double('verbosinator').as_null_object
    })
    system_wrapper = SystemWrapper.new

    hasher = DependencyHasher.new( { :file_wrapper => file_wrapper } )
    normalizer = DependencyPathNormalizer.new( { :file_wrapper => file_wrapper } )
    normalizer.setup()
    cache_store = DependencyCacheStore.new( { :file_wrapper => file_wrapper, :loginator => loginator } )
    gcc_parser = GccDependencyParser.new
    debug_tree = DependencyDebugTree.new( { :file_wrapper => file_wrapper, :yaml_wrapper => YamlWrapper.new } )
    differ = DependencyDiffer.new

    tracker = DependencyTracker.new(
      {
        :file_wrapper => file_wrapper,
        :system_wrapper => system_wrapper,
        :loginator => loginator,
        :dependency_hasher => hasher,
        :dependency_path_normalizer => normalizer,
        :dependency_cache_store => cache_store,
        :gcc_dependency_parser => gcc_parser,
        :dependency_debug_tree => debug_tree,
        :dependency_differ => differ
      }
    )
    tracker.setup()
    tracker.open( store_path: store_path, debug_tier: debug_tier )
    tracker
  end

  # The debug tree root DependencyTracker derives from `store_path` --
  # duplicated here (rather than reaching into the tracker's private state)
  # so specs can independently verify debug tree content lives where it's
  # expected to. Safe to duplicate: `File.dirname`/`File.basename` already
  # handle a Windows drive letter correctly on their own -- unlike mirroring
  # an arbitrary target/dependency path *into* a subdirectory (see below),
  # which is exactly the part that must not be reimplemented independently.
  def debug_root_for(store_path)
    File.join( File.dirname( store_path ), File.basename( store_path, '.*' ) + '_debug' )
  end

  # The real snapshot.yml/diagnosis.yml path for `path` under `debug_root`.
  # Deliberately delegates to a real DependencyDebugTree instead of
  # reimplementing its path-mirroring here: an independent reimplementation
  # previously drifted out of sync with DependencyDebugTree#mirror's Windows
  # drive-letter handling, producing a still-colon-containing path that's
  # invalid on Windows (`Errno::EINVAL`) even though the path the *production*
  # code actually wrote to was correct all along.
  def snapshot_path(store_path, path)
    debug_tree_for_specs.snapshot_file( debug_root_for( store_path ), path )
  end

  def diagnosis_path(store_path, target)
    debug_tree_for_specs.diagnosis_file( debug_root_for( store_path ), target )
  end

  def debug_tree_for_specs
    file_wrapper = FileWrapper.new({
      :loginator    => double('loginator').as_null_object,
      :verbosinator => double('verbosinator').as_null_object
    })
    DependencyDebugTree.new( { :file_wrapper => file_wrapper, :yaml_wrapper => YamlWrapper.new } )
  end

  # Runs `block` with a fresh, real temp directory, cleaned up afterward
  # regardless of pass/fail. Yields the directory's absolute path.
  def in_temp_dir
    dir = Dir.mktmpdir('dependency_tracker_system_spec')
    yield File.realpath( dir )
  ensure
    FileUtils.remove_entry( dir ) if dir && File.exist?( dir )
  end

  # Writes `content` (typically a heredoc) to a real file at `path`,
  # creating any parent directories first. Returns `path` for convenience.
  def write_fixture(path, content)
    FileUtils.mkdir_p( File.dirname( path ) )
    File.write( path, content )
    path
  end

  # Empirically determines (on the real, current filesystem -- not assumed
  # from RUBY_PLATFORM) whether `dir` is case-insensitive, by writing a
  # probe file and checking whether an alternate-case path resolves to it.
  # Specs that only make sense on one kind of filesystem use this to skip
  # themselves cleanly on the other, rather than asserting something that
  # isn't actually true of the machine the suite is running on.
  def filesystem_case_insensitive?(dir)
    probe = File.join( dir, 'CasingProbe.txt' )
    File.write( probe, 'probe' )
    File.exist?( File.join( dir, 'casingprobe.txt' ) )
  ensure
    File.delete( probe ) if probe && File.exist?( probe )
  end

end
