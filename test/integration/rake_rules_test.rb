require File.dirname(__FILE__) + '/../integration_test_helper'
require 'rubygems'
require 'rake'


class RakeRulesTest < Test::Unit::TestCase

  def setup
    rake_setup('rakefile_rules.rb', :file_finder, :file_path_utils, :generator)
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
    runner1     = 'build/tests/runners/test_thing_runner.c'
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

  ##################################################
  ####### Compilation Object File Generation #######
  ##################################################

  should "recognize missing object files, find their source, and execute rake tasks from the rule for object file generation" do
    # default values as set in test_helper
    redefine_global_constant('PROJECT_TEST_BUILD_OUTPUT_PATH', 'project/build/tests/output')
    redefine_global_constant('EXTENSION_OBJECT', '.o')

    # reload rakefile with new global constants
    setup()

    object_src1 = 'tests/a/test_thing.c'
    object_src2 = 'tests/b/test_another_thing.c'
    object_src3 = 'tests/b/test_and_another_thing.c'
    object1     = 'project/build/tests/output/test_thing.o'
    object2     = 'project/build/tests/output/test_another_thing_runner.o'
    object3     = 'project/build/tests/output/test_and_another_thing.o'
  
    # fake out rake so it won't look for the test files on disk and find they don't exist.
    # by creating file tasks we're telling rake there's a means to create these files that don't exist (but we never use the mechanism).
    @rake.define_task(Rake::FileTask, object_src1)
    @rake.define_task(Rake::FileTask, object_src2)
    @rake.define_task(Rake::FileTask, object_src3)
  
    # set up expectations
    @file_finder.expects.find_compilation_input_file(object1).returns(object_src1)
    @generator.expects.generate_object_file(object_src1, object1)
    @file_finder.expects.find_compilation_input_file(object2).returns(object_src2)
    @generator.expects.generate_object_file(object_src2, object2)
    @file_finder.expects.find_compilation_input_file(object3).returns(object_src3)
    @generator.expects.generate_object_file(object_src3, object3)
    
    # invoke the test object creation rule under test
    @rake[object1].invoke
    @rake[object2].invoke
    @rake[object3].invoke
  end
  
  should "handle alternate build file paths and object file extensions for object generation rule" do
    redefine_global_constant('PROJECT_TEST_BUILD_OUTPUT_PATH', 'build/stuff/out')
    redefine_global_constant('EXTENSION_OBJECT', '.obj')
  
    # reload rakefile with new global constants
    setup()
    
    object_src1 = 'tests/a/test_thing.c'
    object1     = 'build/stuff/out/test_thing.obj'
  
    # fake out rake so it won't look for the test files on disk and find they don't exist.
    # by creating file tasks we're telling rake there's a means to create these files that don't exist (but we never use the mechanism).
    @rake.define_task(Rake::FileTask, object_src1)
  
    # set up expectations
    @file_finder.expects.find_compilation_input_file(object1).returns(object_src1)
    @generator.expects.generate_object_file(object_src1, object1)
    
    # invoke the test runner creation rule under test
    @rake[object1].invoke
  end

  ##########################################
  ####### Executable File Generation #######
  ##########################################

  should "recognize missing executable files, find their object files, and execute rake tasks from the rule for executable generation" do
    # default values as set in test_helper
    redefine_global_constant('PROJECT_TEST_BUILD_OUTPUT_PATH', 'project/build/tests/output')
    redefine_global_constant('EXTENSION_EXECUTABLE', '.out')

    # reload rakefile with new global constants
    setup()

    executable_prereqs1 = ['project/build/tests/output/unity.o', 'project/build/tests/output/mock_stuff.o', 'project/build/tests/output/thing.o']
    executable_prereqs2 = ['project/build/tests/output/able.o', 'project/build/tests/output/unity.o']
    executable1         = 'project/build/tests/output/test_thing.out'
    executable2         = 'project/build/tests/output/test_able.out'
  
    # fake out rake so it won't look for the test files on disk and find they don't exist.
    # by creating file tasks we're telling rake there's a means to create these files that don't exist (but we never use the mechanism).
    @rake.define_task(Rake::FileTask, executable_prereqs1[0])
    @rake.define_task(Rake::FileTask, executable_prereqs1[1])
    @rake.define_task(Rake::FileTask, executable_prereqs1[2])
    @rake.define_task(Rake::FileTask, executable_prereqs2[0])
    @rake.define_task(Rake::FileTask, executable_prereqs2[1])

    task = @rake.define_task(Rake::FileTask, executable1)
    task.enhance(executable_prereqs1)
    task = @rake.define_task(Rake::FileTask, executable2)
    task.enhance(executable_prereqs2)

    # set up expectations
    @generator.expects.generate_executable_file(executable_prereqs1, executable1)
    @generator.expects.generate_executable_file(executable_prereqs2, executable2)
    
    # invoke the test object creation rule under test
    @rake[executable1].invoke
    @rake[executable2].invoke
  end
  
  should "handle alternate build file paths and executable extensions for executable generation rule" do
    # default values as set in test_helper
    redefine_global_constant('PROJECT_TEST_BUILD_OUTPUT_PATH', 'build/dump')
    redefine_global_constant('EXTENSION_EXECUTABLE', '.exe')

    # reload rakefile with new global constants
    setup()

    executable_prereqs1 = ['project/build/tests/output/able.o', 'project/build/tests/output/unity.o']
    executable1         = 'build/dump/test_able.exe'
  
    # fake out rake so it won't look for the test files on disk and find they don't exist.
    # by creating file tasks we're telling rake there's a means to create these files that don't exist (but we never use the mechanism).
    @rake.define_task(Rake::FileTask, executable_prereqs1[0])
    @rake.define_task(Rake::FileTask, executable_prereqs1[1])

    task = @rake.define_task(Rake::FileTask, executable1)
    task.enhance(executable_prereqs1)

    # set up expectations
    @generator.expects.generate_executable_file(executable_prereqs1, executable1)
    
    # invoke the test object creation rule under test
    @rake[executable1].invoke
  end

  ###############################################################
  ####### Test Pass File Generation (i.e. execute a test) #######
  ###############################################################

  should "recognize missing test pass files, find the test executable, and execute rake tasks from the rule for test result generation" do
    # default values as set in test_helper
    redefine_global_constant('PROJECT_TEST_RESULTS_PATH', 'project/build/tests/results')
    redefine_global_constant('EXTENSION_TESTPASS', '.pass')

    # reload rakefile with new global constants
    setup()

    pass_results_src1 = 'project/build/tests/output/test_thing.exe'
    pass_results_src2 = 'project/build/tests/output/test_another_thing.exe'
    pass_results_src3 = 'project/build/tests/output/test_and_another_thing.exe'
    pass_results1     = 'project/build/tests/results/test_thing.pass'
    pass_results2     = 'project/build/tests/results/test_another_thing_runner.pass'
    pass_results3     = 'project/build/tests/results/test_and_another_thing.pass'
  
    # fake out rake so it won't look for the test files on disk and find they don't exist.
    # by creating file tasks we're telling rake there's a means to create these files that don't exist (but we never use the mechanism).
    @rake.define_task(Rake::FileTask, pass_results_src1)
    @rake.define_task(Rake::FileTask, pass_results_src2)
    @rake.define_task(Rake::FileTask, pass_results_src3)
  
    # set up expectations
    @file_path_utils.expects.form_executable_filepath(pass_results1).returns(pass_results_src1)
    @generator.expects.generate_test_results(pass_results_src1, pass_results1)
    @file_path_utils.expects.form_executable_filepath(pass_results2).returns(pass_results_src2)
    @generator.expects.generate_test_results(pass_results_src2, pass_results2)
    @file_path_utils.expects.form_executable_filepath(pass_results3).returns(pass_results_src3)
    @generator.expects.generate_test_results(pass_results_src3, pass_results3)
    
    # invoke the test pass results creation rule under test
    @rake[pass_results1].invoke
    @rake[pass_results2].invoke
    @rake[pass_results3].invoke
  end
  
  should "handle alternate test results file paths and test pass file extensions for test results generation rule" do
    # default values as set in test_helper
    redefine_global_constant('PROJECT_TEST_RESULTS_PATH', 'project/test_run')
    redefine_global_constant('EXTENSION_TESTPASS', '.testpass')

    # reload rakefile with new global constants
    setup()

    pass_results_src1 = 'project/build/tests/output/test_thing.exe'
    pass_results1     = 'project/test_run/test_thing.testpass'
  
    # fake out rake so it won't look for the test files on disk and find they don't exist.
    # by creating file tasks we're telling rake there's a means to create these files that don't exist (but we never use the mechanism).
    @rake.define_task(Rake::FileTask, pass_results_src1)
  
    # set up expectations
    @file_path_utils.expects.form_executable_filepath(pass_results1).returns(pass_results_src1)
    @generator.expects.generate_test_results(pass_results_src1, pass_results1)
    
    # invoke the test pass results creation rule under test
    @rake[pass_results1].invoke
  end

end
