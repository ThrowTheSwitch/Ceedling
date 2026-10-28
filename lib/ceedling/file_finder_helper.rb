# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'fileutils'
require 'ceedling/constants' # for Verbosity enumeration
require 'ceedling/exceptions'
require 'ceedling/path_matcher'

class FileFinderHelper

  constructor :loginator

  def setup
    @noticed      = []
    @notice_mutex = Mutex.new
  end

  def find_file_in_collection(filename, file_list, complain)
    found = PathMatcher.match(filename, file_list)
    return found unless found.nil?

    return not_found_in_collection(filename, file_list, complain)
  end

  # As `#find_file_in_collection`, but never raises on ambiguity -- a query matching
  # more than one file resolves to the first entry in `file_list`'s own order (which
  # already reflects real project path priority), with an ℹ️ NOTICE naming what else
  # matched so the choice isn't silent. Every test that names the file makes the same
  # choice, so a build notes it once.
  def resolve_file_in_collection(filename, file_list, complain)
    found, others = PathMatcher.resolve(filename, file_list)
    return not_found_in_collection(filename, file_list, complain) if found.nil?

    unless others.empty?
      msg = "Multiple files matched '#{filename}' but chose '#{found}' by search-path priority. " \
            "Other candidates: #{others.join(', ')}. Add more path to '#{filename}' at its point " \
            "of reference to select a different file."
      first = @notice_mutex.synchronize { !@noticed.include?( msg ) && @noticed << msg }
      @loginator.log( msg, Verbosity::COMPLAIN, LogLabels::NOTICE ) if first
    end

    return found
  end

  def find_best_path_in_collection(pathname, path_list, complain, description)
    # search our collection for the specified exact path
    raise "No path list provided for #{description} search" if path_list.nil?
    return pathname if path_list.include?(pathname)

    # The closest match shares the most path segments, especially those ENDING the same. The
    # first of equally close matches wins, and the first path when none shares a segment.
    pieces = reversed_pieces( pathname )
    scores = path_list.map { |path| match_score( pieces, reversed_pieces( path ) ) }

    complain_of_no_path( "Found no path `#{pathname}` in #{description} search paths.", complain ) if scores.max.to_i.zero? and !pieces.empty?

    return path_list[best_index( scores )]
  end

  def handle_missing_file(filename, complain)
    case (complain)
      when :error then blow_up(filename) 
      when :warn
        gripe(filename)
        return nil
      when :ignore then return nil
    end

    return nil
  end

  ### Private ###

  private

  # Shared by both #find_file_in_collection and #resolve_file_in_collection: neither
  # can find any candidate at all, so the query's own basename gets one last check
  # against every list entry case-insensitively -- catches the common slip of a
  # filename typed with the wrong case before falling through to the caller's own
  # not-found handling.
  #
  # `complain` of :silent skips that check. A caller asks for silence when it can't know
  # whether the reference is even live, such as a scan of #includes that ignores #if, and
  # a later, authoritative lookup reports a real slip.
  def not_found_in_collection(filename, file_list, complain)
    return nil if complain == :silent

    matches = file_list.find_all {|v| v =~ /(?:\\|\/|^)#{Regexp.escape(filename)}$/i}
    if (matches.length > 0)
      blow_up(filename, "However, a filename having different capitalization was found: '#{matches[0]}'.")
    end

    return handle_missing_file(filename, complain)
  end

  def blow_up(filename, extra_message="")
    error = ["Found no file `#{filename}` in search paths.", extra_message].join(' ').strip
    raise CeedlingException.new( error )
  end
    
  def gripe(filename, extra_message="")
    warning = ["Found no file `#{filename}` in search paths.", extra_message].join(' ').strip
    @loginator.log( warning, Verbosity::COMPLAIN )
  end

  def reversed_pieces(path)
    return path.split( /(?:\\|\/)/ ).reverse
  end

  # Three for each trailing segment matched in place, and one for each segment found anywhere
  def match_score(pieces, candidate)
    in_place = pieces.zip( candidate ).count { |piece, other| piece == other }
    return (in_place * 3) + pieces.count { |piece| candidate.include?( piece ) }
  end

  # The first of the highest scores, or the first when none scores
  def best_index(scores)
    best = scores.max.to_i
    return best.zero? ? 0 : scores.index( best )
  end

  def complain_of_no_path(message, complain)
    raise CeedlingException.new( message ) if complain == :error

    @loginator.log( message, Verbosity::COMPLAIN ) if complain == :warn
  end

end
