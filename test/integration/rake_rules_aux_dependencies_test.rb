require File.dirname(__FILE__) + '/../integration_test_helper'
require 'rubygems'
require 'rake'


class RakeRulesAuxDependenciesTest < Test::Unit::TestCase

  def setup
    rake_setup('rakefile_rules_aux_dependencies.rb', :file_finder, :generator)
  end

  def teardown
    Rake.application = nil
  end
  
  
  should "recognize missing dependencies files, find their source, and execute rake tasks from the rule for dependency file generation" do
    # default values as set in test_helper
    redefine_global_constant('PROJECT_TEST_DEPENDENCIES_PATH', 'project/build/dependencies')
    redefine_global_constant('EXTENSION_DEPENDENCIES', '.d')

    # reload rakefile with new global constants
    setup()

    dependencies_src1 = 'files/source/thing.c'
    dependencies_src2 = 'tests/test_thing.c'
    dependencies_src3 = 'lib/stuff.c'
    dependencies1     = 'project/build/dependencies/thing.d'
    dependencies2     = 'project/build/dependencies/test_thing.d'
    dependencies3     = 'project/build/dependencies/stuff.d'

    # fake out rake so it won't look for the header files on disk and find they don't exist.
    # by creating file tasks we're telling rake there's a means to create these files that don't exist (but we never use the mechanism).
    @rake.define_task(Rake::FileTask, dependencies_src1)
    @rake.define_task(Rake::FileTask, dependencies_src2)
    @rake.define_task(Rake::FileTask, dependencies_src3)

    # set up expectations
    @file_finder.expects.find_compilation_input_file(dependencies1).returns(dependencies_src1)
    @generator.expects.generate_dependencies_file(dependencies_src1, dependencies1)
    @file_finder.expects.find_compilation_input_file(dependencies2).returns(dependencies_src2)
    @generator.expects.generate_dependencies_file(dependencies_src2, dependencies2)
    @file_finder.expects.find_compilation_input_file(dependencies3).returns(dependencies_src3)
    @generator.expects.generate_dependencies_file(dependencies_src3, dependencies3)

    # invoke the dependencies creation rule under test
    @rake[dependencies1].invoke
    @rake[dependencies2].invoke
    @rake[dependencies3].invoke
  end

  should "handle alternate build file paths and file extensions for dependency file generation rule" do
    # default values as set in test_helper
    redefine_global_constant('PROJECT_TEST_DEPENDENCIES_PATH', 'dependencies/dump')
    redefine_global_constant('EXTENSION_DEPENDENCIES', '.i')

    # reload rakefile with new global constants
    setup()

    dependencies_src1 = 'files/source/thing.c'
    dependencies1     = 'dependencies/dump/thing.i'

    # fake out rake so it won't look for the header files on disk and find they don't exist.
    # by creating file tasks we're telling rake there's a means to create these files that don't exist (but we never use the mechanism).
    @rake.define_task(Rake::FileTask, dependencies_src1)

    # set up expectations
    @file_finder.expects.find_compilation_input_file(dependencies1).returns(dependencies_src1)
    @generator.expects.generate_dependencies_file(dependencies_src1, dependencies1)

    # invoke the dependencies creation rule under test
    @rake[dependencies1].invoke
  end

end
