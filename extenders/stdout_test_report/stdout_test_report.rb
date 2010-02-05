require 'extender'
require 'yaml'


class StdoutTestReport < Extender
  
  def setup
    @test_list = []
  end
  
  
  def post_test_execute(arg_hash)    
    @test_list << File.basename(arg_hash[:executable], EXTENSION_EXECUTABLE)
  end
  
  def post_build
    return if (not @system_objects[:extendinator].test_build?)

    @system_objects[:reporter_test_results].run_report(PROJECT_TEST_RESULTS_PATH, @test_list, 'Unit test failures.')
  end

end