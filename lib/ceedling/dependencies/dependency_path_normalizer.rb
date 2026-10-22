# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Canonicalizes a path into the identity DependencyTracker uses as a cache key.
#
# Path *equality* is platform-dependent: Linux is case-sensitive (`Foo.c` and
# `foo.c` are different files); macOS (default APFS/HFS+) and Windows (NTFS)
# are case-insensitive but case-preserving (`Foo.c` and `foo.c` name the same
# file, but the filesystem remembers whichever casing created it). A target or
# dependency path can reach this code in whatever casing a caller happened to
# use (a `#include "Foo.h"` directive vs. an on-disk `foo.h`, or a path
# assembled from YAML config with inconsistent casing) -- if the cache key
# doesn't reflect the file's *actual* on-disk casing, a lookup can miss even
# though the file is genuinely the same one previously tracked.
#
# Rather than first detecting "is this filesystem case-insensitive?" as a
# separate yes/no probe, this class always attempts to recover the real
# on-disk casing for a path that exists, one directory component at a time,
# memoizing each directory's listing within this instance (a directory's
# contents don't change mid-build in the relevant sense, and this avoids
# re-listing the same directory for every path lookup that shares it). This
# is a no-op in the case-sensitive case: the exact-case entry is simply what
# the listing already contains, so resolution finds it immediately. A path
# that does not exist on disk (or a directory listing that fails, e.g. a
# permissions error) is returned expanded but otherwise unchanged -- it can't
# be case-resolved against a filesystem that can't be consulted, and callers
# already treat a nonexistent dependency as unconditionally stale.
class DependencyPathNormalizer

  constructor :file_wrapper

  def setup()
    @directory_listing_cache = {}
  end

  # Returns the canonical cache-key form of `path`: expanded to an absolute
  # path and, if it exists, resolved to its real on-disk casing.
  def normalize(path)
    expanded = @file_wrapper.get_expanded_path( path )
    return expanded unless @file_wrapper.exist?( expanded )

    real_case_path( expanded )
  end

  ### Private ###
  private

  def real_case_path(path)
    dir  = @file_wrapper.dirname( path )
    base = @file_wrapper.basename( path )

    # Reached the filesystem root -- `dirname` of the root is itself.
    return path if dir == path

    parent = real_case_path( dir )
    entries = directory_listing( parent )

    # Prefer an exact-case match over a merely case-insensitive one: on a
    # case-sensitive filesystem where two distinctly-cased entries genuinely
    # coexist (e.g. `Foo.c` and `foo.c` as two different files), the exact
    # match is unambiguously the right one -- falling back to a case-
    # insensitive match is only correct when no exact match exists at all.
    on_disk_entry = entries.find { |entry| entry == base } || entries.find { |entry| entry.casecmp?( base ) }

    on_disk_entry ? File.join( parent, on_disk_entry ) : path
  end

  def directory_listing(dir)
    @directory_listing_cache[dir] ||= begin
      @file_wrapper.directory_listing( File.join( dir, '*' ) ).map { |entry| @file_wrapper.basename( entry ) }
    rescue StandardError
      []
    end
  end

end
