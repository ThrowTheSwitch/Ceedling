require 'plugin'
require 'defaults'

class StdoutPrettyTestsReport < Plugin
  
  def setup
    @result_list = []
    
    template = %q{
      % ignored      = hash[:results][:counts][:ignored]
      % failed       = hash[:results][:counts][:failed]
      % stdout_count = hash[:results][:counts][:stdout]
      % header_prepend = ((hash[:header].length > 0) ? "#{hash[:header]}: " : '')
      % banner_width   = 25 + header_prepend.length # widest message
      
      % if (ignored > 0)
      <%=@ceedling[:plugin_reportinator].generate_banner(header_prepend + 'IGNORED UNIT TEST SUMMARY')%>
      %   hash[:results][:ignores].each do |ignore|
      [<%=ignore[:source][:file]%>]
      %     ignore[:collection].each do |item|
        Test: <%=item[:test]%>
      % if (not item[:message].empty?)
        At line (<%=item[:line]%>): "<%=item[:message]%>"
      % else
        At line (<%=item[:line]%>)
      % end

      %     end
      %   end
      % end
      % if (failed > 0)
      <%=@ceedling[:plugin_reportinator].generate_banner(header_prepend + 'FAILED UNIT TEST SUMMARY')%>
      %   hash[:results][:failures].each do |failure|
      [<%=failure[:source][:file]%>]
      %     failure[:collection].each do |item|
        Test: <%=item[:test]%>
      % if (not item[:message].empty?)
        At line (<%=item[:line]%>): "<%=item[:message]%>"
      % else
        At line (<%=item[:line]%>)
      % end

      %     end
      %   end
      % end
      % if (stdout_count > 0)
      <%=@ceedling[:plugin_reportinator].generate_banner(header_prepend + 'UNIT TEST OTHER OUTPUT')%>
      %   hash[:results][:stdout].each do |string|
      [<%=string[:source][:file]%>]
      %     string[:collection].each do |item|
        - "<%=item%>"
      %     end

      %   end
      % end
      % total_string = hash[:results][:counts][:total].to_s
      % format_string = "%#{total_string.length}i"
      <%=@ceedling[:plugin_reportinator].generate_banner(header_prepend + 'OVERALL UNIT TEST SUMMARY')%>
      % if (hash[:results][:counts][:total] > 0)
      TESTED:  <%=hash[:results][:counts][:total].to_s%>
      PASSED:  <%=sprintf(format_string, hash[:results][:counts][:passed])%>
      FAILED:  <%=sprintf(format_string, failed)%>
      IGNORED: <%=sprintf(format_string, ignored)%>
      % else

      No tests executed.
      % end

      }.left_margin
      
      @ceedling[:plugin_reportinator].register_test_results_template( template )
  end
  
  def post_test_execute(arg_hash)
    return if not (arg_hash[:context] == TEST_CONTEXT)
  
    @result_list << arg_hash[:result_file]
  end
  
  def post_build
    return if not (@ceedling[:task_invoker].test_invoked?)

    results = @ceedling[:plugin_reportinator].assemble_test_results(@result_list)
    hash = {
      :header => '',
      :results => results
    }

    @ceedling[:plugin_reportinator].run_test_results_report(hash) do
      message = ''
      message = 'Unit test failures.' if (results[:counts][:failed] > 0)
      message
    end
  end

  def summary
    result_list = @ceedling[:file_path_utils].form_pass_results_filelist( PROJECT_TEST_RESULTS_PATH, COLLECTION_ALL_TESTS )

    # get test results for only those tests in our configuration and of those only tests with results on disk
    hash = {
      :header => '',
      :results => @ceedling[:plugin_reportinator].assemble_test_results(result_list, {:boom => false})
    }

    @ceedling[:plugin_reportinator].run_test_results_report(hash)
  end

end