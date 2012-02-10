require File.dirname(__FILE__) + '/../integration_test_helper'
require 'rubygems'
require 'rake'


class RakeTasksTest < Test::Unit::TestCase

  def setup
    rake_setup('rakefile_tasks.rb', :configurator, :test_invoker)
    
    @rake.define_task(Rake::FileTask, :directories) # fake out dependency in test tasks
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
    @test_invoker.expects.setup_and_invoke(all_tests)
    
    # invoke the task
    @rake['test:all'].invoke
  end

  should "invoke a test by its test file name" do
    all_tests = ['tests/test_yo.c', 'tests/test.mama.c']

    redefine_global_constant('COLLECTION_ALL_TESTS', all_tests)
    redefine_global_constant('PROJECT_TEST_FILE_PREFIX', 'test_')
    setup()

    # set up expectations
    @test_invoker.expects.setup_and_invoke('tests/test_yo.c')
    
    # invoke the task
    @rake['test:test_yo.c'].invoke
  end

  should "invoke a test by its source file name" do
    all_tests = ['tests/TestIcle.c', 'tests/TestYoMama.c']

    redefine_global_constant('COLLECTION_ALL_TESTS', all_tests)
    redefine_global_constant('PROJECT_TEST_FILE_PREFIX', 'Test')
    setup()

    # set up expectations
    @test_invoker.expects.setup_and_invoke('tests/TestIcle.c')
    
    # invoke the task
    @rake['test:Icle.c'].invoke
  end

  should "invoke a test by its source header file name" do
    all_tests = ['tests/TestIcle.c', 'tests/TestYoMama.c']

    redefine_global_constant('COLLECTION_ALL_TESTS', all_tests)
    redefine_global_constant('PROJECT_TEST_FILE_PREFIX', 'Test')
    setup()

    # set up expectations
    @test_invoker.expects.setup_and_invoke('tests/TestYoMama.c')
    
    # invoke the task
    @rake['test:YoMama.h'].invoke
  end  

  should "complain upon unknown test task" do
    all_tests = ['tests/TestIcle.c', 'tests/TestYoMama.c']

    redefine_global_constant('COLLECTION_ALL_TESTS', all_tests)
    redefine_global_constant('PROJECT_TEST_FILE_PREFIX', 'Test')
    setup()

    # invoke the task
    assert_raise(RuntimeError){ @rake['test:Broken.c'].invoke }
  end  


end
