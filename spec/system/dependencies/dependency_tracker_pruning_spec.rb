# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'json'
require 'dependency_tracker_system_helper'

# System-level coverage of DependencyTracker's two entry-pruning mechanisms,
# against real files, a real persisted cache, and a real second tracker
# instance standing in for the next Ceedling invocation's process:
#
# - Always-on, load-time pruning of entries whose target has been deleted
#   from disk (DependencyCacheStore#load) -- safe under a partial build,
#   since it only ever removes entries for targets *provably gone*.
# - Opt-in, caller-declared pruning of entries for targets simply not
#   registered this run (DependencyTracker#flush(prune: true)) -- for a
#   caller that knows this run's registrations are the complete, current
#   target set. Deliberately off by default (see the class-level comment on
#   #flush): naively pruning "not touched this run" would wipe cache
#   entries for every target a partial build (`ceedling test:some_file.c`)
#   simply didn't happen to touch.
describe 'DependencyTracker entry pruning (system)' do
  include DependencyTrackerSystemHelper

  def persisted_entries(store_path)
    JSON.parse( File.read( store_path ) )['entries']
  end

  # Load-time pruning: a target deleted from disk between one Ceedling
  # invocation and the next must not linger in the cache forever. A brand
  # new tracker instance (a real second process would look identical) opens
  # the same store_path and, without registering anything at all yet, its
  # very next flush already reflects the deleted target's entry being gone
  # -- proving the prune happened during #open's load, not needing any
  # register()/invalidate() call to trigger it.
  it 'drops a cache entry for a target deleted from disk by the time the cache is next loaded' do
    in_temp_dir do |dir|
      store_path = File.join(dir, '.dep_cache.json')
      keep = write_fixture( File.join(dir, 'keep.o'), 'kept object bytes' )
      doomed = write_fixture( File.join(dir, 'doomed.o'), 'doomed object bytes' )

      first_run = build_dependency_tracker( store_path: store_path )
      first_run.register( keep, files: [] )
      first_run.register( doomed, files: [] )
      first_run.mark_fresh( keep )
      first_run.mark_fresh( doomed )
      first_run.flush

      expect( persisted_entries(store_path).keys ).to contain_exactly( keep, doomed )

      # Simulate the target being deleted between invocations (a renamed
      # source file, a removed test, a build reconfiguration).
      File.delete( doomed )

      second_run = build_dependency_tracker( store_path: store_path )
      second_run.flush # no register() calls at all -- pruning already happened on load

      expect( persisted_entries(store_path).keys ).to eq( [keep] )
    end
  end

  # The same scenario, but proving the *behavioral* consequence, not just
  # the persisted JSON shape: re-registering the still-existing target with
  # its original real content is recognized as fresh (its valid cache entry
  # genuinely survived), independent of the deleted target's fate.
  it 'a still-existing target remains correctly recognized as fresh after a sibling target is pruned' do
    in_temp_dir do |dir|
      store_path = File.join(dir, '.dep_cache.json')
      keep = write_fixture( File.join(dir, 'keep.o'), 'kept object bytes' )
      doomed = write_fixture( File.join(dir, 'doomed.o'), 'doomed object bytes' )

      first_run = build_dependency_tracker( store_path: store_path )
      first_run.register( keep, files: [] )
      first_run.register( doomed, files: [] )
      first_run.mark_fresh( keep )
      first_run.mark_fresh( doomed )
      first_run.flush

      File.delete( doomed )

      second_run = build_dependency_tracker( store_path: store_path )
      second_run.register( keep, files: [] ) # re-declared, as a real build step would every run

      expect( second_run.stale?( keep ) ).to be(false)
    end
  end

  # Opt-in full-prune: by default (prune: false, i.e. plain #flush), a cache
  # entry for a target not registered this run survives untouched -- even
  # though the real file backing it still exists on disk. This is the
  # necessary, safe default for a partial build.
  it 'by default, keeps a cache entry for a target not registered this run, even though its real file still exists' do
    in_temp_dir do |dir|
      store_path = File.join(dir, '.dep_cache.json')
      touched = write_fixture( File.join(dir, 'touched.o'), 'touched object bytes' )
      untouched = write_fixture( File.join(dir, 'untouched.o'), 'untouched object bytes' )

      first_run = build_dependency_tracker( store_path: store_path )
      first_run.register( touched, files: [] )
      first_run.register( untouched, files: [] )
      first_run.mark_fresh( touched )
      first_run.mark_fresh( untouched )
      first_run.flush

      # A later, partial-build-style run only concerns itself with `touched`.
      second_run = build_dependency_tracker( store_path: store_path )
      second_run.register( touched, files: [] )
      second_run.flush # prune: false (default)

      expect( persisted_entries(store_path).keys ).to contain_exactly( touched, untouched )
    end
  end

  # The opt-in case: a caller that knows this run's registrations are the
  # complete, current target set passes `prune: true` -- now the untouched
  # target's entry is dropped even though its real file is still sitting
  # right there on disk (the defining difference from load-time pruning,
  # which only ever acts on targets that are provably *gone*).
  it 'prune: true drops a cache entry for a target not registered this run, regardless of whether its real file still exists' do
    in_temp_dir do |dir|
      store_path = File.join(dir, '.dep_cache.json')
      touched = write_fixture( File.join(dir, 'touched.o'), 'touched object bytes' )
      untouched = write_fixture( File.join(dir, 'untouched.o'), 'untouched object bytes' )

      first_run = build_dependency_tracker( store_path: store_path )
      first_run.register( touched, files: [] )
      first_run.register( untouched, files: [] )
      first_run.mark_fresh( touched )
      first_run.mark_fresh( untouched )
      first_run.flush

      second_run = build_dependency_tracker( store_path: store_path )
      second_run.register( touched, files: [] )
      second_run.flush( prune: true )

      expect( persisted_entries(store_path).keys ).to eq( [touched] )
      expect( File.exist?( untouched ) ).to be(true) # the real file itself is untouched -- only its cache entry was dropped
    end
  end

  # A target registered this run but not yet (re-)marked fresh this run
  # (e.g. about to be rebuilt) must survive prune: true -- pruning is keyed
  # on registration, not on a fresh mark_fresh call having already happened
  # in this same run.
  it 'prune: true keeps a target registered this run even before it has been (re-)marked fresh this run' do
    in_temp_dir do |dir|
      store_path = File.join(dir, '.dep_cache.json')
      target = write_fixture( File.join(dir, 'foo.o'), 'object bytes' )

      first_run = build_dependency_tracker( store_path: store_path )
      first_run.register( target, files: [] )
      first_run.mark_fresh( target )
      first_run.flush

      second_run = build_dependency_tracker( store_path: store_path )
      second_run.register( target, files: [] ) # registered again, as every real run would
      second_run.flush( prune: true )           # but not yet re-marked fresh this run

      expect( persisted_entries(store_path).keys ).to eq( [target] )
    end
  end

end
