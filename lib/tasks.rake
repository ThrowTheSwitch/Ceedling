require 'verbosinator'


desc "Display test build environment version info."
task :version do
# print ceedling, cmock, unity info
end


desc "Set verbose output [0-3]."
task :verbosity, :level do |t, args|
  verbosity_level = args.level.to_i
  
  # update internal verbosity settings
  @objects[:configurator].set_verbosity(verbosity_level)
  
  # control rake's verbosity with new setting
  if (verbosity_level == Verbosity::OBNOXIOUS)
    verbose(true)
  else
    verbose(false)
  end
end


task :default => [:directories, :clobber, 'tests:all']


namespace :tests do
  
  desc "Run all unit tests."
  task(:all) { @objects[:test_invoker].invoke_tests(COLLECTION_ALL_TESTS) }
      
  COLLECTION_ALL_TESTS.each do |test|
    # by test file name
    name = File.basename(test)
    task(name.to_sym) { @objects[:test_invoker].invoke_tests(test) }

    # by source file name
    name = File.basename(test).sub(/#{PROJECT_TEST_FILE_PREFIX}/, '')
    task(name.to_sym) { @objects[:test_invoker].invoke_tests(test) }

    # by header file name
    name = File.basename(test).ext(EXTENSION_HEADER).sub(/#{PROJECT_TEST_FILE_PREFIX}/, '')
    task(name.to_sym) { @objects[:test_invoker].invoke_tests(test) }
  end
    
  desc "Run tests for changed files."
  task(:delta) { @objects[:test_invoker].invoke_tests(COLLECTION_ALL_TESTS, {:force_run => false}) }
  
end