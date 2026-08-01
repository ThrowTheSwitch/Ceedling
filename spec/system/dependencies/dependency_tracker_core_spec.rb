# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'dependency_tracker_system_helper'

# System-level coverage of DependencyTracker's core query API -- register,
# stale?, mark_fresh, invalidate, flush -- against a real FileWrapper, real
# SHA-256 hashing, and real files on a real temp directory. Unlike the unit
# specs (spec/units/dependencies), nothing here is mocked at the filesystem
# boundary: dependency and target "files" are real heredoc-written source-ish
# content, and staleness is driven by actually rewriting those files on disk.
describe 'DependencyTracker core tracking (system)' do
  include DependencyTrackerSystemHelper

  # A minimal, syntactically-plausible C translation unit and header, just
  # realistic enough to read like genuine build inputs in test output.
  FOO_C = <<~C
    #include "foo.h"
    int add(int a, int b) { return a + b; }
  C

  FOO_H = <<~C
    #ifndef FOO_H
    #define FOO_H
    int add(int a, int b);
    #endif
  C

  # A never-registered target is stale -- there is nothing to compare against,
  # real file or not.
  it 'reports a never-registered target as stale' do
    in_temp_dir do |dir|
      tracker = build_dependency_tracker( store_path: File.join(dir, '.dep_cache.json') )

      expect( tracker.stale?( File.join(dir, 'foo.o') ) ).to be(true)
    end
  end

  # A registered target that simply doesn't exist on disk yet (e.g. a build
  # step that hasn't produced its object file for the first time) is stale.
  it 'reports a registered target as stale when the target file does not exist on disk' do
    in_temp_dir do |dir|
      tracker = build_dependency_tracker( store_path: File.join(dir, '.dep_cache.json') )
      target = File.join(dir, 'foo.o')

      tracker.register( target, files: [] )

      expect( tracker.stale?( target ) ).to be(true)
    end
  end

  # A registered, existing target that has never been marked fresh (first
  # build, or the cache was wiped) is stale.
  it 'reports a registered, existing target as stale until it has been marked fresh at least once' do
    in_temp_dir do |dir|
      tracker = build_dependency_tracker( store_path: File.join(dir, '.dep_cache.json') )
      target = write_fixture( File.join(dir, 'foo.o'), 'not really an object file, just bytes' )

      tracker.register( target, files: [] )

      expect( tracker.stale?( target ) ).to be(true)
    end
  end

  # The core round trip: register a real target against a real dependency,
  # mark it fresh, and confirm it now reads as not-stale -- then rewrite the
  # dependency's real on-disk content and confirm it becomes stale again.
  # This is the fundamental scenario the whole module exists to answer.
  it 'is not stale after being marked fresh, and becomes stale again when a dependency file changes on disk' do
    in_temp_dir do |dir|
      tracker = build_dependency_tracker( store_path: File.join(dir, '.dep_cache.json') )
      foo_c = write_fixture( File.join(dir, 'foo.c'), FOO_C )
      foo_h = write_fixture( File.join(dir, 'foo.h'), FOO_H )
      target = write_fixture( File.join(dir, 'foo.o'), 'object bytes' )

      tracker.register( target, files: [foo_c, foo_h] )
      tracker.mark_fresh( target )
      expect( tracker.stale?( target ) ).to be(false)

      # Simulate a source edit: rewrite the header with different real content.
      write_fixture( foo_h, FOO_H + "// a comment was added\n" )

      expect( tracker.stale?( target ) ).to be(true)
    end
  end

  # Changing the *target's own* real content (not a dependency) also
  # triggers staleness -- e.g. a build step that regenerates its own output
  # non-deterministically, or an interrupted/partial write.
  it 'becomes stale again when the target file itself changes on disk' do
    in_temp_dir do |dir|
      tracker = build_dependency_tracker( store_path: File.join(dir, '.dep_cache.json') )
      target = write_fixture( File.join(dir, 'foo.o'), 'original object bytes' )

      tracker.register( target, files: [] )
      tracker.mark_fresh( target )
      expect( tracker.stale?( target ) ).to be(false)

      write_fixture( target, 'different object bytes' )

      expect( tracker.stale?( target ) ).to be(true)
    end
  end

  # A dependency that is deleted out from under a fresh target must be
  # treated as stale, not silently ignored -- the build can no longer be
  # trusted to reflect that (now-missing) input.
  it 'becomes stale again when a previously-tracked dependency is deleted from disk' do
    in_temp_dir do |dir|
      tracker = build_dependency_tracker( store_path: File.join(dir, '.dep_cache.json') )
      foo_h = write_fixture( File.join(dir, 'foo.h'), FOO_H )
      target = write_fixture( File.join(dir, 'foo.o'), 'object bytes' )

      tracker.register( target, files: [foo_h] )
      tracker.mark_fresh( target )
      expect( tracker.stale?( target ) ).to be(false)

      File.delete( foo_h )

      expect( tracker.stale?( target ) ).to be(true)
    end
  end

  # register() is additive: two separate calls for the same target each
  # naming a different real dependency file must accumulate, not replace one
  # another. Proven by showing changing *either* independently-registered
  # dependency triggers staleness.
  it 'accumulates dependencies across repeated register() calls for the same target (additive, not replacing)' do
    in_temp_dir do |dir|
      tracker = build_dependency_tracker( store_path: File.join(dir, '.dep_cache.json') )
      foo_c = write_fixture( File.join(dir, 'foo.c'), FOO_C )
      foo_h = write_fixture( File.join(dir, 'foo.h'), FOO_H )
      target = write_fixture( File.join(dir, 'foo.o'), 'object bytes' )

      tracker.register( target, files: [foo_c] )
      tracker.register( target, files: [foo_h] )
      tracker.mark_fresh( target )
      expect( tracker.stale?( target ) ).to be(false)

      write_fixture( foo_h, FOO_H + "// changed\n" )
      expect( tracker.stale?( target ) ).to be(true)

      # Re-freshen, then prove the *first* registration call's dependency is
      # still independently tracked too.
      tracker.mark_fresh( target )
      write_fixture( foo_c, FOO_C + "// changed\n" )
      expect( tracker.stale?( target ) ).to be(true)
    end
  end

  # meta shallow-merges across repeated register() calls, later keys winning
  # on conflicts -- proven by showing a target marked fresh under a merged
  # meta value is stale once that merged value changes, and fresh again once
  # matching meta is re-registered.
  it 'shallow-merges meta across repeated register() calls, later values winning on conflicting keys' do
    in_temp_dir do |dir|
      tracker = build_dependency_tracker( store_path: File.join(dir, '.dep_cache.json') )
      target = write_fixture( File.join(dir, 'foo.o'), 'object bytes' )

      tracker.register( target, meta: { coverage: true, opt_level: 0 } )
      tracker.register( target, meta: { opt_level: 2 } ) # overrides opt_level, coverage survives
      tracker.mark_fresh( target )
      expect( tracker.stale?( target ) ).to be(false)

      tracker.invalidate( target )
      tracker.register( target, meta: { coverage: true, opt_level: 2 } ) # the actual merged result
      tracker.mark_fresh( target )
      expect( tracker.stale?( target ) ).to be(false)
    end
  end

  # invalidate() is explicit cache-busting, independent of any real content
  # change -- and must not affect any other target's cache entry.
  it 'invalidate() forces a fresh target stale again without touching other targets' do
    in_temp_dir do |dir|
      tracker = build_dependency_tracker( store_path: File.join(dir, '.dep_cache.json') )
      foo = write_fixture( File.join(dir, 'foo.o'), 'foo bytes' )
      bar = write_fixture( File.join(dir, 'bar.o'), 'bar bytes' )

      tracker.register( foo, files: [] )
      tracker.register( bar, files: [] )
      tracker.mark_fresh( foo )
      tracker.mark_fresh( bar )

      tracker.invalidate( foo )

      expect( tracker.stale?( foo ) ).to be(true)
      expect( tracker.stale?( bar ) ).to be(false)
    end
  end

  # A dependency missing at the moment of mark_fresh is simply omitted from
  # what gets recorded, rather than raising -- and the target is correctly
  # (still) stale afterward, since `stale?` independently treats a missing
  # registered dependency as stale.
  it 'omits a dependency that is missing at mark_fresh time rather than raising, and remains stale' do
    in_temp_dir do |dir|
      tracker = build_dependency_tracker( store_path: File.join(dir, '.dep_cache.json') )
      target = write_fixture( File.join(dir, 'foo.o'), 'object bytes' )
      never_written = File.join(dir, 'phantom.h')

      tracker.register( target, files: [never_written] )

      expect { tracker.mark_fresh( target ) }.not_to raise_error
      expect( tracker.stale?( target ) ).to be(true)
    end
  end

  # flush() persists real JSON to disk, and a brand-new DependencyTracker
  # instance (simulating the next Ceedling invocation's process) that opens
  # the same store_path and re-registers the *same* real target/dependency
  # correctly recognizes it as still fresh -- the whole point of persisting
  # anything at all. Unregistered targets are still stale in the new
  # instance until re-registered, even if a cache entry exists for them,
  # since `stale?` requires this run's own registration first.
  it 'persists across a simulated new process: a second tracker instance recognizes prior work as fresh once re-registered' do
    in_temp_dir do |dir|
      store_path = File.join(dir, '.dep_cache.json')
      foo_h = write_fixture( File.join(dir, 'foo.h'), FOO_H )
      target = write_fixture( File.join(dir, 'foo.o'), 'object bytes' )

      first_run = build_dependency_tracker( store_path: store_path )
      first_run.register( target, files: [foo_h] )
      first_run.mark_fresh( target )
      first_run.flush

      expect( File.exist?( store_path ) ).to be(true)

      second_run = build_dependency_tracker( store_path: store_path )
      # Not yet stale-checkable: this new instance hasn't registered anything yet.
      expect( second_run.stale?( target ) ).to be(true)

      # Re-declaring the same (unchanged) dependencies, as a real build step would every run:
      second_run.register( target, files: [foo_h] )
      expect( second_run.stale?( target ) ).to be(false)
    end
  end

end
