require File.dirname(__FILE__) + '/../unit_test_helper'
require 'rubygems'
require 'rake'


class RakeRulesTest < Test::Unit::TestCase

  def setup    
    # create mocks rules will use
    objects = create_mocks(:file_finder, :generator)
    # create & assign instance of rake
    @rake = Rake::Application.new
    Rake.application = @rake
    
    # tell rake to be verbose in its tracing output
    # (hard to do otherwise since our tests are run from within a rake instance around this one)
    Rake.application.options.trace_rules = true

    # load rakefile wrapper that loads actual rules
    load File.join(TESTS_ROOT, 'rakefile_rules.rb')
    
    # provide the mock objects to the rakefile instance under test
    @rake['inject'].invoke(objects)    
  end

  def teardown
    Rake.application = nil
  end
  
  
  ######################################
  ####### Test Runner Generation #######
  ######################################

  should "recognize missing test runner files, find their source, and execute rake tasks from the rule for test runner generation" do
    # default values as set in test_helper
    redefine_global_constant('PROJECT_TEST_FILE_PREFIX', 'test_')
    redefine_global_constant('TEST_RUNNER_FILE_SUFFIX', '_runner')
    redefine_global_constant('EXTENSION_SOURCE', '.c')

    # reload rakefile with new global constants
    setup()

    runner_src1 = 'tests/a/test_thing.c'
    runner_src2 = 'tests/b/test_another_thing.c'
    runner_src3 = 'tests/b/test_and_another_thing.c'
    runner1     = 'build/runners/test_thing_runner.c'
    runner2     = 'test_another_thing_runner.c'
    runner3     = 'runners/test_another_thing_runner.c'
  
    # fake out rake so it won't look for the test files on disk and find they don't exist.
    # by creating file tasks we're telling rake there's a means to create these files that don't exist (but we never use the mechanism).
    @rake.define_task(Rake::FileTask, runner_src1)
    @rake.define_task(Rake::FileTask, runner_src2)
    @rake.define_task(Rake::FileTask, runner_src3)
  
    # set up expectations
    @file_finder.expects.find_test_from_runner_path(runner1).returns(runner_src1)
    @generator.expects.generate_test_runner(runner_src1, runner1)
    @file_finder.expects.find_test_from_runner_path(runner2).returns(runner_src2)
    @generator.expects.generate_test_runner(runner_src2, runner2)
    @file_finder.expects.find_test_from_runner_path(runner3).returns(runner_src3)
    @generator.expects.generate_test_runner(runner_src3, runner3)
    
    # invoke the test runner creation rule under test
    @rake[runner1].invoke
    @rake[runner2].invoke
    @rake[runner3].invoke
  end

  should "handle alternate prefixes, suffixes, and source extensions for test runner generation rule" do
    redefine_global_constant('PROJECT_TEST_FILE_PREFIX', 'Test')
    redefine_global_constant('TEST_RUNNER_FILE_SUFFIX', 'Runner')
    redefine_global_constant('EXTENSION_SOURCE', '.x')

    # reload rakefile with new global constants
    setup()
    
    runner_src1 = 'files/tests/TestOneTwoThree.x'
    runner1     = 'build/runners/TestOneTwoThreeRunner.x'
  
    # fake out rake so it won't look for the test files on disk and find they don't exist.
    # by creating file tasks we're telling rake there's a means to create these files that don't exist (but we never use the mechanism).
    @rake.define_task(Rake::FileTask, runner_src1)
  
    # set up expectations
    @file_finder.expects.find_test_from_runner_path(runner1).returns(runner_src1)
    @generator.expects.generate_test_runner(runner_src1, runner1)
    
    # invoke the test runner creation rule under test
    @rake[runner1].invoke
  end

end
