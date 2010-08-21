require 'constants'

class PluginReportinator
  
  constructor :plugin_reportinator_helper, :plugin_manager, :reportinator

  
  def set_system_objects(system_objects)
    @plugin_reportinator_helper.ceedling = system_objects
  end
  
  
  def fetch_results(test_results_path, test)
    return @plugin_reportinator_helper.fetch_results(test_results_path, test)
  end


  def test_build?
    return @plugin_reportinator_helper.rake_task_invoked?(/^#{TESTS_TASKS_ROOT_NAME}:/)
  end

  
  def release_build?
    return @plugin_reportinator_helper.rake_task_invoked?(/^#{RELEASE_TASKS_ROOT_NAME}/)
  end

  
  def rake_task_invoked?(task_regex)
    return @plugin_reportinator_helper.rake_task_invoked?(task_regex)
  end

  
  def generate_banner(message)
    return @reportinator.generate_banner(message)
  end

  
  def assemble_test_results(results_path, test_list)
    aggregated_results = get_results_structure
    
    test_list.each do |test| 
      results = @plugin_reportinator_helper.fetch_results( results_path, test )
      @plugin_reportinator_helper.process_results(aggregated_results, results)
    end

    return aggregated_results
  end
  
  def run_report(stream, template, results=nil, verbosity=Verbosity::NORMAL)
    failure = ''
    failure = yield() if block_given?
  
    @plugin_manager.register_build_failure( failure )
    
    @plugin_reportinator_helper.run_report( stream, template, results, verbosity )
  end
  
  private ###############################
  
  def get_results_structure
    return {
      :successes => [],
      :failures  => [],
      :ignores   => [],
      :stdout    => [],
      :counts    => {:total => 0, :passed => 0, :failed => 0, :ignored  => 0, :stdout => 0}
      }
  end
 
end