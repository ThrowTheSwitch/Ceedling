# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'fileutils'
require 'ceedling/constants' # for Verbosity enumeration
require 'ceedling/exceptions'

class FileFinderHelper

  constructor :loginator
  
  
  def find_file_in_collection(filename, file_list, complain, original_filepath="")
    # Search our collection for the specified base filename
    matches = file_list.find_all {|v| File.basename(v) == filename }
    
    case matches.length 
      when 0 
        matches = file_list.find_all {|v| v =~ /(?:\\|\/|^)#{filename}$/i}
        if (matches.length > 0)
          blow_up(filename, "However, a filename having different capitalization was found: '#{matches[0]}'.")
        end

        return handle_missing_file(filename, complain)
      when 1
        return matches[0]
      else
        # Determine the closest match by looking for matching path segments, especially paths ENDING the same
        best_match_index = 0
        best_match_value = 0
        reverse_original_pieces = original_filepath.split(/(?:\\|\/)/).reverse
        matches.each_with_index do |m,i|
          reverse_match_pieces = m.split(/(?:\\|\/)/).reverse

          num = reverse_original_pieces.zip(reverse_match_pieces).inject(0){|s,v| v[0] == v[1] ? s+3 : s}
          num = reverse_original_pieces.inject(num){|s,v| reverse_match_pieces.include?(v) ? s+1 : s}
          if num > best_match_value
            best_match_index = i 
            best_match_value = num 
          end
        end
        return matches[best_match_index]
    end

    return nil
  end

  def find_best_path_in_collection(pathname, path_list, complain)
    # search our collection for the specified exact path
    raise "No path list provided for search" if path_list.nil?
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

  def blow_up(filename, extra_message="")
    error = ["Found no file `#{filename}` in search paths.", extra_message].join(' ').strip
    raise CeedlingException.new( error )
  end
    
  def gripe(filename, extra_message="")
    warning = ["Found no file `#{filename}` in search paths.", extra_message].join(' ').strip
    @loginator.log( warning + extra_message, Verbosity::COMPLAIN )
  end

end


