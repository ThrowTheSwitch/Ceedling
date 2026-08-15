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


  def find_file_in_collection(filename, file_list, complain)
    found = PathMatcher.match(filename, file_list)
    return found unless found.nil?

    return not_found_in_collection(filename, file_list, complain)
  end

  # As `#find_file_in_collection`, but never raises on ambiguity -- a query matching
  # more than one file resolves to the first entry in `file_list`'s own order (which
  # already reflects real project path priority), with an ℹ️ NOTICE naming what else
  # matched so the choice isn't silent.
  def resolve_file_in_collection(filename, file_list, complain)
    found, others = PathMatcher.resolve(filename, file_list)
    return not_found_in_collection(filename, file_list, complain) if found.nil?

    unless others.empty?
      msg = "Multiple files matched '#{filename}' but chose '#{found}' by search-path priority. " \
            "Other candidates: #{others.join(', ')}. Add more path to '#{filename}' at its point " \
            "of reference to select a different file."
      @loginator.log( msg, Verbosity::COMPLAIN, LogLabels::NOTICE )
    end

    return found
  end

  def find_best_path_in_collection(pathname, path_list, complain, description)
    # search our collection for the specified exact path
    raise "No path list provided for #{description} search" if path_list.nil?
    return pathname if path_list.include?(pathname)

    # Determine the closest match by looking for matching path segments, especially paths ENDING the same
    best_match_index = 0
    best_match_value = 0
    reverse_original_pieces = pathname.split(/(?:\\|\/)/).reverse
    path_list.each_with_index do |p,i|
      reverse_match_pieces = p.split(/(?:\\|\/)/).reverse
      # 
      num = reverse_original_pieces.zip(reverse_match_pieces).inject(0){|s,v| v[0] == v[1] ? s+3 : s}
      num = reverse_original_pieces.inject(num){|s,v| reverse_match_pieces.include?(v) ? s+1 : s}
      if num > best_match_value
        best_match_index = i 
        best_match_value = num 
      end
    end

    # If none of the options were a good match, handle to the best of our ability
    if (best_match_value == 0) && (reverse_original_pieces.length > 0)
      case (complain)
        when :error
          raise CeedlingException.new( "Found no path `#{pathname}` in #{description} search paths." ) 
        when :warn
          warning = "Found no path `#{pathname}` in #{description} search paths."
          @loginator.log( warning, Verbosity::COMPLAIN )
        when :ignore 
          # nothing further to do
      end
    end

    return path_list[best_match_index]
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
  def not_found_in_collection(filename, file_list, complain)
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

end


