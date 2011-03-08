require 'plugin'


class StdoutIdeTestsReport < Plugin
  
  def setup
    @result_list = []
    
    @template = %q{
      % ignored      = results[:counts][:ignored]
      % failed       = results[:counts][:failed]
      % stdout_count = results[:counts][:stdout]
      % if (ignored > 0)
      <%=@ceedling[:plugin_reportinator].generate_banner('IGNORED UNIT TEST SUMMARY')%>
      %   results[:ignores].each do |ignore|
      %     ignore[:collection].each do |item|
      <%=ignore[:source][:path]%><%=File::SEPARATOR%><%=ignore[:source][:file]%>:<%=item[:line]%>:<%=item[:test]%>
      % if (item[:message].length > 0)
      : "<%=item[:message]%>"
      % else
      <%="\n"%>
      % end
      %     end
      %   end
      
      % end
      % if (failed > 0)
      <%=@ceedling[:plugin_reportinator].generate_banner('FAILED UNIT TEST SUMMARY')%>
      %   results[:failures].each do |failure|
      %     failure[:collection].each do |item|
      <%=failure[:source][:path]%><%=File::SEPARATOR%><%=failure[:source][:file]%>:<%=item[:line]%>:<%=item[:test]%>
      % if (item[:message].length > 0)
      : "<%=item[:message]%>"
      % else
      <%="\n"%>
      % end
      %     end
      %   end
      
      % end
      % if (stdout_count > 0)
      <%=@ceedling[:plugin_reportinator].generate_banner('UNIT TEST OTHER OUTPUT')%>
      %   results[:stdout].each do |string|
      %     string[:collection].each do |item|
      <%=string[:source][:path]%><%=File::SEPARATOR%><%=string[:source][:file]%>: "<%=item%>"
      %     end
      %   end
      
      % end
      % total_string = results[:counts][:total].to_s
      % format_string = "%#{total_string.length}i"
      <%=@ceedling[:plugin_reportinator].generate_banner('OVERALL UNIT TEST SUMMARY')%>
      % if (results[:counts][:total] > 0)
      TESTED:  <%=results[:counts][:total].to_s%>
      PASSED:  <%=sprintf(format_string, results[:counts][:passed])%>
      FAILED:  <%=sprintf(format_string, failed)%>
      IGNORED: <%=sprintf(format_string, ignored)%>
      % else

      No tests executed.
      % end

      }.left_margin
  end
    
  def post_test_execute(arg_hash)
    @result_list << arg_hash[:result_file] if not @result_list.include?(arg_hash[:result_file])
  end
  
  def post_build
    return if (not @ceedling[:task_invoker].test_invoked?)

    results = @ceedling[:plugin_reportinator].assemble_test_results(@result_list)

    @ceedling[:plugin_reportinator].run_report($stdout, @template, results) do
      message = ''
      message = 'Unit test failures.' if (results[:counts][:failed] > 0)
      message
    end
  end

  def summary
    result_list = @ceedling[:file_path_utils].form_pass_results_filelist( COLLECTION_ALL_TESTS )

    # get test results for only those tests in our configuration and of those only tests with results on disk
    results = @ceedling[:plugin_reportinator].assemble_test_results(result_list, {:boom => false})

    @ceedling[:plugin_reportinator].run_report($stdout, @template, results)
  end

end