require 'constants'


class ProjectConfigManager

  attr_reader :options_files, :release_config_changed, :test_config_changed
  attr_accessor :config_hash

  constructor :configurator, :yaml_wrapper, :file_wrapper


  def setup
    @options_files = []
    @release_config_changed = false
    @test_config_changed    = false
  end


  def merge_options(config_hash, option_filepath)
    @options_files << File.basename( option_filepath )
    config_hash.deep_merge( @yaml_wrapper.load( option_filepath ) )
    return config_hash
  end 
  
  
  def process_release_config_change
    @release_config_changed = config_changed_since_last_build?( @configurator.project_release_build_cache_path, @config_hash )
  end


  def process_test_config_change
    @test_config_changed = config_changed_since_last_build?( @configurator.project_test_build_cache_path, @config_hash )
  end

  private
    
  def config_changed_since_last_build?(path, config)
    filepath = File.join(path, "#{DEFAULT_CEEDLING_MAIN_PROJECT_FILE}")
    
    return true if ( not @file_wrapper.exist?(filepath) )
    return true if ( (@file_wrapper.exist?(filepath)) and (!(@yaml_wrapper.load(filepath) == config)) )
    return false
  end

end
