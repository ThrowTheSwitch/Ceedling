require 'constants'
require 'set'

class PluginManager

  constructor :configurator, :plugin_manager_helper, :streaminator, :reportinator, :system_wrapper

  def setup
    @build_fail_registry = []
    @plugin_objects = [] # so we can preserve order
  end
  
  def load_plugin_scripts(script_plugins, system_objects)
    script_plugins.each do |plugin|
			next if (@plugin_manager_helper.include?(@plugin_objects, plugin))
			# build up load path in case there are ruby files in plugin directory that main ruby file wants to load
      @system_wrapper.add_load_path( File.join(@configurator.plugins_base_path, plugin ) )
      @system_wrapper.require_file( File.join(@configurator.plugins_base_path, plugin, "#{plugin}.rb") )
      
      object = @plugin_manager_helper.instantiate_plugin_script( camelize(plugin), system_objects, plugin )
      @plugin_objects << object
      
      # add plugins to hash of all system objects
      system_objects[plugin.downcase.to_sym] = object
    end
  end
  
  def build_failed?
    return (@build_fail_registry.size > 0)
  end
  
  def print_build_failures
    if (@build_fail_registry.size > 0)
      report = @reportinator.generate_banner('BUILD FAILURE SUMMARY')
      
      @build_fail_registry.each do |failure|
        report += "#{' - ' if (@build_fail_registry.size > 1)}#{failure}\n"
      end
      
      report += "\n"
      
      @streaminator.stderr_puts(report, Verbosity::ERRORS)
    end    
  end
  
  def register_build_failure(message)
    @build_fail_registry << message  if not message.empty?
  end

  #### execute all plugin methods ####

  def pre_build; execute_plugins(:pre_build); end

  def pre_mock_execute(arg_hash); execute_plugins(:pre_mock_execute, arg_hash); end
  def post_mock_execute(arg_hash); execute_plugins(:post_mock_execute, arg_hash); end

  def pre_runner_execute(arg_hash); execute_plugins(:pre_runner_execute, arg_hash); end
  def post_runner_execute(arg_hash); execute_plugins(:post_runner_execute, arg_hash); end

  def pre_compile_execute(arg_hash); execute_plugins(:pre_compile_execute, arg_hash); end
  def post_compile_execute(arg_hash); execute_plugins(:post_compile_execute, arg_hash); end

  def pre_link_execute(arg_hash); execute_plugins(:pre_link_execute, arg_hash); end
  def post_link_execute(arg_hash); execute_plugins(:post_link_execute, arg_hash); end

  def pre_test_execute(arg_hash); execute_plugins(:pre_test_execute, arg_hash); end
  def post_test_execute(arg_hash)
    # special arbitration: raw test results are printed or taken over by plugins handling the job
    @streaminator.stdout_puts(arg_hash[:tool_output]) if (@configurator.plugins_display_raw_test_results)
    execute_plugins(:post_test_execute, arg_hash)
  end
  
  def post_build; execute_plugins(:post_build); end
  
  private ####################################
  
  def camelize(underscored_name)
    return underscored_name.gsub(/(_|^)([a-z0-9])/) {$2.upcase}
  end

  def execute_plugins(method, *args)
    @plugin_objects.each {|plugin| plugin.send(method, *args) }
  end

end
