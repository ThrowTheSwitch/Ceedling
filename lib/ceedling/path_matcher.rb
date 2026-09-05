# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/exceptions'

# Resolves a query -- a bare filename, a partial relative path, or a full/absolute
# path -- against a collection of full filepaths, treating however much path the
# query supplies as the thing to match, not merely a hint. A project may legitimately
# contain two files with the same name in different directories; this class is the
# one place that decides whether a given query is specific enough to mean exactly one
# of them, so no caller has to fall back on guessing.
class PathMatcher

  # The single file `query` identifies in `collection`, or nil if none does.
  # Raises a CeedlingException if `query` is insufficiently specific and more than
  # one file in `collection` matches it -- a query is never allowed to silently pick
  # a winner among genuinely ambiguous candidates.
  def self.match(query, collection)
    found = candidates(query, collection)

    case found.length
    when 0
      nil
    when 1
      found.first
    else
      raise CeedlingException.new(ambiguous_message(query, found))
    end
  end

  # As `.match`, but never raises. When more than one candidate matches, the winner
  # is simply the first entry in `collection`'s own order -- callers hand this method
  # a collection whose order already reflects real priority (e.g. a project's own
  # `:paths` configuration order, which mirrors the order a compiler's own search
  # paths would consult), so the earliest-listed candidate is the one a real build
  # would actually find first.
  #
  # Returns [winner, others] -- `winner` is the resolved file or nil; `others` is
  # every remaining candidate passed over, empty unless genuinely ambiguous, so a
  # caller can decide whether anything is worth telling the user about.
  def self.resolve(query, collection)
    found = candidates(query, collection)
    winner = found.first
    others = found[1..] || []
    return [winner, others]
  end

  # Every entry in `collection` that `query` could refer to.
  def self.candidates(query, collection)
    if absolute?(query)
      target = File.expand_path(query)
      return collection.select { |candidate| File.expand_path(candidate) == target }
    end

    query_segments = segments(query)
    collection.select { |candidate| tail_matches?(query_segments, segments(candidate)) }
  end

  # Collapses a `..` segment in `query` against `anchor`, a directory path in the
  # same representation as every other path this class handles (e.g. a test file's
  # own `File.dirname`) -- one anchor segment is popped per leading `..`, so the
  # result is an ordinary, `..`-free query ready for `.match`/`.resolve`/`.candidates`
  # exactly as if it had been written that way to begin with. A query with no `..` at
  # all is returned completely untouched, so this is a no-op for the overwhelming
  # majority of callers.
  #
  # `anchor: nil` means no file context exists to resolve against (e.g. a bare CLI
  # task name, which names no file of its own) -- a `..` there can't mean anything,
  # so it raises rather than silently mismatching or falling through to a confusing
  # "not found" further down. `anchor: ''` is different: it means the query is
  # already a complete, self-contained path that merely needs its own internal `..`
  # collapsed, not prefixed onto anything else -- the shape GCC itself produces for a
  # directory-relative quoted include, which is a full project-root-relative path
  # left uncanonicalized.
  #
  # An absolute query (including a Windows drive letter) is returned unchanged --
  # `candidates()`'s own `File.expand_path` comparison above already resolves `..`
  # correctly for those, so reprocessing one here as anchor-relative would be wrong,
  # not merely redundant.
  def self.resolve_relative(query, anchor: nil)
    return query if absolute?(query)

    query_segments = segments(query)
    return query unless query_segments.include?('..')

    if anchor.nil?
      raise CeedlingException.new(
        "Relative path reference '..' in '#{query}' has no file context to resolve against here."
      )
    end

    resolved = segments(anchor)

    query_segments.each do |segment|
      if segment == '..'
        if resolved.empty?
          raise CeedlingException.new("Relative path reference '..' in '#{query}' goes outside the project.")
        end
        resolved.pop
      else
        resolved << segment
      end
    end

    resolved.join('/')
  end

  # Two filepaths correspond if the shorter one's path segments equal the longer
  # one's own trailing segments, exactly, in order -- checked without regard for
  # which side is shorter, since a query and a candidate can each be the more
  # specific one depending on how each was discovered.
  def self.correspond?(a, b)
    segments_a = segments(a)
    segments_b = segments(b)
    shorter, longer = segments_a.length <= segments_b.length ? [segments_a, segments_b] : [segments_b, segments_a]
    tail_matches?(shorter, longer)
  end

  ### Private ###

  def self.absolute?(path)
    path.start_with?('/') || path =~ /\A[A-Za-z]:[\\\/]/
  end
  private_class_method :absolute?

  def self.segments(path)
    path.split(/[\\\/]/).reject(&:empty?)
  end
  private_class_method :segments

  # `query_segments` matches `candidate_segments` if the query's segments equal the
  # candidate's own trailing segments exactly, in order -- a bare filename (one
  # segment) matches any candidate ending in that filename; a deeper query only
  # matches a candidate whose path actually ends the same way, not merely contains
  # those segments somewhere.
  def self.tail_matches?(query_segments, candidate_segments)
    return false if query_segments.length > candidate_segments.length
    candidate_segments.last(query_segments.length) == query_segments
  end
  private_class_method :tail_matches?

  def self.ambiguous_message(query, candidates)
    "Ambiguous file reference '#{query}' found. " \
    "Include more trailing path to distinguish among: #{candidates.join(', ')}"
  end
  private_class_method :ambiguous_message

end
