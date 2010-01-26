require File.dirname(__FILE__) + '/../unit_test_helper'
require 'rubygems'
require 'rake'


class RakeTasksTest < Test::Unit::TestCase

  def setup    
    # create mocks rules will use
    objects = create_mocks(:configurator, :test_invoker)

    # create & assign instance of rake
    @rake = Rake::Application.new
    Rake.application = @rake
    
    # tell rake to be verbose in its tracing output
    # (hard to do otherwise since our tests are run from within a rake instance around this one)
    Rake.application.options.trace_rules = true

    # load rakefile wrapper that loads actual rules
    load File.join(TESTS_ROOT, 'rakefile_tasks.rb')
    
    # provide the mock objects to the rakefile instance under test
    @rake['inject'].invoke(objects)
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
