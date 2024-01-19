require 'rubygems'
require 'rake' # for ext()
require 'ceedling/constants'
require 'ceedling/file_path_utils'  # for glob handling class methods


class ConfiguratorValidator
  
  constructor :config_walkinator, :file_wrapper, :stream_wrapper, :system_wrapper, :reportinator, :tool_validator

  # Walk into config hash verify existence of data at key depth
  def exists?(config, *keys)
    hash  = @config_walkinator.fetch_value( config, *keys )
    exist = !hash[:value].nil?

    if (not exist)
      # no verbosity checking since this is lowest level anyhow & verbosity checking depends on configurator
      walk = @reportinator.generate_config_walk( keys, hash[:depth] )
      @stream_wrapper.stderr_puts("ERROR: Required config file entry #{walk} does not exist.")    
    end
    
    return exist
  end

  # Walk into config hash. verify directory path(s) at given key depth
  def validate_path_list(config, *keys)
    hash = @config_walkinator.fetch_value( config, *keys )
    list = hash[:value]

    # return early if we couldn't walk into hash and find a value
    return false if (list.nil?)

    path_list = []
    exist = true
    
    case list
      when String then path_list << list
      when Array  then path_list =  list
    end
    
    path_list.each do |path|
      base_path = FilePathUtils::extract_path(path) # lop off add/subtract notation & glob specifiers
      
      if (not @file_wrapper.exist?(base_path))
        # no verbosity checking since this is lowest level anyhow & verbosity checking depends on configurator
        walk = @reportinator.generate_config_walk( keys, hash[:depth] )
        @stream_wrapper.stderr_puts("ERROR: Config path #{walk}['#{base_path}'] does not exist on disk.") 
        exist = false
      end 
    end
    
    return exist
  end

  # Simple path verification
  def validate_filepath_simple(path, *keys)
    validate_path = path
    
    if (not @file_wrapper.exist?(validate_path))
      # no verbosity checking since this is lowest level anyhow & verbosity checking depends on configurator
      walk = @reportinator.generate_config_walk( keys, keys.size )
      @stream_wrapper.stderr_puts("ERROR: Config path '#{validate_path}' associated with #{walk} does not exist on disk.") 
      return false
    end 
    
    return true
  end
 
  # Walk into config hash. verify specified file exists.
  def validate_filepath(config, *keys)
    hash     = @config_walkinator.fetch_value( config, *keys )
    filepath = hash[:value]

    # return early if we couldn't walk into hash and find a value
    return false if (filepath.nil?)

    # skip everything if we've got an argument replacement pattern
    return true if (filepath =~ TOOL_EXECUTOR_ARGUMENT_REPLACEMENT_PATTERN)
    
    if (not @file_wrapper.exist?(filepath))

      # See if we can deal with it internally.
      if GENERATED_DIR_PATH.include?(filepath)      
        # we already made this directory before let's make it again.
        FileUtils.mkdir_p File.join(File.dirname(__FILE__), filepath)
        walk = @reportinator.generate_config_walk( keys, hash[:depth] )
        @stream_wrapper.stderr_puts("WARNING: Generated filepath #{walk} => '#{filepath}' does not exist on disk. Recreating") 
 
      else
        # no verbosity checking since this is lowest level anyhow & verbosity checking depends on configurator
        walk = @reportinator.generate_config_walk( keys, hash[:depth] )
        @stream_wrapper.stderr_puts("ERROR: Config filepath #{walk} => '#{filepath}' does not exist on disk.")
        return false
      end
    end      

    return true
  end
  
  def validate_tool(config, key)
    # Get tool
    walk = [:tools, key]
    hash = @config_walkinator.fetch_value( config, *walk )

    arg_hash = {
      tool: hash[:value],
      name: @reportinator.generate_config_walk( walk ),
      extension: config[:extension][:executable],
      respect_optional: true
    }
  
    return @tool_validator.validate( **arg_hash )
  end

end
