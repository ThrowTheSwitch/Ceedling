require 'constants'
require 'set'

class PluginManager

  constructor :configurator, :plugin_manager_helper, :streaminator, :reportinator, :system_wrapper

  def setup
    @build_fail_registry = []
  end
  
  def load_plugin_scripts(script_plugins, system_objects)
    @plugin_objects = []
    
    script_plugins.each do |plugin|
      @system_wrapper.require_file( File.join(@configurator.plugins_base_path, plugin, "#{plugin}.rb") )
      @plugin_objects << @plugin_manager_helper.instantiate_plugin_script( camelize(plugin), system_objects )
    end
  end
  
  def build_failed?
    return (@build_fail_registry.size > 0)
  end
  
  def test_build?
    return @plugin_manager_helper.rake_task_invoked?(/^#{TESTS_TASKS_ROOT_NAME}:/)
  end
  
  def release_build?
    return @plugin_manager_helper.rake_task_invoked?(/^#{RELEASE_TASKS_ROOT_NAME}:/)
  end
  
  def rake_task_invoked?(task_regex)
    return @plugin_manager_helper.rake_task_invoked?(task_regex)
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
    @build_fail_registry << message
  end

  def pre_test_execute(arg_hash)
    @plugin_objects.each do |plugin|
      plugin.pre_test_execute(arg_hash)
    end    
  end
  
  def post_test_execute(arg_hash)
    @plugin_objects.each do |plugin|
      plugin.post_test_execute(arg_hash)
    end    
  end
  
  def post_build
    @plugin_objects.each do |plugin|
      plugin.post_build
    end
  end
  
  private
  
  def camelize(underscored_name)
    return underscored_name.gsub(/(_|^)([a-z0-9])/) {$2.upcase}
  end

end
