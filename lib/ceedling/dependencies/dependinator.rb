# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Ceedling-specific adapter between the build pipeline and the generic,
# application-agnostic DependencyTracker -- owns the tracker's lifecycle
# (where its cache file lives, when it's opened and flushed) so pipeline
# code only ever deals in build verbs, never cache mechanics.
class Dependinator

  CACHE_FILENAME = 'dep_cache.json'.freeze

  constructor :dependency_tracker

  # Builds the cache file path for a given pipeline identifier (:test, :release, a
  # plugin's own symbol, ...). Public and callable without an instance so any
  # caller -- a pipeline invoker, a spec, a future plugin -- can compute or inspect
  # the path an identifier resolves to. Every identifier lands in the same,
  # already-unconditionally-created directory, distinguished by filename alone, so
  # a new pipeline needs no build-path scaffolding of its own to get an isolated
  # cache -- just a unique identifier.
  def self.cache_store_path(identifier)
    File.join( PROJECT_BUILD_DEPENDENCIES_CACHE_PATH, ".#{identifier}.#{CACHE_FILENAME}" )
  end

  # `identifier` isolates one pipeline's cache from another's -- sharing a single
  # cache file between, say, test and release builds would make a full test:all
  # run's pruning flush (see `flush`) silently evict every cached release entry,
  # and vice versa, since pruning drops anything not registered in the current run.
  def open(identifier: :test)
    @dependency_tracker.open( store_path: self.class.cache_store_path( identifier ) )
  end

  def register(target, files: [], meta: {})
    @dependency_tracker.register( target, files: files, meta: meta )
  end

  def register_gcc_deps_file(filepath, meta: {})
    @dependency_tracker.register_gcc_deps_file( filepath, meta: meta )
  end

  def stale?(target)
    @dependency_tracker.stale?( target )
  end

  def mark_fresh(target)
    @dependency_tracker.mark_fresh( target )
  end

  def invalidate(target)
    @dependency_tracker.invalidate( target )
  end

  # `refresh_dependencies` is a full-run signal, set only by `test:all` (tasks_tests.rake):
  # only a run that touched every test target may safely prune cache entries
  # for targets it didn't see this time -- a partial build (a single test
  # file, `test:pattern`, `test:path`, `test:build_only`) must not.
  def flush(refresh_dependencies: false)
    @dependency_tracker.flush( prune: refresh_dependencies )
  end

end
