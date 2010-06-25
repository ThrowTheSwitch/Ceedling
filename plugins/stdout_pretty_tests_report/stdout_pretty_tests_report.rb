require 'plugin'


class StdoutPrettyTestsReport < Plugin
  
  def setup
    @test_list = []
    
    @template = %q{
      % ignored      = results[:counts][:ignored]
      % failed       = results[:counts][:failed]
      % stdout_count = results[:counts][:stdout]
      % if (ignored > 0)
      <%=@ceedling[:plugin_reportinator].generate_banner('IGNORED UNIT TEST SUMMARY')%>
      %   results[:ignores].each do |ignore|
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
      <%=@ceedling[:plugin_reportinator].generate_banner('FAILED UNIT TEST SUMMARY')%>
      %   results[:failures].each do |failure|
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
      <%=@ceedling[:plugin_reportinator].generate_banner('UNIT TEST OTHER OUTPUT')%>
      %   results[:stdout].each do |string|
      [<%=string[:source][:file]%>]
      %     string[:collection].each do |item|
        :"<%=item%>"
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
    test = File.basename(arg_hash[:executable], EXTENSION_EXECUTABLE)
    
    @test_list << test if not @test_list.include?(test)
  end
  
  def post_build
    return if (not @ceedling[:plugin_reportinator].test_build?)

    results = @ceedling[:plugin_reportinator].assemble_test_results(PROJECT_TEST_RESULTS_PATH, @test_list)

    @ceedling[:plugin_reportinator].run_report($stdout, @template, results) do
      message = ''
      message = 'Unit test failures.' if (results[:counts][:failed] > 0)
      message
    end
  end

end