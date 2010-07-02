
# rather than require 'rake/clean' & try to override, we replicate for finer control
CLEAN   = Rake::FileList["**/*~", "**/*.bak"]
CLOBBER = Rake::FileList.new

CLEAN.clear_exclude.exclude { |fn| fn.pathmap("%f") == 'core' && File.directory?(fn) }

CLEAN.include(File.join(PROJECT_TEST_BUILD_OUTPUT_PATH, '*'))
CLEAN.include(File.join(PROJECT_TEST_RESULTS_PATH, '*'))
CLEAN.include(File.join(PROJECT_RELEASE_BUILD_OUTPUT_PATH, '*')) if (PROJECT_RELEASE_BUILD)

CLOBBER.include(File.join(PROJECT_BUILD_ARTIFACTS_ROOT, '**/*'))
CLOBBER.include(File.join(PROJECT_BUILD_TESTS_ROOT, '**/*'))
CLOBBER.include(File.join(PROJECT_BUILD_RELEASE_ROOT, '**/*')) if (PROJECT_RELEASE_BUILD)
CLOBBER.include(File.join(PROJECT_LOG_PATH, '**/*'))
CLOBBER.include(File.join(PROJECT_TEMP_PATH, '**/*'))

# because of cmock config, mock path can optionally exist apart from standard test build paths
CLOBBER.include(File.join(CMOCK_MOCK_PATH, '*')) if (PROJECT_USE_MOCKS)

REMOVE_FILE_PROC = Proc.new { |fn| rm_r fn rescue nil }

desc "Delete all compilation artifacts and temporary products."
task(:clean) { CLEAN.each { |fn| REMOVE_FILE_PROC.call(fn) } }

desc "Delete all generated files including compilation artifacts."
task(:clobber => [:clean]) { CLOBBER.each { |fn| REMOVE_FILE_PROC.call(fn) } }


PROJECT_BUILD_PATHS.each { |path| directory(path) }

# create directories that hold build output and generated files
task :directories => PROJECT_BUILD_PATHS


# list paths discovered at load time
namespace :paths do
  
  desc "List all test paths."
  task(:test)    { COLLECTION_PATHS_TEST.sort.each { |path| puts " - #{path}" } }
  
  desc "List all source paths."
  task(:source)  { COLLECTION_PATHS_SOURCE.sort.each { |path| puts " - #{path}" } }
  
  desc "List all include paths."
  task(:include) { COLLECTION_PATHS_INCLUDE.sort.each { |path| puts " - #{path}" } }
  
end