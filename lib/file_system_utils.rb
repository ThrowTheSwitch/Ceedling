require 'rubygems'
require 'rake'
require 'fileutils'
require 'file_path_utils.rb'


class FileSystemUtils
  
  constructor :file_wrapper

  # build up a FileList of directory paths from input of one or more strings, arrays, or filelists
  def collect_paths(*paths)
    # collection of all files & directories assembled by filelists
    all = @file_wrapper.instantiate_file_list
    
    # container for only directories
    dirs = @file_wrapper.instantiate_file_list
    
    paths.each do |paths_container|
      case (paths_container)
        when FileList then all += paths_container
        when String   then all.include(FilePathUtils::reform_glob(paths_container))
        when Array    then paths_container.each {|path| all.include(FilePathUtils::reform_glob(path))}
      end
    end

    all.each do |item|
      dirs.include(item) if @file_wrapper.directory?(item)
    end
    
    return dirs
  end

end
