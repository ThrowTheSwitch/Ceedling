require 'constants'

class ConfiguratorPlugins

  constructor :stream_wrapper, :file_wrapper

  def setup
    @rake_plugins   = []
    @script_plugins = []
  end


  # gather up and return .rake filepaths that exist on-disk
  def find_rake_plugins(config)
    base_path = config[:plugins][:base_path]
    
    return if base_path.empty?
    
    plugins_with_path = []
    
    config[:plugins][:enabled].each do |plugin|
      rake_plugin_path = File.join(base_path, plugin, "#{plugin}.rake")
      if (@file_wrapper.exist?(rake_plugin_path))
        plugins_with_path << rake_plugin_path
        @rake_plugins << plugin
      end
    end
    
    return plugins_with_path
  end


  # gather up and return just names of .rb classes that exist on-disk
  def find_script_plugins(config)
    base_path = config[:plugins][:base_path]
    
    return if base_path.empty?
    
    config[:plugins][:enabled].each do |plugin|
      script_plugin_path = File.join(base_path, plugin, "#{plugin}.rb")
      @script_plugins << plugin if @file_wrapper.exist?(script_plugin_path)
    end
    
    return @script_plugins 
  end
  
  
  # gather up and return .yml filepaths that exist on-disk
  def find_config_plugins(config)
    base_path = config[:plugins][:base_path]
    
    return if base_path.empty?

    plugins_with_path = []
    
    config[:plugins][:enabled].each do |plugin|
      config_plugin_path = File.join(base_path, plugin, "#{plugin}.yml")
      plugins_with_path << config_plugin_path if @file_wrapper.exist?(config_plugin_path)
    end
    
    return plugins_with_path    
  end
  
  
  def validate_plugins(enabled_plugins)
    missing_plugins = Set.new(enabled_plugins) - Set.new(@rake_plugins) - Set.new(@script_plugins)
    
    missing_plugins.each do |plugin|
      @stream_wrapper.stdout_puts.stderr_puts("ERROR: Ceedling plugin '#{plugin}' contains no rake or script entry point. (Misspelled or missing files?)")
    end
    
    raise if (missing_plugins.size > 0)
  end

end
