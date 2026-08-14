# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'json'
require 'ceedling/constants'
require 'ceedling/dependencies/dependency_hasher'

# Loads, validates, and persists DependencyTracker's on-disk cache file.
#
# The persisted shape is a single JSON object:
#   {
#     "schema_version": 1,
#     "hash_algorithm": "sha256",
#     "entries": {
#       "<target path>": {
#         "self_hash": "<hex digest>",
#         "meta_hash": "<hex digest>" | null,
#         "deps": { "<dep path>": "<hex digest>", ... }
#       },
#       ...
#     }
#   }
#
# Loading never raises: a cache file that is missing, unreadable, malformed
# JSON, structurally wrong, schema-mismatched, or hand-edited into garbage is
# all treated as "cache absent" (an empty store, i.e. a full rebuild) --
# reading a stale/foreign/corrupt cache file is a routine, expected outcome
# (another Ceedling version, an interrupted write, manual editing), not an
# exceptional one, and misinterpreting an ambiguous cache as valid risks
# answering `stale?` *incorrectly* rather than merely rebuilding more than
# strictly necessary.
#
# A single corrupt *entry* does not invalidate the whole cache, though: only
# that one entry is dropped (that one target is simply treated as stale),
# since a schema mismatch calls every entry's shape into question but one
# malformed entry very likely reflects isolated damage.
#
# Entry pruning: an entry whose target no longer exists on disk (a deleted
# or renamed source/object file) is dropped silently on load -- this is
# routine build-tree drift, not corruption, so unlike a malformed entry it
# is not logged as a warning. This is a conservative, always-safe prune:
# it only ever removes entries for targets that are provably gone, so it
# cannot misfire under a partial build (`ceedling test:some_file.c`) the
# way pruning based on "was this target registered this run" could -- a
# target simply not touched by a partial build still exists on disk and so
# is never pruned here. Broader pruning ("no longer part of the build, but
# still present on disk") is deliberately not attempted at load time, since
# that requires knowing the current build's full target manifest -- see
# DependencyTracker#flush's `prune:` option, which the *caller* opts into
# only when it knows a run's registrations were comprehensive.
class DependencyCacheStore

  CACHE_SCHEMA_VERSION = 1 unless const_defined?(:CACHE_SCHEMA_VERSION, false)

  constructor :file_wrapper, :loginator

  # Loads and validates `store_path`, returning
  # `{ 'schema_version', 'hash_algorithm', 'entries', 'pruned' }`. `entries`
  # is always a Hash of target path => entry Hash, with any invalid or
  # deleted-target entries dropped. `pruned` is the list of target paths
  # dropped this load (malformed or deleted) -- callers use it to also clean
  # up any DependencyDebugTree data for those same targets, so the debug
  # tree doesn't outlive the cache entries it exists to explain.
  def load(store_path)
    return empty_store unless @file_wrapper.exist?( store_path )

    raw = @file_wrapper.read( store_path )
    parsed = JSON.parse( raw )

    return degrade( store_path, "does not contain a JSON object" ) unless parsed.is_a?( Hash )
    return degrade( store_path, "has an incompatible or missing schema_version" ) unless parsed['schema_version'] == CACHE_SCHEMA_VERSION
    return degrade( store_path, "has an incompatible or missing hash_algorithm" ) unless parsed['hash_algorithm'] == DependencyHasher::HASH_ALGORITHM
    return degrade( store_path, "is missing its entries object" ) unless parsed['entries'].is_a?( Hash )

    valid_entries = {}
    pruned = []
    parsed['entries'].each do |target, entry|
      if !valid_entry?( entry )
        @loginator.log(
          "Dependency cache entry for '#{target}' in #{store_path} is malformed -- dropping just that entry.",
          Verbosity::COMPLAIN, LogLabels::WARNING
        )
        pruned << target
      elsif !@file_wrapper.exist?( target )
        @loginator.log(
          "Dependency cache entry for '#{target}' in #{store_path} no longer exists on disk -- pruning it.",
          Verbosity::OBNOXIOUS, LogLabels::AUTO
        )
        pruned << target
      else
        valid_entries[target] = entry
      end
    end

    {
      'schema_version' => CACHE_SCHEMA_VERSION,
      'hash_algorithm' => DependencyHasher::HASH_ALGORITHM,
      'entries'        => valid_entries,
      'pruned'         => pruned
    }

  rescue JSON::ParserError => e
    degrade( store_path, "is not valid JSON (#{e.message})" )
  end

  # Persists `entries` (a Hash of target path => entry Hash) to `store_path`.
  # Writes to a temp file in the same directory and renames into place so a
  # reader never observes a partially-written cache file, even if two
  # Ceedling invocations somehow raced on the same project.
  def persist(store_path, entries)
    @file_wrapper.mkdir( @file_wrapper.dirname( store_path ) )

    payload = {
      'schema_version' => CACHE_SCHEMA_VERSION,
      'hash_algorithm' => DependencyHasher::HASH_ALGORITHM,
      'entries'        => entries
    }

    tmp_path = "#{store_path}.tmp.#{Process.pid}"
    @file_wrapper.write( tmp_path, JSON.pretty_generate( payload ) )
    @file_wrapper.mv( tmp_path, store_path )
  end

  ### Private ###
  private

  def empty_store
    { 'schema_version' => CACHE_SCHEMA_VERSION, 'hash_algorithm' => DependencyHasher::HASH_ALGORITHM, 'entries' => {}, 'pruned' => [] }
  end

  def degrade(store_path, reason)
    @loginator.log(
      "Dependency cache #{store_path} #{reason} -- treating it as absent (full rebuild for tracked targets).",
      Verbosity::COMPLAIN, LogLabels::WARNING
    )
    empty_store
  end

  def valid_entry?(entry)
    return false unless entry.is_a?( Hash )
    return false unless valid_digest?( entry['self_hash'] )
    return false unless entry['meta_hash'].nil? || valid_digest?( entry['meta_hash'] )
    return false unless entry['deps'].is_a?( Hash )
    entry['deps'].all? { |dep, digest| dep.is_a?( String ) && valid_digest?( digest ) }
  end

  def valid_digest?(value)
    value.is_a?( String ) && value.match?( DependencyHasher::DIGEST_RE )
  end

end
