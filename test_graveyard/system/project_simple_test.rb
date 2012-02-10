require File.dirname(__FILE__) + '/../system_test_helper'


class ProjectSimpleTest < Test::Unit::TestCase

  def setup
    @results_path = "#{SYSTEM_TEST_ROOT}/simple/build/tests/results"
    
    ENV['CEEDLING_MAIN_PROJECT_FILE'] = File.join(SYSTEM_TEST_ROOT, 'project_simple.yml')

    ceedling_execute('directories', 'clobber')
  end

  def teardown
  end


  should "run all tests and verify test results" do

    # tell rake to execute all tests; use '--trace' to see problem if rake run explodes
    ceedling_execute('test:all', '--trace')
    
    results = fetch_test_results(@results_path, 'test_stuff');
    
    assert_equal(7, results[:counts][:total])
    assert_equal(2, results[:counts][:passed])
    assert_equal(1, results[:counts][:failed])
    assert_equal(4, results[:counts][:ignored])

    results = fetch_test_results(@results_path, 'test_other_stuff');
    
    assert_equal(4, results[:counts][:total])
    assert_equal(2, results[:counts][:passed])
    assert_equal(2, results[:counts][:failed])
    assert_equal(0, results[:counts][:ignored])

  end

end
