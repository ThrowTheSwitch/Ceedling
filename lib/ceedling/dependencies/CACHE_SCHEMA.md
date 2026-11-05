# Dependency Cache Schema Versions

This file records each version of the delta build dependency cache's schema: what a
cache of that version holds, and why the version was raised. The version is
`DependencyCacheStore::CACHE_SCHEMA_VERSION` (`dependency_cache_store.rb`). Add a
section here whenever it changes.

## When the version changes

The version changes in either of two cases:

- **The file's shape changes.** A field is added, removed, renamed, or reinterpreted in a
  way an older Ceedling would misread.
- **The build layout changes.** Cache keys are build paths, so a release that moves where
  a build puts its output changes the version even when the file's shape is unchanged.
  Otherwise an old entry could vouch for a path that now holds a different target's
  output.

An optional field an older reader safely ignores needs no new version.

## How a version is read

`DependencyCacheStore#load` compares a cache's `schema_version` with the current one:

- **Equal.** The cache is used. Malformed entries and entries whose target is gone are
  dropped one at a time.
- **Earlier**, from 1 up to the current version minus 1. The cache comes from an earlier
  build layout. It is set aside, and the first build rebuilds everything once. A notice
  advises `ceedling clobber` to remove output the old layout left on disk, which gcov
  reports would otherwise still read.
- **Anything else**, missing or newer. The cache is treated as absent, with a warning,
  and the build rebuilds everything.

## The cache file

Each pipeline, such as test or release, has its own cache file,
`<build_root>/cache/.<identifier>.dep_cache.json`. It is one JSON object:

```json
{
  "schema_version": 3,
  "hash_algorithm": "sha256",
  "entries": {
    "<target path>": {
      "self_hash": "<hex digest>",
      "meta_hash": "<hex digest> or null",
      "deps":      { "<dependency path>": "<hex digest>" },
      "outputs":   { "<output path>": "<hex digest>" }
    }
  }
}
```

- **`hash_algorithm`** names the digest every hash uses. A cache with another algorithm
  is treated as absent.
- **`entries`** maps each tracked target's absolute, real-cased path to what its last
  fresh build saw:
  - `self_hash`, the target's own content;
  - `meta_hash`, the hash of the target's build inputs that aren't files, such as a tool's
    command line, or null;
  - `deps`, each dependency file's content hash;
  - `outputs`, present only for a step that produces files a later run trusts, each
    output's content hash.

## Versions

### 3: shortened build roots (1.2.3)

**Contents:** unchanged from version 2.

**Why:** the build layout changed. A build file below a long configured `:paths` root
moved below the root's short `_<name>_<hash>` marker, in place of the root's whole
location and any `_up_` climb to it (#1387). Keys naming the old paths name places no
build reads any more.

### 2: placement by project path (1.2.2)

**Contents:** unchanged from version 1.

**Why:** the build layout changed. Each test's output moved below the test's path from the
project root. Each object, preprocessed file, and dependencies file moved below its
source's path from the project root, with `_up_`, `_abs_`, `_unc_`, and `_ceedling_` for
paths outside it. A different test's new name could reuse an old directory, so no old
entry could be trusted.

### 1: the first cache (1.2.0)

**Contents:** `schema_version`, `hash_algorithm`, and `entries` with `self_hash`,
`meta_hash`, and `deps`. `outputs` was added during the 1.2.0 prereleases, before 1.2.0
shipped, as an optional field older readers ignore, so it needed no new version.

**Why:** content-hash tracking replaced timestamp-based rebuild decisions.
