# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'yaml'
require 'dependency_tracker_system_helper'

# System-level coverage of DependencyTracker#diagnose and its
# DependencyDebugTree/DependencyDiffer collaborators, against real files, a
# real persisted cache, and real YAML written to a real debug tree on disk
# -- the detailed, human-readable troubleshooting output requested to
# explain both the tracker's own behavior and the (eventual) main
# application's use of it: what SHA mismatched, the diff that triggered it,
# and which antecedent(s) were responsible.
describe 'DependencyTracker#diagnose (system)' do
  include DependencyTrackerSystemHelper

  def read_yaml_file(path)
    YAML.safe_load( File.read( path ) )
  end

  # A target's diagnosis.yml lives right alongside its own snapshot.yml,
  # under its mirrored path in the debug tree.
  def diagnosis_path(store_path, target)
    File.join( debug_root_for( store_path ), target.sub( /\A\/+/, '' ), 'diagnosis.yml' )
  end

  def snapshot_path(store_path, target)
    File.join( debug_root_for( store_path ), target.sub( /\A\/+/, '' ), 'snapshot.yml' )
  end

  it 'writes a real, human-readable diagnosis.yml explaining unchanged self/meta/antecedents for a fresh target' do
    in_temp_dir do |dir|
      store_path = File.join(dir, '.dep_cache.json')
      foo_h = write_fixture( File.join(dir, 'foo.h'), "#define FOO 1\n" )
      target = write_fixture( File.join(dir, 'foo.o'), 'object bytes' )

      tracker = build_dependency_tracker( store_path: store_path )
      tracker.register( target, files: [foo_h], meta: { opt_level: 2 } )
      tracker.mark_fresh( target )

      diagnosis = tracker.diagnose( target )

      expect( diagnosis['self']['changed'] ).to be(false)
      expect( diagnosis['meta']['changed'] ).to be(false)
      expect( diagnosis['antecedents'] ).to eq( [ { 'path' => foo_h, 'changed' => false } ] )

      on_disk = read_yaml_file( diagnosis_path( store_path, target ) )
      expect( on_disk ).to eq( diagnosis )
    end
  end

  it 'produces a real, readable content diff for a changed target when the prior run captured a :full snapshot' do
    in_temp_dir do |dir|
      store_path = File.join(dir, '.dep_cache.json')
      target = write_fixture( File.join(dir, 'foo.o'), "version one\nsecond line\n" )

      tracker = build_dependency_tracker( store_path: store_path, debug_tier: :full )
      tracker.register( target, files: [] )
      tracker.mark_fresh( target )

      write_fixture( target, "version TWO\nsecond line\n" )

      diagnosis = tracker.diagnose( target )

      expect( diagnosis['self']['changed'] ).to be(true)
      expect( diagnosis['self']['diff'] ).to include('version one')
      expect( diagnosis['self']['diff'] ).to include('version TWO')
      # The unchanged second line is not diff noise.
      expect( diagnosis['self']['diff'] ).not_to include('second line')

      # Confirm this is genuinely on disk, not just an in-memory return value.
      on_disk = read_yaml_file( diagnosis_path( store_path, target ) )
      expect( on_disk['self']['diff'] ).to eq( diagnosis['self']['diff'] )
    end
  end

  it 'reports why no diff is available for a changed target when no :full snapshot was ever captured' do
    in_temp_dir do |dir|
      store_path = File.join(dir, '.dep_cache.json')
      target = write_fixture( File.join(dir, 'foo.o'), 'version one' )

      tracker = build_dependency_tracker( store_path: store_path ) # tier :none
      tracker.register( target, files: [] )
      tracker.mark_fresh( target )

      write_fixture( target, 'version two' )

      diagnosis = tracker.diagnose( target )

      expect( diagnosis['self']['changed'] ).to be(true)
      expect( diagnosis['self']['reason'] ).to match(/no prior snapshot/i)
      expect( File.exist?( snapshot_path( store_path, target ) ) ).to be(false)
    end
  end

  it 'produces a real meta diff (added/removed/changed_keys) when the prior run captured a :meta snapshot' do
    in_temp_dir do |dir|
      store_path = File.join(dir, '.dep_cache.json')
      target = write_fixture( File.join(dir, 'foo.o'), 'object bytes' )

      first_run = build_dependency_tracker( store_path: store_path, debug_tier: :meta )
      first_run.register( target, meta: { opt_level: 0, coverage: true } )
      first_run.mark_fresh( target )
      first_run.flush

      # A second run (fresh instance, as a real new Ceedling invocation would
      # be): opt_level changes, mcdc is newly registered, coverage simply
      # isn't registered at all this time.
      second_run = build_dependency_tracker( store_path: store_path, debug_tier: :meta )
      second_run.register( target, meta: { opt_level: 2, mcdc: true } )

      diagnosis = second_run.diagnose( target )

      expect( diagnosis['meta']['changed'] ).to be(true)
      expect( diagnosis['meta']['changed_keys'] ).to eq( 'opt_level' => { 'old' => 0, 'new' => 2 } )
      expect( diagnosis['meta']['added'] ).to eq( 'mcdc' => true )
      expect( diagnosis['meta']['removed'] ).to eq( 'coverage' => true )
    end
  end

  it 'produces a real content diff for a changed antecedent, distinct from the target\'s own diff' do
    in_temp_dir do |dir|
      store_path = File.join(dir, '.dep_cache.json')
      foo_h = write_fixture( File.join(dir, 'foo.h'), "#define LIMIT 10\n" )
      target = write_fixture( File.join(dir, 'foo.o'), 'object bytes, unchanged' )

      tracker = build_dependency_tracker( store_path: store_path, debug_tier: :full )
      tracker.register( target, files: [foo_h] )
      tracker.mark_fresh( target )

      write_fixture( foo_h, "#define LIMIT 20\n" )

      diagnosis = tracker.diagnose( target )

      expect( diagnosis['self']['changed'] ).to be(false)
      antecedent = diagnosis['antecedents'].first
      expect( antecedent['path'] ).to eq( foo_h )
      expect( antecedent['changed'] ).to be(true)
      expect( antecedent['diff'] ).to include('LIMIT 10')
      expect( antecedent['diff'] ).to include('LIMIT 20')

      # The antecedent's own snapshot is a real, independent file on disk.
      expect( File.exist?( snapshot_path( store_path, foo_h ) ) ).to be(true)
    end
  end

  it 'flags a deleted antecedent as missing rather than attempting to diff it' do
    in_temp_dir do |dir|
      store_path = File.join(dir, '.dep_cache.json')
      foo_h = write_fixture( File.join(dir, 'foo.h'), "#define FOO 1\n" )
      target = write_fixture( File.join(dir, 'foo.o'), 'object bytes' )

      tracker = build_dependency_tracker( store_path: store_path, debug_tier: :full )
      tracker.register( target, files: [foo_h] )
      tracker.mark_fresh( target )

      File.delete( foo_h )

      antecedent = tracker.diagnose( target )['antecedents'].first
      expect( antecedent ).to eq( 'path' => foo_h, 'missing' => true )
    end
  end

  it 'reports a clear reason without raising when the target was never marked fresh' do
    in_temp_dir do |dir|
      store_path = File.join(dir, '.dep_cache.json')
      target = write_fixture( File.join(dir, 'foo.o'), 'object bytes' )

      tracker = build_dependency_tracker( store_path: store_path )
      tracker.register( target, files: [] )

      diagnosis = tracker.diagnose( target )

      expect( diagnosis['reason'] ).to match(/never marked fresh/i)
    end
  end

  # Load-time pruning (see dependency_tracker_pruning_spec.rb) also removes
  # a target's debug tree data, not just its JSON cache entry -- proven here
  # with a real :full snapshot genuinely present on disk beforehand.
  it 'removes debug tree data (not just the JSON cache entry) for a target deleted from disk by the time the cache is next opened' do
    in_temp_dir do |dir|
      store_path = File.join(dir, '.dep_cache.json')
      target = write_fixture( File.join(dir, 'doomed.o'), 'doomed object bytes' )

      first_run = build_dependency_tracker( store_path: store_path, debug_tier: :full )
      first_run.register( target, files: [] )
      first_run.mark_fresh( target )
      first_run.flush

      expect( File.exist?( snapshot_path( store_path, target ) ) ).to be(true)

      File.delete( target )

      build_dependency_tracker( store_path: store_path ) # opening alone triggers the prune

      expect( File.exist?( snapshot_path( store_path, target ) ) ).to be(false)
      expect( File.exist?( File.dirname( snapshot_path( store_path, target ) ) ) ).to be(false)
    end
  end

  # flush(prune: true) also cleans up debug tree data for a target it drops,
  # even though (unlike load-time pruning) the target's real file is
  # untouched -- it's dropped purely for not being registered this run.
  it 'removes debug tree data for a target dropped by flush(prune: true), even though its real file still exists' do
    in_temp_dir do |dir|
      store_path = File.join(dir, '.dep_cache.json')
      touched = write_fixture( File.join(dir, 'touched.o'), 'touched bytes' )
      untouched = write_fixture( File.join(dir, 'untouched.o'), 'untouched bytes' )

      first_run = build_dependency_tracker( store_path: store_path, debug_tier: :full )
      first_run.register( touched, files: [] )
      first_run.register( untouched, files: [] )
      first_run.mark_fresh( touched )
      first_run.mark_fresh( untouched )
      first_run.flush

      expect( File.exist?( snapshot_path( store_path, untouched ) ) ).to be(true)

      second_run = build_dependency_tracker( store_path: store_path )
      second_run.register( touched, files: [] )
      second_run.flush( prune: true )

      expect( File.exist?( snapshot_path( store_path, untouched ) ) ).to be(false)
      expect( File.exist?( untouched ) ).to be(true) # the real file itself is untouched
    end
  end

end
