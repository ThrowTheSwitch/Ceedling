require 'constants'


class ReporterTestResults
  
  constructor :reporter_test_results_helper, :configurator, :extendinator, :streaminator, :yaml_wrapper, :file_wrapper
  
  def setup
    @report_data = {
      :ignores_list  => [],
      :failures_list => [],
      :tested_count  => 0,
      :passed_count  => 0,
      :failed_count  => 0,
      :ignored_count => 0,
      }
  end

  def clear_report_data
    @report_data[:ignores_list]  = []
    @report_data[:failures_list] = []
    @report_data[:tested_count]  = 0
    @report_data[:passed_count]  = 0
    @report_data[:failed_count]  = 0
    @report_data[:ignored_count] = 0    
  end
  
  def run_report(test_results_path, test_list, failure_message='')
    
    clear_report_data # clear out data tracking in case run multiple times on different results
    
    test_list.each do |test|
      filepath = ''

      pass_path = File.join(test_results_path, "#{test}#{@configurator.extension_testpass}")
      fail_path = File.join(test_results_path, "#{test}#{@configurator.extension_testfail}")

      if (@file_wrapper.exists?(pass_path))
        filepath = pass_path
      elsif (@file_wrapper.exists?(fail_path))
        filepath = fail_path
      else
        @streaminator.stderr_puts("Could not find test results for '#{test}' in #{test_results_path}", Verbosity::ERRORS)
        raise
      end

      process_results( @yaml_wrapper.load(filepath) )
    end
    
    if ((@report_data[:failed_count] > 0) and (not failure_message.empty?))
      @extendinator.register_build_failure(failure_message)
    end
    
    @reporter_test_results_helper.print_results(@report_data)
  end

  private
  
  def process_results(results)
    @report_data[:tested_count]  += results[:counts][:total]
    @report_data[:passed_count]  += results[:counts][:passed]
    @report_data[:failed_count]  += results[:counts][:failed]
    @report_data[:ignored_count] += results[:counts][:ignored]
    
    results[:messages][:ignores].each do |ignore_msg|
      @report_data[:ignores_list] << "#{results[:source][:file]}:#{ignore_msg}"
    end

    results[:messages][:failures].each do |fail_msg|
      @report_data[:failures_list] << "#{results[:source][:file]}:#{fail_msg}"
    end
  end
  
end