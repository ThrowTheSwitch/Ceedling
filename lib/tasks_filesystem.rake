
PROJECT_BUILD_PATHS.each { |path| directory(path) }  

CLEAN.include(File.join(PROJECT_TEST_BUILD_OUTPUT_PATH, '*'))
CLEAN.include(File.join(PROJECT_TEST_RESULTS_PATH, '*'))
CLEAN.include(File.join(PROJECT_RELEASE_BUILD_OUTPUT_PATH, '*')) if (RELEASE_BUILD_ENABLED)

CLOBBER.include(File.join(PROJECT_BUILD_ARTIFACTS_ROOT, '**/*'))
CLOBBER.include(File.join(PROJECT_BUILD_TESTS_ROOT, '**/*'))
CLOBBER.include(File.join(PROJECT_BUILD_RELEASE_ROOT, '**/*')) if (RELEASE_BUILD_ENABLED)
CLOBBER.include(File.join(PROJECT_LOG_PATH, '**/*'))

# because of cmock config, mock path can optionally exist apart from standard test build paths
CLOBBER.include(File.join(CMOCK_MOCK_PATH, '*')) if (PROJECT_USE_MOCKS)


# create directories that hold build output and generated files
task :directories => PROJECT_BUILD_PATHS


# list paths discovered at load time
namespace :paths do
  
  desc "List all test paths."
  task :test do
    COLLECTION_PATHS_TEST.sort.each { |path| puts " - #{path}" }
  end
  
  desc "List all source paths."
  task :source do
    COLLECTION_PATHS_SOURCE.sort.each { |path| puts " - #{path}" }
  end
  
  desc "List all include paths."
  task :include do
    COLLECTION_PATHS_INCLUDE.sort.each { |path| puts " - #{path}" }
  end    
  
end