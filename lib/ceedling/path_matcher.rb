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

  # Every entry in `collection` that `query` could refer to.
  def self.candidates(query, collection)
    if absolute?(query)
      target = File.expand_path(query)
      return collection.select { |candidate| File.expand_path(candidate) == target }
    end

    query_segments = segments(query)
    collection.select { |candidate| tail_matches?(query_segments, segments(candidate)) }
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
