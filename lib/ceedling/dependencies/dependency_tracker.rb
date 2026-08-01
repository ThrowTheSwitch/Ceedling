# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'thread'
require 'ceedling/constants'
require 'ceedling/exceptions'

# A pure query module for content-hash-based rebuild staleness -- not a build
# scheduler. Ceedling's existing Rake-based, multithreaded, conditionally-
# branching build steps already encode ordering via task prerequisites; this
# class only answers, at the moment an existing build step considers whether
# to run, "has anything this target depends on changed since it last built
# successfully?" Cascading rebuilds fall out of Ceedling's existing task
# graph, not from anything in here.
#
# Usage, once per target within a single Ceedling invocation:
#   tracker.register(target, files: [...], meta: {...})   # may be called more than once; additive
#   if tracker.stale?(target)
#     ... run the real build step ...
#     tracker.mark_fresh(target)
#   end
#   tracker.flush   # once, after all targets for this invocation are processed
#
# `meta` is an arbitrary, caller-supplied Hash folded into one canonicalized,
# hashed blob alongside the file-content hashes -- compilation/link flags,
# `-D` defines, include/search paths, toolchain version strings, and status
# booleans (coverage on/off, MC/DC on/off, release vs. debug, ...). A target
# is stale if any of: it was never registered, it doesn't exist on disk, its
# own content hash changed, its meta hash changed, any dependency's content
# hash changed, or any dependency no longer exists.
#
# Every filesystem touch goes through the injected FileWrapper (and ENV access
# through SystemWrapper), so every code path here is exercisable in specs
# without creating a single real file.
class DependencyTracker

  DEBUG_TIERS = { none: 0, meta: 1, full: 2 }.freeze

  # Tier 2 (:full) captures raw dependency file content per target, per build --
  # a single huge generated header could otherwise blow up the cache file
  # silently. Content beyond this size is recorded as truncated (with its real
  # size) rather than either silently dropped or silently included in full.
  DEBUG_FULL_CAPTURE_SIZE_CAP = 1_048_576 # 1 MiB

  constructor(
    :file_wrapper,
    :system_wrapper,
    :loginator,
    :dependency_hasher,
    :dependency_path_normalizer,
    :dependency_cache_store,
    :gcc_dependency_parser
  )

  def setup()
    @mutex = Mutex.new
    @store_path = nil
    @debug_tier = DEBUG_TIERS[:none]
    @relationships = {}
    @cache = { 'entries' => {} }
  end

  # Must be called once before any other method. Loads (and validates) any
  # existing cache at `store_path`. `debug_tier` (:none, :meta, or :full)
  # defaults to the `CEEDLING_DEP_DEBUG` environment variable when not given
  # explicitly, matching Ceedling's existing convention of environment
  # variables acting as an override for otherwise-code-driven settings (see
  # Loginator's `CEEDLING_DECORATORS` handling) -- and falls back to :none for
  # anything unset or unrecognized, since these tiers are meant to be opt-in,
  # temporary debugging aids, never a silently-active default.
  def open(store_path:, debug_tier: nil)
    @store_path = store_path
    @debug_tier = resolve_debug_tier( debug_tier )

    @mutex.synchronize do
      @relationships = {}
      @cache = @dependency_cache_store.load( @store_path )
    end
  end

  # Registers `target`'s dependency files and/or meta. Additive: calling this
  # more than once for the same target unions the file lists (deduplicated)
  # and shallow-merges the meta hashes (later calls win on conflicting keys)
  # rather than replacing the prior registration -- so a target's
  # dependencies can be accumulated incrementally across multiple calls (e.g.
  # one call for its own source file plus explicit config, another from
  # `register_gcc_deps_file`/`register_gcc_deps_string` for its discovered
  # header dependencies) without each caller needing to know and resupply
  # everything a previous caller already established.
  def register(target, files: [], meta: {})
    ensure_open!

    key = @dependency_path_normalizer.normalize( target )
    file_keys = Array( files ).map { |file| @dependency_path_normalizer.normalize( file ) }

    @mutex.synchronize do
      existing = @relationships[key] || { files: [], meta: {} }
      @relationships[key] = {
        files: (existing[:files] + file_keys).uniq,
        meta:  existing[:meta].merge( meta )
      }
    end
  end

  # Parses gcc `-M`/`-MM`/`-MMD` Makefile-dialect dependency content and
  # additively registers each target it discovers (see `register`) with its
  # parsed dependencies. `meta` is applied identically to every target found
  # in `content`.
  def register_gcc_deps_string(content, meta: {})
    ensure_open!

    @gcc_dependency_parser.parse( content ).each do |target, deps|
      register( target, files: deps, meta: meta )
    end
  end

  # As `register_gcc_deps_string`, but reads `filepath` (e.g. a `.d` file
  # produced by gcc's `-MF`) via the injected FileWrapper first.
  def register_gcc_deps_file(filepath, meta: {})
    ensure_open!
    register_gcc_deps_string( @file_wrapper.read( filepath ), meta: meta )
  end

  # Pure query -- never mutates the cache. `target` is stale if:
  # - it was never registered this run,
  # - it does not exist on disk,
  # - there is no prior cache entry for it,
  # - its own content hash no longer matches the cache entry,
  # - its meta hash no longer matches the cache entry, or
  # - any registered dependency no longer exists, or its content hash no
  #   longer matches the cache entry.
  def stale?(target)
    ensure_open!

    key = @dependency_path_normalizer.normalize( target )
    rel = @mutex.synchronize { @relationships[key] }
    return true if rel.nil?
    return true unless @file_wrapper.exist?( key )

    entry = @mutex.synchronize { @cache['entries'][key] }
    return true if entry.nil?
    return true if entry['self_hash'] != @dependency_hasher.hash_of_file( key )
    return true if entry['meta_hash'] != @dependency_hasher.hash_of_meta( rel[:meta] )

    rel[:files].each do |dep|
      return true unless @file_wrapper.exist?( dep )
      return true if entry.dig( 'deps', dep ) != @dependency_hasher.hash_of_file( dep )
    end

    false
  end

  # Records `target` (and its currently-registered dependencies and meta) as
  # fresh -- called by a build step after it successfully (re)builds `target`.
  # A dependency that doesn't currently exist is simply omitted from the
  # recorded `deps` hashes (rather than raising); the next `stale?` call
  # already treats a missing dependency as stale on its own.
  def mark_fresh(target)
    ensure_open!

    key = @dependency_path_normalizer.normalize( target )
    rel = @mutex.synchronize { @relationships[key] } || { files: [], meta: {} }

    entry = {
      'self_hash' => @dependency_hasher.hash_of_file( key ),
      'meta_hash' => @dependency_hasher.hash_of_meta( rel[:meta] ),
      'deps'      => rel[:files].each_with_object( {} ) do |dep, hashes|
        hashes[dep] = @dependency_hasher.hash_of_file( dep ) if @file_wrapper.exist?( dep )
      end
    }

    if @debug_tier >= DEBUG_TIERS[:meta]
      entry['debug_tier'] = @debug_tier
      entry['debug_meta'] = @dependency_hasher.canonicalize( rel[:meta] )
    end

    if @debug_tier >= DEBUG_TIERS[:full]
      entry['debug_files'] = capture_file_contents( (rel[:files] + [key]).uniq )
    end

    @mutex.synchronize { @cache['entries'][key] = entry }
  end

  # Explicit cache-busting: drops any cache entry for `target`, so the next
  # `stale?` call for it returns true regardless of hashes. Does not affect
  # this run's `register`ed relationships for `target`.
  def invalidate(target)
    ensure_open!
    key = @dependency_path_normalizer.normalize( target )
    @mutex.synchronize { @cache['entries'].delete( key ) }
  end

  # Persists the current cache state to `store_path`. Intended to be called
  # once per Ceedling invocation, after all targets have been processed.
  #
  # `prune: true` additionally drops any cache entry whose target was *not*
  # `register`ed at some point during this run, both from what gets
  # persisted and from in-memory state. This is opt-in and off by default
  # because it is only correct when the caller knows this run's
  # registrations represent the complete, current set of targets -- e.g. a
  # real `test:all`/`release` run, never a partial build of a single file
  # (`ceedling test:some_file.c`), which would otherwise wipe cache entries
  # for every target the partial build simply didn't touch. Contrast with
  # the always-on, always-safe pruning `DependencyCacheStore#load` already
  # does for targets provably deleted from disk, which cannot misfire this
  # way regardless of build completeness.
  def flush(prune: false)
    ensure_open!

    entries = @mutex.synchronize do
      @cache['entries'].select! { |target, _entry| @relationships.key?( target ) } if prune
      @cache['entries'].dup
    end

    @dependency_cache_store.persist( @store_path, entries )
  end

  ### Private ###
  private

  def ensure_open!
    return unless @store_path.nil?
    raise CeedlingException.new( 'DependencyTracker#open must be called before use.' )
  end

  def resolve_debug_tier(explicit)
    tier = explicit || env_debug_tier()
    DEBUG_TIERS.fetch( tier, DEBUG_TIERS[:none] )
  end

  def env_debug_tier
    value = @system_wrapper.env_get( 'CEEDLING_DEP_DEBUG' )
    return :none if value.nil? || value.strip.empty?
    value.strip.downcase.to_sym
  end

  def capture_file_contents(paths)
    paths.each_with_object( {} ) do |path, captured|
      next unless @file_wrapper.exist?( path )

      content = @file_wrapper.read( path )
      if content.bytesize > DEBUG_FULL_CAPTURE_SIZE_CAP
        captured[path] = { 'truncated' => true, 'size' => content.bytesize }
      else
        captured[path] = { 'content' => content }
      end
    end
  end

end
