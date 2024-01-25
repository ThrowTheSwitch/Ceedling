require 'set'
require 'pathname'
require 'fileutils'
require 'ceedling/file_path_utils'
require 'ceedling/exceptions'


class FileSystemUtils
  
  constructor :file_wrapper, :stream_wrapper, :reportinator

  def setup()
    # TODO: Update Dir.pwd() to use a project root once it has been figured out
    @working_dir_path = Pathname.new( Dir.pwd() )
  end

  # Build up a path list from one or more strings or arrays of (+:/-:) simple paths & globs
  def collect_paths(walk, paths)
    # Create label for project file section 
    walk = @reportinator.generate_config_walk(walk)

    raw   = [] # All paths (with aggregation decorators and globs)
    plus  = Set.new # All real, expanded directory paths to add
    minus = Set.new # All real, expanded paths to exclude
    
    # Assemble all globs and simple paths, reforming our glob notation to ruby globs
    paths.each do |container|
      case (container)
      when String then raw << container
      when Array  then container.each {|path| raw << path }
      else
        error = "Cannot handle `#{container.class}` container at #{walk} (must be string or array)"
        raise CeedlingException.new( error )
      end
    end

    # Iterate each path possibly decorated with aggregation modifiers and/or containing glob characters
    raw.each do |path|
      dirs = [] # Working list for evaluated directory paths
    
      # Get path stripped of any +:/-: aggregation modifier
      _path = FilePathUtils.no_aggregation_decorators( path )

      if @file_wrapper.exist?( _path ) and !@file_wrapper.directory?( _path )
        # Path is a simple filepath (not a directory)
        warning = "Warning: #{walk} => '#{_path}' is a filepath and will be ignored (:paths is directory-oriented while :files is file-oriented)"
        @stream_wrapper.stderr_puts( warning )

        next # Skip to next path
      end

      # Expand paths using Ruby's Dir.glob()
      #  - A simple path will yield that path
      #  - A path glob will expand to one or more paths
      _reformed = FilePathUtils::reform_subdirectory_glob( _path )
      @file_wrapper.directory_listing( _reformed ).each do |entry|
        # For each result, add it to the working list *if* it's a directory
        dirs << entry if @file_wrapper.directory?(entry)
      end
      
      # Path did not work -- must be malformed glob or glob referencing path that does not exist.
      # An earlier validation step ensures no nonexistent simple directory paths are in these results.
      if dirs.empty?
        error = "#{walk} => '#{_path}' yielded no directories -- glob is malformed or directories do not exist"
        raise CeedlingException.new( error )
      end

      # For recursive directory glob at end of a path, collect parent directories too.
      # Our reursive glob convention includes parent directories (unlike Ruby's glob).
      if path.end_with?('/**')
        parents = []
        dirs.each {|dir| parents << File.join(dir, '..')}
        dirs += parents
      end

      # Based on aggregation modifiers, add entries to plus and minus hashes.
      # Associate full, absolute paths with glob listing results so we can later ensure logical paths equate.
      # './<path>' is logically equivalent to '<path>' but is not equivalent as strings.
      # Because plus and minus are hashes, each insertion eliminates any duplicate keys.
      dirs.each do |dir|
        abs_path = File.expand_path( dir )
        FilePathUtils.add_path?( path ) ? plus << abs_path : minus << abs_path
      end
    end

    paths = (plus - minus).to_a
    paths.map! do |path|
      (Pathname.new( path ).relative_path_from( @working_dir_path )).to_s()
    end

    return paths.sort()
  end


  # Given a file list, add to it or remove from it considering +: / -: aggregation operators
  def revise_file_list(list, revisions)
    revisions.each do |revision|
      # Include or exclude filepath or file glob to file list
      path = FilePathUtils.no_aggregation_decorators( revision )
      FilePathUtils.add_path?(revision) ? list.include(path) : list.exclude(path)
    end
  end

end
