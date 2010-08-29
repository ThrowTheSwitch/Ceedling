
class Cacheinator

  constructor :configurator, :setupinator, :task_invoker, :yaml_wrapper
  

  def cache_project_config
    # save our test configuration to determine configuration changes upon next test run
    if (@task_invoker.test_invoked?)
      dump_project_config( @configurator.project_test_build_cache_path, @setupinator.config_hash )
    end
    
    # save our release configuration to determine configuration changes upon next release run
    if (@task_invoker.release_invoked?)
      dump_project_config( @configurator.project_release_build_cache_path, @setupinator.config_hash )
    end        
  end

  private
  
  # cache our project configuration so we can diff it later and force project rebuilds
  def dump_project_config(path, config)
    filepath = File.join(path, "#{INPUT_CONFIGURATION_CACHE_FILE}")
    @yaml_wrapper.dump( filepath, config )
  end

end
