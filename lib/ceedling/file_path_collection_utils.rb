require 'set'
require 'pathname'
require 'fileutils'
require 'rake'
require 'ceedling/file_path_utils'
require 'ceedling/exceptions'


class FilePathCollectionUtils
  
  constructor :file_wrapper

  def setup()
    # TODO: Update Dir.pwd() to use a project root once it has been figured out
    @working_dir_path = Pathname.new( Dir.pwd() )
  end


  # Build up a directory path list from one or more strings or arrays of (+:/-:) simple paths & globs
  def collect_paths(paths)
    plus  = Set.new # All real, expanded directory paths to add
    minus = Set.new # All real, expanded paths to exclude
    
    # Iterate each path possibly decorated with aggregation modifiers and/or containing glob characters
    paths.each do |path|
      dirs = [] # Working list for evaluated directory paths
    
      # Get path stripped of any +:/-: aggregation modifier
      _path = FilePathUtils.no_aggregation_decorators( path )

      # If it's a glob, modify it for Ceedling's recursive subdirectory convention
      _reformed = FilePathUtils::reform_subdirectory_glob( _path )

      # Expand paths using Ruby's Dir.glob()
      #  - A simple path will yield that path
      #  - A path glob will expand to one or more paths
      @file_wrapper.directory_listing( _reformed ).each do |entry|
        # For each result, add it to the working list *only* if it's a directory
        # Previous validation has already made warnings about filepaths in the list
        dirs << entry if @file_wrapper.directory?(entry)
      end
      
      # For recursive directory glob at end of a path, collect parent directories too.
      # Ceedling's recursive glob convention includes parent directories (unlike Ruby's glob).
      if path.end_with?('/**')
        parents = []
        dirs.each {|dir| parents << File.join(dir, '..')}
        dirs += parents
      end

      # Based on aggregation modifiers, add entries to plus and minus sets.
      # Use full, absolute paths to ensure logical paths are compared.
      # './<path>' is logically equivalent to '<path>' but is not equivalent as strings.
      # Because plus and minus are sets, each insertion eliminates any duplicates
      # (such as parents added above).
      dirs.each do |dir|
        abs_path = File.expand_path( dir )
        if FilePathUtils.add_path?( path )
          plus << abs_path
        else
          minus << abs_path
        end
      end
    end

    # Use Set subtraction operator to remove any excluded paths
    paths = (plus - minus).to_a

    paths.map! do |path|
      # Reform path from full absolute to nice, neat relative path instead
      (Pathname.new( path ).relative_path_from( @working_dir_path )).to_s()
    end

    return paths.sort()
  end


  # Given a file list, add to it or remove from it considering (+:/-:) aggregation operators
  def revise_filelist(list, revisions)
    revisions.each do |revision|
      # Include or exclude revision in file list
      path = FilePathUtils.no_aggregation_decorators( revision )
      
      if FilePathUtils.add_path?( revision )
        list.include(path)
      else
        list.exclude(path)
      end
    end
  end

end
