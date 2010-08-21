require 'fileutils'
require 'constants' # for Verbosity enumeration

class FileFinderHelper

  constructor :streaminator
  
  
  def find_file_in_collection(file_name, file_list, options = {:should_complain => true})
    file_to_find = nil
    
    file_list.each do |item|
      base_file = File.basename(item)

      # case insensitive comparison
      if (base_file.casecmp(file_name) == 0)
        # case sensitive check
        if (base_file == file_name)
          file_to_find = item
          break
        else
          blow_up(file_name, " but did find filename having different capitalization: '#{item}'.")
          raise
        end
      end
      
    end
    
    blow_up(file_name) if (file_to_find.nil? and options[:should_complain])
    
    return file_to_find
  end

  def blow_up(file_name, extra_message='.')
    @streaminator.stderr_puts("ERROR: Could not find '#{file_name}'" + extra_message, Verbosity::ERRORS)
    raise
  end
  

end


