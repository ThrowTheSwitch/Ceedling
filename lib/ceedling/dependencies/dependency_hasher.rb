# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'digest'
# `Digest::SHA256` is lazily autoloaded from `digest/sha2` on first reference.
# Every call site below runs inside parallel worker threads (DependencyTracker
# is exercised from Batchinator-driven thread pools throughout the pipeline);
# if two threads race to be the first to touch `Digest::SHA256`, Ruby's C
# extension init for the digest classes can raise "Digest::Base cannot be
# directly inherited in Ruby". Loading it here, once, single-threaded, at
# require time settles the class before any worker thread can race on it.
require 'digest/sha2'
require 'json'

# Computes the two kinds of hashes DependencyTracker persists per target:
# - A content hash for a single file (the target itself, or one of its
#   dependencies), read via the injected FileWrapper so this class never
#   touches the filesystem directly and is fully mockable in specs.
# - A hash of an arbitrary, caller-supplied `meta` value (compilation flags,
#   defines, include paths, toolchain version, status booleans, etc.) after
#   canonicalizing it to a stable, order-independent representation so that
#   two logically-identical meta hashes (built in a different key/element
#   order) always hash the same.
class DependencyHasher

  HASH_ALGORITHM = 'sha256'.freeze
  DIGEST_RE = /\A[0-9a-f]{64}\z/.freeze

  constructor :file_wrapper

  # SHA-256 hex digest of a file's exact on-disk bytes.
  #
  # Read via `read_binary` rather than `read`: Ruby's default text-mode read
  # silently translates CRLF to LF on Windows but leaves it untouched on
  # Unix-like platforms, so the same file's bytes -- text or binary -- would
  # otherwise hash differently purely depending on which OS is running
  # Ceedling. Reading raw bytes on every platform keeps the hash a function of
  # the file's actual content alone.
  #
  # This intentionally hashes every file byte-for-byte, whitespace included,
  # rather than attempting any whitespace- or format-insensitive normalization
  # (e.g. collapsing indentation, trimming trailing spaces). That's a
  # deliberate choice, not an oversight:
  # - Whitespace is not reliably cosmetic. In C, the exact whitespace inside a
  #   string or character literal is program content, not formatting -- and
  #   trailing whitespace after a macro's line-continuing backslash can change
  #   whether the continuation is even recognized. In YAML, indentation *is*
  #   the syntax -- two documents differing only in whitespace can parse to
  #   different data entirely.
  # - Deciding which whitespace differences are safe to ignore requires
  #   understanding the semantics of the specific file's language -- i.e. a
  #   real parser for every format this hasher might ever see -- not a text
  #   transform. A byte hash can't be fooled by a parsing bug; a "smart"
  #   normalization can silently mask a real change.
  # - The two ways this hash can be wrong aren't equally bad: reporting a
  #   target stale when it isn't just costs a wasted rebuild, but reporting it
  #   fresh when it isn't means shipping against a build that silently doesn't
  #   reflect the source -- exactly the failure this class exists to prevent.
  #   Any normalization narrows the margin between those two outcomes in
  #   exchange for skipping some rebuilds; that trade isn't worth it here.
  def hash_of_file(path)
    Digest::SHA256.hexdigest( @file_wrapper.read_binary( path ) )
  end

  # SHA-256 hex digest of a canonicalized `meta` value, or nil for nil/empty
  # meta -- distinguishing "no meta was supplied" from "meta hashed to some
  # value" matters to callers deciding whether to store a `meta_hash` at all.
  def hash_of_meta(meta)
    return nil if meta.nil? || (meta.respond_to?(:empty?) && meta.empty?)
    Digest::SHA256.hexdigest( JSON.generate( canonicalize( meta ) ) )
  end

  # Recursively normalizes a value for stable hashing:
  # - Hash keys are stringified and sorted, so key order and Symbol-vs-String
  #   keys never change the resulting hash.
  # - Arrays are canonicalized element-wise, preserving order (element order
  #   in a flags/defines/paths list is meaningful, unlike hash key order).
  # - Everything else (String, Integer, true/false/nil, ...) passes through.
  def canonicalize(obj)
    case obj
    when Hash
      obj.map { |k, v| [k.to_s, canonicalize( v )] }.sort_by { |k, _v| k }.to_h
    when Array
      obj.map { |v| canonicalize( v ) }
    else
      obj
    end
  end

end
