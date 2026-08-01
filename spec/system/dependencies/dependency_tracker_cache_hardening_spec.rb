# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'json'
require 'digest'
require 'dependency_tracker_system_helper'
require 'ceedling/dependencies/dependency_cache_store'
require 'ceedling/dependencies/dependency_hasher'

# System-level coverage of the production-hardening design's three
# cache-file concerns, all exercised against real files on disk:
#   (A) Debug modes (Tier :none / :meta / :full)
#   (B) Cache schema versioning
#   (C) Full validation before use (malformed/corrupt cache handling)
#
# Where a scenario requires a *pre-existing* cache file with specific
# content (a wrong schema version, corrupted JSON, a hand-edited bad entry),
# that file is constructed directly as a heredoc and written to disk before
# opening a tracker against it -- simulating a cache left behind by another
# Ceedling version, an interrupted write, or manual editing.
describe 'DependencyTracker cache hardening (system)' do
  include DependencyTrackerSystemHelper

  def real_sha256(path)
    Digest::SHA256.hexdigest( File.read( path ) )
  end

  # ── (A) Debug modes ───────────────────────────────────────────────────

  context 'debug modes' do
    it 'records no debug fields at the default tier (:none)' do
      in_temp_dir do |dir|
        store_path = File.join(dir, '.dep_cache.json')
        target = write_fixture( File.join(dir, 'foo.o'), 'object bytes' )

        tracker = build_dependency_tracker( store_path: store_path )
        tracker.register( target, meta: { opt_level: 2 } )
        tracker.mark_fresh( target )
        tracker.flush

        entry = JSON.parse( File.read( store_path ) )['entries'][target]
        expect( entry ).not_to have_key('debug_tier')
        expect( entry ).not_to have_key('debug_meta')
        expect( entry ).not_to have_key('debug_files')
      end
    end

    it 'records canonicalized meta at tier :meta, without any captured file content' do
      in_temp_dir do |dir|
        store_path = File.join(dir, '.dep_cache.json')
        target = write_fixture( File.join(dir, 'foo.o'), 'object bytes' )

        tracker = build_dependency_tracker( store_path: store_path, debug_tier: :meta )
        tracker.register( target, meta: { opt_level: 2, coverage: true } )
        tracker.mark_fresh( target )
        tracker.flush

        entry = JSON.parse( File.read( store_path ) )['entries'][target]
        expect( entry['debug_tier'] ).to eq( DependencyTracker::DEBUG_TIERS[:meta] )
        expect( entry['debug_meta'] ).to eq( 'coverage' => true, 'opt_level' => 2 )
        expect( entry ).not_to have_key('debug_files')
      end
    end

    it 'additionally captures real dependency file content at tier :full' do
      in_temp_dir do |dir|
        store_path = File.join(dir, '.dep_cache.json')
        foo_h = write_fixture( File.join(dir, 'foo.h'), "#define FOO 1\n" )
        target = write_fixture( File.join(dir, 'foo.o'), 'object bytes' )

        tracker = build_dependency_tracker( store_path: store_path, debug_tier: :full )
        tracker.register( target, files: [foo_h] )
        tracker.mark_fresh( target )
        tracker.flush

        entry = JSON.parse( File.read( store_path ) )['entries'][target]
        expect( entry['debug_files'][target]['content'] ).to eq('object bytes')
        expect( entry['debug_files'][foo_h]['content'] ).to eq("#define FOO 1\n")
      end
    end

    it 'truncates (flagged, not silently dropped or fully included) an oversized real file at tier :full' do
      in_temp_dir do |dir|
        store_path = File.join(dir, '.dep_cache.json')
        huge_content = 'x' * (DependencyTracker::DEBUG_FULL_CAPTURE_SIZE_CAP + 1)
        target = write_fixture( File.join(dir, 'foo.o'), huge_content )

        tracker = build_dependency_tracker( store_path: store_path, debug_tier: :full )
        tracker.register( target, files: [] )
        tracker.mark_fresh( target )
        tracker.flush

        captured = JSON.parse( File.read( store_path ) )['entries'][target]['debug_files'][target]
        expect( captured['truncated'] ).to be(true)
        expect( captured['size'] ).to eq( huge_content.bytesize )
        expect( captured ).not_to have_key('content')
      end
    end

    it 'resolves debug tier from the real CEEDLING_DEP_DEBUG environment variable when not given explicitly' do
      in_temp_dir do |dir|
        store_path = File.join(dir, '.dep_cache.json')
        target = write_fixture( File.join(dir, 'foo.o'), 'object bytes' )

        previous = ENV['CEEDLING_DEP_DEBUG']
        ENV['CEEDLING_DEP_DEBUG'] = 'meta'
        begin
          tracker = build_dependency_tracker( store_path: store_path ) # no explicit debug_tier
          tracker.register( target, meta: { a: 1 } )
          tracker.mark_fresh( target )
          tracker.flush
        ensure
          ENV['CEEDLING_DEP_DEBUG'] = previous
        end

        entry = JSON.parse( File.read( store_path ) )['entries'][target]
        expect( entry ).to have_key('debug_meta')
      end
    end
  end

  # ── (B) Cache schema versioning ───────────────────────────────────────

  context 'cache schema versioning' do
    # A cache written by an older (or newer) Ceedling version has a
    # different `schema_version`. Even though this constructed cache file
    # is otherwise well-formed and its entry's hash genuinely matches the
    # real on-disk file, the version mismatch alone must be enough to
    # discard the entire cache -- proven by the target still reading as
    # stale after being re-registered identically.
    it 'discards an entire cache whose schema_version does not match, even if otherwise well-formed' do
      in_temp_dir do |dir|
        store_path = File.join(dir, '.dep_cache.json')
        target = write_fixture( File.join(dir, 'foo.o'), 'object bytes' )

        stale_version_cache = <<~JSON
          {
            "schema_version": #{DependencyCacheStore::CACHE_SCHEMA_VERSION - 1},
            "hash_algorithm": "#{DependencyHasher::HASH_ALGORITHM}",
            "entries": {
              "#{target}": {
                "self_hash": "#{real_sha256(target)}",
                "meta_hash": null,
                "deps": {}
              }
            }
          }
        JSON
        write_fixture( store_path, stale_version_cache )

        tracker = build_dependency_tracker( store_path: store_path )
        tracker.register( target, files: [] )

        expect( tracker.stale?( target ) ).to be(true)
      end
    end

    # Same principle, but for a mismatched hash_algorithm field rather than
    # schema_version -- the two are independent, both-checked axes.
    it 'discards an entire cache whose hash_algorithm does not match' do
      in_temp_dir do |dir|
        store_path = File.join(dir, '.dep_cache.json')
        target = write_fixture( File.join(dir, 'foo.o'), 'object bytes' )

        wrong_algorithm_cache = <<~JSON
          {
            "schema_version": #{DependencyCacheStore::CACHE_SCHEMA_VERSION},
            "hash_algorithm": "md5",
            "entries": {
              "#{target}": {
                "self_hash": "#{real_sha256(target)}",
                "meta_hash": null,
                "deps": {}
              }
            }
          }
        JSON
        write_fixture( store_path, wrong_algorithm_cache )

        tracker = build_dependency_tracker( store_path: store_path )
        tracker.register( target, files: [] )

        expect( tracker.stale?( target ) ).to be(true)
      end
    end

    it 'writes its own schema_version and hash_algorithm on flush, readable back from real disk' do
      in_temp_dir do |dir|
        store_path = File.join(dir, '.dep_cache.json')
        target = write_fixture( File.join(dir, 'foo.o'), 'object bytes' )

        tracker = build_dependency_tracker( store_path: store_path )
        tracker.register( target, files: [] )
        tracker.mark_fresh( target )
        tracker.flush

        on_disk = JSON.parse( File.read( store_path ) )
        expect( on_disk['schema_version'] ).to eq( DependencyCacheStore::CACHE_SCHEMA_VERSION )
        expect( on_disk['hash_algorithm'] ).to eq( DependencyHasher::HASH_ALGORITHM )
      end
    end
  end

  # ── (C) Full validation before use ────────────────────────────────────

  context 'validation of a pre-existing cache file' do
    # A cache file truncated mid-write (process killed, disk full) is not
    # valid JSON at all. The tracker must not crash -- it degrades to an
    # empty cache and keeps working normally for the rest of the run.
    it 'treats syntactically invalid JSON as an absent cache and continues to function normally' do
      in_temp_dir do |dir|
        store_path = File.join(dir, '.dep_cache.json')
        target = write_fixture( File.join(dir, 'foo.o'), 'object bytes' )

        write_fixture( store_path, '{ "schema_version": 1, "entries": { "trunc' ) # truncated mid-write

        tracker = build_dependency_tracker( store_path: store_path )
        tracker.register( target, files: [] )

        expect( tracker.stale?( target ) ).to be(true) # no usable prior entry
        expect { tracker.mark_fresh( target ) }.not_to raise_error
        expect( tracker.stale?( target ) ).to be(false) # tracker fully recovered and works
      end
    end

    it 'treats a syntactically valid but structurally wrong top-level JSON value (an array) as an absent cache' do
      in_temp_dir do |dir|
        store_path = File.join(dir, '.dep_cache.json')
        target = write_fixture( File.join(dir, 'foo.o'), 'object bytes' )

        write_fixture( store_path, '["not", "the", "expected", "shape"]' )

        tracker = build_dependency_tracker( store_path: store_path )
        tracker.register( target, files: [] )

        expect( tracker.stale?( target ) ).to be(true)
      end
    end

    # The asymmetric case central to design point (C): one hand-corrupted
    # entry (a self_hash that isn't even hex) must not take down entries
    # for *other* targets that are otherwise genuinely valid and genuinely
    # match real on-disk content.
    it 'drops only a malformed individual entry, keeping a separate genuinely-valid entry usable' do
      in_temp_dir do |dir|
        store_path = File.join(dir, '.dep_cache.json')
        good_target = write_fixture( File.join(dir, 'good.o'), 'good object bytes' )
        bad_target  = write_fixture( File.join(dir, 'bad.o'), 'bad object bytes' )

        mixed_cache = <<~JSON
          {
            "schema_version": #{DependencyCacheStore::CACHE_SCHEMA_VERSION},
            "hash_algorithm": "#{DependencyHasher::HASH_ALGORITHM}",
            "entries": {
              "#{good_target}": {
                "self_hash": "#{real_sha256(good_target)}",
                "meta_hash": null,
                "deps": {}
              },
              "#{bad_target}": {
                "self_hash": "not-a-hex-digest-at-all",
                "meta_hash": null,
                "deps": {}
              }
            }
          }
        JSON
        write_fixture( store_path, mixed_cache )

        tracker = build_dependency_tracker( store_path: store_path )
        tracker.register( good_target, files: [] )
        tracker.register( bad_target, files: [] )

        expect( tracker.stale?( good_target ) ).to be(false) # valid entry survived intact
        expect( tracker.stale?( bad_target ) ).to be(true)   # corrupt entry was dropped
      end
    end

    # Forward compatibility: unknown extra keys (e.g. a future schema
    # addition, or fields from a *newer* DependencyTracker within the same
    # schema_version) are tolerated rather than treated as corruption.
    it 'tolerates unknown extra keys on an otherwise-valid entry and top-level object' do
      in_temp_dir do |dir|
        store_path = File.join(dir, '.dep_cache.json')
        target = write_fixture( File.join(dir, 'foo.o'), 'object bytes' )

        forward_compatible_cache = <<~JSON
          {
            "schema_version": #{DependencyCacheStore::CACHE_SCHEMA_VERSION},
            "hash_algorithm": "#{DependencyHasher::HASH_ALGORITHM}",
            "some_future_top_level_field": "ignored",
            "entries": {
              "#{target}": {
                "self_hash": "#{real_sha256(target)}",
                "meta_hash": null,
                "deps": {},
                "some_future_entry_field": 42
              }
            }
          }
        JSON
        write_fixture( store_path, forward_compatible_cache )

        tracker = build_dependency_tracker( store_path: store_path )
        tracker.register( target, files: [] )

        expect( tracker.stale?( target ) ).to be(false)
      end
    end
  end

end
