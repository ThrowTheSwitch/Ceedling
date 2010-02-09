require File.dirname(__FILE__) + '/../system_test_helper'


class TestTasksTest < Test::Unit::TestCase

  def setup
    @results_path = "#{SYSTEM_TEST_ROOT}/mocks/build/tests/results"
    
    ENV['CEEDLING_MAIN_PROJECT_FILE'] = File.join(SYSTEM_TEST_ROOT, 'project_mocks.yml')

    ceedling_execute('directories', 'clobber')
  end

  def teardown
  end


  should "run a test and verify test results" do

    # tell rake to execute all tests; use '--trace' to see problem if rake run explodes
    ceedling_execute('test:test_a_file.c', '--trace')
    
    results = fetch_test_results(@results_path, 'test_a_file');
    
    assert_equal(4, results[:counts][:total])
    assert_equal(2, results[:counts][:passed])
    assert_equal(2, results[:counts][:failed])
  end

  should "blow up if header to be mocked is not found" do

    # tell rake to execute all tests
    results = ceedling_execute_no_boom('test:test_no_file.c')
    assert_no_match(/ERROR: Could not find 'say_wha\.h'/i, results, 'execution should have failed because header file was not found')
  end


end
