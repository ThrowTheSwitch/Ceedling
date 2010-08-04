
namespace TESTS_TASKS_ROOT_NAME.to_sym do
  
  desc "Run all unit tests."
  task :all => [:directories] do
    @ceedling[:test_invoker].setup_and_invoke(COLLECTION_ALL_TESTS)
  end

  COLLECTION_ALL_TESTS.each do |test|
    # by test file name
    name = File.basename(test)
    task name.to_sym => [:directories] do
      @ceedling[:test_invoker].setup_and_invoke(test)
    end

    # by source file name
    name = File.basename(test).sub(/#{PROJECT_TEST_FILE_PREFIX}/, '')
    task name.to_sym => [:directories] do
      @ceedling[:test_invoker].setup_and_invoke(test)
    end
    
    # by header file name
    name = File.basename(test).ext(EXTENSION_HEADER).sub(/#{PROJECT_TEST_FILE_PREFIX}/, '')
    task name.to_sym => [:directories] do
      @ceedling[:test_invoker].setup_and_invoke(test)
    end
  end

  desc "Run tests for changed files."
  task :delta => [:directories] do
    @ceedling[:test_invoker].setup_and_invoke(COLLECTION_ALL_TESTS, {:force_run => false})
  end
  
end