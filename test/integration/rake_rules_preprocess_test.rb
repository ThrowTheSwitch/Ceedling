require File.dirname(__FILE__) + '/../unit_test_helper'
require 'rubygems'
require 'rake'


class RakeRulesPreprocessTest < Test::Unit::TestCase

  def setup    
    rake_setup('rakefile_rules_preprocess.rb', :file_finder, :generator, :configurator)
  end

  def teardown
    Rake.application = nil
  end
  
  
  ################################
  ####### Preprocess Files #######
  ################################

  should "recognize missing preprocessed files, find their source, and execute rake tasks from the rule for generating preprocessed file output" do
    # default values as set in test_helper
    redefine_global_constant('PROJECT_TEST_PREPROCESS_FILES_PATH', 'project/build/preprocess/files')
    # because rule matches on any file, gotta set this path here to help rake distinguish rules when file is tested
    redefine_global_constant('PROJECT_TEST_PREPROCESS_INCLUDES_PATH', 'project/build/preprocess/includes')

    # reload rakefile with new global constants
    setup()

    # try all different paths and file extensions; we should be able to preprocess any kind of source file
    preprocess_src1 = 'tests/a/test_thing.c'
    preprocess_src2 = 'source/a_file.h'
    preprocess_src3 = 'source/lib/include/API.H'
    preprocess1     = 'project/build/preprocess/files/test_thing.c'
    preprocess2     = 'project/build/preprocess/files/a_file.h'
    preprocess3     = 'project/build/preprocess/files/API.H'
  
    # fake out rake so it won't look for the test files on disk and find they don't exist.
    # by creating file tasks we're telling rake there's a means to create these files that don't exist (but we never use the mechanism).
    @rake.define_task(Rake::FileTask, preprocess_src1)
    @rake.define_task(Rake::FileTask, preprocess_src2)
    @rake.define_task(Rake::FileTask, preprocess_src3)
  
    # set up expectations
    @file_finder.expects.find_test_or_source_or_header_file(preprocess1).returns(preprocess_src1)
    @configurator.expects.project_use_auxiliary_dependencies.returns(true)
    @generator.expects.generate_preprocessed_file(preprocess_src1)

    @file_finder.expects.find_test_or_source_or_header_file(preprocess2).returns(preprocess_src2)
    @configurator.expects.project_use_auxiliary_dependencies.returns(true)
    @generator.expects.generate_preprocessed_file(preprocess_src2)

    @file_finder.expects.find_test_or_source_or_header_file(preprocess3).returns(preprocess_src3)
    @configurator.expects.project_use_auxiliary_dependencies.returns(true)
    @generator.expects.generate_preprocessed_file(preprocess_src3)
    
    # invoke the test preprocess creation rule under test
    @rake[preprocess1].invoke
    @rake[preprocess2].invoke
    @rake[preprocess3].invoke
  end

  should "complain if file preprocessing rule is executed but auxiliary dependencies are not enabled" do
    # default values as set in test_helper
    redefine_global_constant('PROJECT_TEST_PREPROCESS_FILES_PATH', 'project/build/preprocess/files')
    # because rule matches on any file, gotta set this path here to help rake distinguish rules when file is tested
    redefine_global_constant('PROJECT_TEST_PREPROCESS_INCLUDES_PATH', 'project/build/preprocess/includes')

    # reload rakefile with new global constants
    setup()

    # try all different paths and file extensions; we should be able to preprocess any kind of source file
    preprocess_src1 = 'tests/a/test_thing.c'
    preprocess1     = 'project/build/preprocess/files/test_thing.c'
  
    # fake out rake so it won't look for the test files on disk and find they don't exist.
    # by creating file tasks we're telling rake there's a means to create these files that don't exist (but we never use the mechanism).
    @rake.define_task(Rake::FileTask, preprocess_src1)
  
    # set up expectations
    @file_finder.expects.find_test_or_source_or_header_file(preprocess1).returns(preprocess_src1)
    @configurator.expects.project_use_auxiliary_dependencies.returns(false)
    
    # invoke the test preprocess creation rule under test
    assert_raise(RuntimeError){ @rake[preprocess1].invoke }
  end

  should "handle alternate output file paths for preprocessed file output rule" do
    # default values as set in test_helper
    redefine_global_constant('PROJECT_TEST_PREPROCESS_FILES_PATH', 'demacroified/files')
    # because rule matches on any file, gotta set this path here to help rake distinguish rules when file is tested
    redefine_global_constant('PROJECT_TEST_PREPROCESS_INCLUDES_PATH', 'includes')

    # reload rakefile with new global constants
    setup()

    preprocess_src1 = 'tests/a/test_thing.C'
    preprocess1     = 'demacroified/files/test_thing.C'
  
    # fake out rake so it won't look for the test files on disk and find they don't exist.
    # by creating file tasks we're telling rake there's a means to create these files that don't exist (but we never use the mechanism).
    @rake.define_task(Rake::FileTask, preprocess_src1)
  
    # set up expectations
    @file_finder.expects.find_test_or_source_or_header_file(preprocess1).returns(preprocess_src1)
    @configurator.expects.project_use_auxiliary_dependencies.returns(true)
    @generator.expects.generate_preprocessed_file(preprocess_src1)

    # invoke the test preprocess creation rule under test
    @rake[preprocess1].invoke
  end

  ########################################
  ####### Extract Shallow Includes #######
  ########################################

  should "recognize missing extracted includes files, find their source, and execute rake tasks from the rule for extracting file includes output" do
    # default values as set in test_helper
    redefine_global_constant('PROJECT_TEST_PREPROCESS_INCLUDES_PATH', 'project/build/preprocess/includes')
    # because rule matches on any file, gotta set this path here to help rake distinguish rules when file is tested
    redefine_global_constant('PROJECT_TEST_PREPROCESS_FILES_PATH', 'project/build/preprocess/files')

    # reload rakefile with new global constants
    setup()

    # try all different paths and file extensions; we should be able to preprocess any kind of source file
    includes_src1 = 'tests/a/test_thing.c'
    includes_src2 = 'source/a_file.h'
    includes_src3 = 'source/lib/include/API.H'
    includes1     = 'project/build/preprocess/includes/test_thing.c'
    includes2     = 'project/build/preprocess/includes/a_file.h'
    includes3     = 'project/build/preprocess/includes/API.H'
  
    # fake out rake so it won't look for the test files on disk and find they don't exist.
    # by creating file tasks we're telling rake there's a means to create these files that don't exist (but we never use the mechanism).
    @rake.define_task(Rake::FileTask, includes_src1)
    @rake.define_task(Rake::FileTask, includes_src2)
    @rake.define_task(Rake::FileTask, includes_src3)
  
    # set up expectations
    @file_finder.expects.find_test_or_source_or_header_file(includes1).returns(includes_src1)
    @generator.expects.generate_shallow_includes_list(includes_src1)
    @file_finder.expects.find_test_or_source_or_header_file(includes2).returns(includes_src2)
    @generator.expects.generate_shallow_includes_list(includes_src2)
    @file_finder.expects.find_test_or_source_or_header_file(includes3).returns(includes_src3)
    @generator.expects.generate_shallow_includes_list(includes_src3)
    
    # invoke the test includes creation rule under test
    @rake[includes1].invoke
    @rake[includes2].invoke
    @rake[includes3].invoke
  end

  should "handle alternate output file paths for preprocessor incluedes file output rule" do
    # default values as set in test_helper
    redefine_global_constant('PROJECT_TEST_PREPROCESS_INCLUDES_PATH', 'include_stuff')
    # because rule matches on any file, gotta set this path here to help rake distinguish rules when file is tested
    redefine_global_constant('PROJECT_TEST_PREPROCESS_FILES_PATH', 'project/build/preprocess/files')

    # reload rakefile with new global constants
    setup()

    includes_src1 = 'tests/a/test_thing.C'
    includes1     = 'include_stuff/test_thing.C'
  
    # fake out rake so it won't look for the test files on disk and find they don't exist.
    # by creating file tasks we're telling rake there's a means to create these files that don't exist (but we never use the mechanism).
    @rake.define_task(Rake::FileTask, includes_src1)
  
    # set up expectations
    @file_finder.expects.find_test_or_source_or_header_file(includes1).returns(includes_src1)
    @generator.expects.generate_shallow_includes_list(includes_src1)
    
    # invoke the test includes creation rule under test
    @rake[includes1].invoke
  end

end
