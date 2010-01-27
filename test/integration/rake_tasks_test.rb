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


  should "set verbosity level 0" do
    # set up expectations
    @configurator.expects.set_verbosity(0)
    
    # invoke the task
    @rake['verbosity'].invoke('0')
  end

  should "set verbosity level 2" do
    # set up expectations
    @configurator.expects.set_verbosity(2)
    
    # invoke the task
    @rake['verbosity'].invoke(2)
  end
  
  
  should "invoke all tests" do
    all_tests = ['tests/test_yo.c', 'tests/test.mama.c']

    redefine_global_constant('COLLECTION_ALL_TESTS', all_tests)
    setup()

    # set up expectations
    @test_invoker.expects.invoke_tests(all_tests)
    
    # invoke the task
    @rake['tests:all'].invoke
  end

  should "invoke a test by its test file name" do
    all_tests = ['tests/test_yo.c', 'tests/test.mama.c']

    redefine_global_constant('COLLECTION_ALL_TESTS', all_tests)
    redefine_global_constant('PROJECT_TEST_FILE_PREFIX', 'test_')
    setup()

    # set up expectations
    @test_invoker.expects.invoke_tests('tests/test_yo.c')
    
    # invoke the task
    @rake['tests:test_yo.c'].invoke
  end

  should "invoke a test by its source file name" do
    all_tests = ['tests/TestIcle.c', 'tests/TestYoMama.c']

    redefine_global_constant('COLLECTION_ALL_TESTS', all_tests)
    redefine_global_constant('PROJECT_TEST_FILE_PREFIX', 'Test')
    setup()

    # set up expectations
    @test_invoker.expects.invoke_tests('tests/TestIcle.c')
    
    # invoke the task
    @rake['tests:Icle.c'].invoke
  end

  should "invoke a test by its source header file name" do
    all_tests = ['tests/TestIcle.c', 'tests/TestYoMama.c']

    redefine_global_constant('COLLECTION_ALL_TESTS', all_tests)
    redefine_global_constant('PROJECT_TEST_FILE_PREFIX', 'Test')
    setup()

    # set up expectations
    @test_invoker.expects.invoke_tests('tests/TestYoMama.c')
    
    # invoke the task
    @rake['tests:YoMama.h'].invoke
  end  

  should "complain upon unknown test task" do
    all_tests = ['tests/TestIcle.c', 'tests/TestYoMama.c']

    redefine_global_constant('COLLECTION_ALL_TESTS', all_tests)
    redefine_global_constant('PROJECT_TEST_FILE_PREFIX', 'Test')
    setup()

    # invoke the task
    assert_raise(RuntimeError){ @rake['tests:Broken.c'].invoke }
  end  


end
