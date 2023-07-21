require 'fileutils'
require 'ceedling/constants' # for Verbosity enumeration

class FileFinderHelper

  constructor :streaminator
  
  
  def find_file_in_collection(file_name, file_list, complain, original_filepath="")
    file_to_find = nil
    
    # search our collection for the specified base filename
    matches = file_list.find_all {|v| File.basename(v) == file_name }
    case matches.length 
      when 0 
        matches = file_list.find_all {|v| v =~ /(?:\\|\/|^)#{file_name}$/i}
        if (matches.length > 0)
          blow_up(file_name, "However, a filename having different capitalization was found: '#{matches[0]}'.")
        end

        case (complain)
          when :error then blow_up(file_name) 
          when :warn  then gripe(file_name)
          #when :ignore then      
        end
      when 1
        return matches[0]
      else
        # Determine the closest match by giving looking for matching path segments, especially paths ENDING the same
        best_match_index = 0
        best_match_value = 0
        reverse_original_pieces = original_filepath.split(/(?:\\|\/)/).reverse
        matches.each_with_index do |m,i|
          reverse_match_pieces = m.split(/(?:\\|\/)/).reverse
          # 
          num = reverse_original_pieces.zip(reverse_match_pieces).inject(0){|s,v| v[0] == v[1] ? s+3 : s}
          num = reverse_original_pieces.inject(num){|s,v| reverse_match_pieces.include?(v) ? s+1 : s}
          if num > best_match_value
            best_match_index = i 
            best_match_value = num 
          end
        end
        return matches[best_match_index]
    end
  end

  private
  
  def blow_up(file_name, extra_message="")
    error = "ERROR: Found no file '#{file_name}' in search paths."
    error += ' ' if (extra_message.length > 0)
    @streaminator.stderr_puts(error + extra_message, Verbosity::ERRORS)
    raise
  end
  
  def gripe(file_name, extra_message="")
    warning = "WARNING: Found no file '#{file_name}' in search paths."
    warning += ' ' if (extra_message.length > 0)
    @streaminator.stderr_puts(warning + extra_message, Verbosity::COMPLAIN)
  end

end


