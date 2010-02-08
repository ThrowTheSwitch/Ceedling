require 'fileutils'
require 'verbosinator' # for Verbosity enumeration

class FileFinderHelper

  constructor :streaminator, :file_wrapper

  
  def find_file_on_disk(file_name, search_paths, hash = {:should_complain => true})
    file_to_find = ''
    search_paths.each do |path|
      file_to_find = File.join(path, file_name)
      break if @file_wrapper.exist?(file_to_find)
      file_to_find = ''
    end
    blow_up(file_name) if (file_to_find.empty? and hash[:should_complain])
    return file_to_find
  end

  def find_file_in_collection(file_name, file_list, hash = {:should_complain => true})
    file_to_find = ''
    file_list.each do |item|
      base_file = File.basename(item)
      # casw insensitive comparison
      if (base_file.casecmp(file_name) == 0)
        # case sensitive check
        if (base_file == file_name)
          file_to_find = item
          break
        else
          @streaminator.stderr_puts("ERROR: Could not find '#{file_name}' but did find file having different capitalization ('#{base_file}').", Verbosity::ERRORS)
          raise
        end
      end
    end
    blow_up(file_name) if (file_to_find.empty? and hash[:should_complain])
    return file_to_find
  end

  private ###########################
  
  def blow_up(file_name)
    @streaminator.stderr_puts("ERROR: Could not find '#{file_name}'.", Verbosity::ERRORS)
    raise
  end

end


