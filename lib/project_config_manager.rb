require 'constants'


class ProjectConfigManager

  attr_reader :options_files

  constructor :yaml_wrapper, :file_wrapper


  def setup
    # only used outside this file as a place to stash a filepath
    @options_files = []
  end


  def merge_options(config_hash, option_filepath)
    @options_files << File.basename( option_filepath )
    config_hash.deep_merge( @yaml_wrapper.load( option_filepath ) )
    return config_hash
  end 
  
    
  def input_config_changed_since_last_build(path, config)
    filepath = File.join(path, "#{DEFAULT_CEEDLING_MAIN_PROJECT_FILE}")
    
    if ( (@file_wrapper.exist?(filepath)) and (!(@yaml_wrapper.load(filepath) == config)) )
      @file_wrapper.touch(filepath) # update timestamp just to be thorough
      yield filepath
    end
  end

end
