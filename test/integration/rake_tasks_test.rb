require File.dirname(__FILE__) + '/../integration_test_helper'
require 'rubygems'
require 'rake'


class RakeTasksTest < Test::Unit::TestCase

  def setup
    rake_setup('rakefile_tasks.rb', :configurator, :test_invoker)
  end

  def teardown
    Rake.application = nil
  end
  
  
  should "clean all test results and invoke all tests" do
    all_tests = ['tests/test_yo.c', 'tests/test.mama.c']

    redefine_global_constant('COLLECTION_ALL_TESTS', all_tests)
    setup()

    # set up expectations
    @test_invoker.expects.invoke_tests(all_tests)
    
    # invoke the task
    @rake['tests:all'].invoke
  end
  

end
