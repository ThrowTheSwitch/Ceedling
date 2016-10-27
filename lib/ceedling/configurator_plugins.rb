require 'ceedling/constants'

class ConfiguratorPlugins

  constructor :stream_wrapper, :file_wrapper, :system_wrapper
  attr_reader :rake_plugins, :script_plugins

  def setup
    @rake_plugins   = []
    @script_plugins = []
  end


  def add_load_paths(config)
    plugin_paths = {}

    config[:plugins][:load_paths].each do |root|
      @system_wrapper.add_load_path( root ) if ( not @file_wrapper.directory_listing( File.join( root, '*.rb' ) ).empty? )

      config[:plugins][:enabled].each do |plugin|
        path = File.join(root, plugin, "lib")

        if ( not @file_wrapper.directory_listing( File.join( path, '*.rb' ) ).empty? )
          plugin_paths[(plugin + '_path').to_sym] = path
          @system_wrapper.add_load_path( path )
        end
      end
    end

    return plugin_paths
  end


  # gather up and return .rake filepaths that exist on-disk
  def find_rake_plugins(config)
    plugins_with_path = []

    config[:plugins][:load_paths].each do |root|
      config[:plugins][:enabled].each do |plugin|
        rake_plugin_path = File.join(root, plugin, "#{plugin}.rake")
        if (@file_wrapper.exist?(rake_plugin_path))
          plugins_with_path << rake_plugin_path
          @rake_plugins << plugin
        end
      end
    end

    return plugins_with_path
  end


  # gather up and return just names of .rb classes that exist on-disk
  def find_script_plugins(config)
    config[:plugins][:load_paths].each do |root|
      config[:plugins][:enabled].each do |plugin|
        script_plugin_path = File.join(root, plugin, "lib", "#{plugin}.rb")


        if @file_wrapper.exist?(script_plugin_path)
          @script_plugins << plugin
        end

      end
    end

    return @script_plugins
  end


  # gather up and return configuration .yml filepaths that exist on-disk
  def find_config_plugins(config)
    plugins_with_path = []

    config[:plugins][:load_paths].each do |root|
      config[:plugins][:enabled].each do |plugin|
        config_plugin_path = File.join(root, plugin, "config", "#{plugin}.yml")


        if @file_wrapper.exist?(config_plugin_path)
          plugins_with_path << config_plugin_path
        end
      end
    end

    return plugins_with_path
  end


  # gather up and return default .yml filepaths that exist on-disk
  def find_plugin_defaults(config)
    defaults_with_path = []

    config[:plugins][:load_paths].each do |root|
      config[:plugins][:enabled].each do |plugin|
        default_path = File.join(root, plugin, 'config', 'defaults.yml')

        if @file_wrapper.exist?(default_path)
          defaults_with_path << default_path
        end
      end
    end

    return defaults_with_path
  end

end
