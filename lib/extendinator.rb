require 'constants'
require 'set'

class Extendinator

  constructor :configurator, :extendinator_helper, :streaminator, :reportinator, :system_wrapper

  def setup
    @build_fail_registry = []
  end
  
  def load_extender_scripts(script_extenders, system_objects)
    @extender_objects = []
    
    script_extenders.each do |extender|
      @system_wrapper.require_file( File.join(@configurator.extenders_base_path, extender, "#{extender}.rb") )
      @extender_objects << @extendinator_helper.instantiate_extender_script( camelize(extender), system_objects )
    end
  end
  
  def build_failed?
    return (@build_fail_registry.size > 0)
  end
  
  def test_build?
    return @extendinator_helper.rake_task_invoked?(/^#{TESTS_TASKS_ROOT_NAME}:/)
  end
  
  def release_build?
    return @extendinator_helper.rake_task_invoked?(/^#{RELEASE_TASKS_ROOT_NAME}:/)
  end
  
  def rake_task_invoked?(task_regex)
    return @extendinator_helper.rake_task_invoked?(task_regex)
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
    @extender_objects.each do |extender|
      extender.pre_test_execute(arg_hash)
    end    
  end
  
  def post_test_execute(arg_hash)
    @extender_objects.each do |extender|
      extender.post_test_execute(arg_hash)
    end    
  end
  
  def post_build
    @extender_objects.each do |extender|
      extender.post_build
    end
  end
  
  private
  
  def camelize(underscored_name)
    return underscored_name.gsub(/(_|^)([a-z0-9])/) {$2.upcase}
  end

end
