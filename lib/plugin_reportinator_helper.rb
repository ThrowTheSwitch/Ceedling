require 'constants'
require 'erb'


class PluginReportinatorHelper
  
  attr_writer :ceedling
  
  constructor :configurator, :streaminator, :yaml_wrapper, :file_wrapper, :rake_wrapper

  def rake_task_invoked?(task_regex)
    task_invoked = false
    @rake_wrapper.task_list.each do |task|
      if ((task.already_invoked) and (task.to_s =~ task_regex))
        task_invoked = true
        break
      end
    end
    return task_invoked
  end

  
  def fetch_results(test_results_path, test)
    filepath = ''

    pass_path = File.join(test_results_path, "#{test}#{@configurator.extension_testpass}")
    fail_path = File.join(test_results_path, "#{test}#{@configurator.extension_testfail}")

    if (@file_wrapper.exist?(fail_path))
      filepath = fail_path
    elsif (@file_wrapper.exist?(pass_path))
      filepath = pass_path
    else
      @streaminator.stderr_puts("Could not find test results for '#{test}' in #{test_results_path}", Verbosity::ERRORS)
      raise
    end
    
    return @yaml_wrapper.load(filepath)
  end


  def process_results(aggregate_results, results)
    aggregate_results[:successes]        << { :source => results[:source].clone, :collection => results[:successes].clone } if (results[:successes].size > 0)
    aggregate_results[:failures]         << { :source => results[:source].clone, :collection => results[:failures].clone  } if (results[:failures].size > 0)
    aggregate_results[:ignores]          << { :source => results[:source].clone, :collection => results[:ignores].clone   } if (results[:ignores].size > 0)
    aggregate_results[:stdout]           << { :source => results[:source].clone, :collection => results[:stdout].clone    } if (results[:stdout].size > 0)
    aggregate_results[:counts][:total]   += results[:counts][:total]
    aggregate_results[:counts][:passed]  += results[:counts][:passed]
    aggregate_results[:counts][:failed]  += results[:counts][:failed]
    aggregate_results[:counts][:ignored] += results[:counts][:ignored]
    aggregate_results[:counts][:stdout]  += results[:stdout].size
  end


  def run_report(stream, template, results, verbosity)
    output = ERB.new(template, 0, "%<>")
    @streaminator.stream_puts(stream, output.result(binding()), verbosity)
  end
  
end