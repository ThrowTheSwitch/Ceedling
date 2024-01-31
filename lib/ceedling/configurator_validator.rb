require 'rubygems'
require 'rake' # for ext()
require 'ceedling/constants'
require 'ceedling/file_path_utils'  # for glob handling class methods


class ConfiguratorValidator
  
  constructor :config_walkinator, :file_wrapper, :streaminator, :system_wrapper, :reportinator, :tool_validator

  # Walk into config hash verify existence of data at key depth
  def exists?(config, *keys)
    hash  = @config_walkinator.fetch_value( config, *keys )
    exist = !hash[:value].nil?

    if (not exist)
      walk = @reportinator.generate_config_walk( keys, hash[:depth] )
      @streaminator.stderr_puts("ERROR: Required config file entry #{walk} does not exist.", Verbosity::ERRORS )    
    end
    
    return exist
  end

  # Walk into config hash. verify existence of path(s) at given key depth.
  # Paths are either full simple paths or a simple portion of a path up to a glob.
  def validate_path_list(config, *keys)
    exist = true
    hash = @config_walkinator.fetch_value( config, *keys )
    list = hash[:value]

    # Return early if we couldn't walk into hash and find a value
    return false if (list.nil?)
    
    list.each do |path|
      # Trim add/subtract notation & glob specifiers
      _path = FilePathUtils::no_decorators( path )

      next if _path.empty? # Path begins with or is entirely a glob, skip it

      # If (partial) path does not exist, complain
      if (not @file_wrapper.exist?( _path ))
        walk = @reportinator.generate_config_walk( keys, hash[:depth] )
        @streaminator.stderr_puts("ERROR: Config path #{walk} => '#{_path}' does not exist in the filesystem.", Verbosity::ERRORS ) 
        exist = false
      end 
    end
    
    return exist
  end


  # Validate :paths entries, exercising each entry as Ceedling directory glob (variation of Ruby glob)
  def validate_paths_entries(config, key)
    valid = true
    keys = [:paths, key]
    walk = @reportinator.generate_config_walk( keys )

    hash = @config_walkinator.fetch_value( config, *keys )
    list = hash[:value]

    # Return early if we couldn't walk into hash and find a value
    return false if (list.nil?)
    
    list.each do |path|
      dirs = [] # Working list

      # Trim add/subtract notation
      _path = FilePathUtils::no_aggregation_decorators( path )

      if @file_wrapper.exist?( _path ) and !@file_wrapper.directory?( _path )
        # Path is a simple filepath (not a directory)
        warning = "WARNING: #{walk} => '#{_path}' is a filepath and will be ignored (FYI :paths is directory-oriented while :files is file-oriented)"
        @streaminator.stderr_puts( warning, Verbosity::COMPLAIN )

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
      
      # Handle edge case of subdirectories glob but not subdirectories
      # (Containing parent directory will still exist)
      next if dirs.empty? and _path =~ /\/\*{1,2}$/

      # Path did not work -- must be malformed glob or glob referencing path that does not exist.
      # (An earlier step validates all simple directory paths).
      if dirs.empty?
        error = "ERROR: #{walk} => '#{_path}' yielded no directories -- matching glob is malformed or directories do not exist"
        @streaminator.stderr_puts( error, Verbosity::ERRORS )
        valid = false
      end
    end
    
    return valid
  end


  # Validate :files entries, exercising each entry as FileList glob
  def validate_files_entries(config, key)
    valid = true
    keys = [:files, key]
    walk = @reportinator.generate_config_walk( keys )

    hash = @config_walkinator.fetch_value( config, *keys )
    list = hash[:value]

    # Return early if we couldn't walk into hash and find a value
    return false if (list.nil?)
    
    list.each do |path|
      # Trim add/subtract notation
      _path = FilePathUtils::no_aggregation_decorators( path )

      if @file_wrapper.exist?( _path ) and @file_wrapper.directory?( _path )
        # Path is a simple directory path (and is naturally ignored by FileList without a glob pattern)
        warning = "WARNING: #{walk} => '#{_path}' is a directory path and will be ignored (FYI :files is file-oriented while :paths is directory-oriented)"
        @streaminator.stderr_puts( warning, Verbosity::COMPLAIN )

        next # Skip to next path
      end      

      filelist = @file_wrapper.instantiate_file_list(_path)

      # If file list is empty, complain
      if (filelist.size == 0)
        error = "#{walk} => 'ERROR: #{_path}' yielded no files -- matching glob is malformed or files do not exist"
        @streaminator.stderr_puts( error, Verbosity::ERRORS ) 
        valid = false
      end 
    end
    
    return valid
  end


  # Simple path verification
  def validate_filepath_simple(path, *keys)
    validate_path = path
    
    if (not @file_wrapper.exist?(validate_path))
      walk = @reportinator.generate_config_walk( keys, keys.size )
      @streaminator.stderr_puts("ERROR: Config path '#{validate_path}' associated with #{walk} does not exist in the filesystem.", Verbosity::ERRORS ) 
      return false
    end 
    
    return true
  end
   
  def validate_tool(config:, key:, respect_optional:true)
    # Get tool
    walk = [:tools, key]
    hash = @config_walkinator.fetch_value( config, *walk )

    arg_hash = {
      tool: hash[:value],
      name: @reportinator.generate_config_walk( walk ),
      extension: config[:extension][:executable],
      respect_optional: respect_optional
    }
  
    return @tool_validator.validate( **arg_hash )
  end

end
