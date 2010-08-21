
# rather than require 'rake/clean' & try to override, we replicate for finer control
CLEAN   = Rake::FileList["**/*~", "**/*.bak"]
CLOBBER = Rake::FileList.new

CLEAN.clear_exclude.exclude { |fn| fn.pathmap("%f") == 'core' && File.directory?(fn) }

CLEAN.include(File.join(PROJECT_TEST_BUILD_OUTPUT_PATH, '*'))
CLEAN.include(File.join(PROJECT_TEST_RESULTS_PATH, '*'))
CLEAN.include(File.join(PROJECT_RELEASE_BUILD_OUTPUT_PATH, '*'))

CLOBBER.include(File.join(PROJECT_BUILD_ARTIFACTS_ROOT, '**/*'))
CLOBBER.include(File.join(PROJECT_BUILD_TESTS_ROOT, '**/*'))
CLOBBER.include(File.join(PROJECT_BUILD_RELEASE_ROOT, '**/*'))
CLOBBER.include(File.join(PROJECT_LOG_PATH, '**/*'))
CLOBBER.include(File.join(PROJECT_TEMP_PATH, '**/*'))

# because of cmock config, mock path can optionally exist apart from standard test build paths
CLOBBER.include(File.join(CMOCK_MOCK_PATH, '*'))

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
  
  paths = @ceedling[:setupinator].config_hash[:paths]
  paths.each_key do |section|
    name = section.to_s.downcase
    path_list = Object.const_get("COLLECTION_PATHS_#{name.upcase}")
    
    if (path_list.size != 0)
      desc "List all collected #{name} paths."
      task(name.to_sym) { puts "#{name} paths:"; path_list.sort.each {|path| puts " - #{path}" } }
    end
  end
end


# list files & file counts discovered at load time
namespace :files do
  
  categories = [
    ['test',   COLLECTION_ALL_TESTS],
    ['source', COLLECTION_ALL_SOURCE],
    ['header', COLLECTION_ALL_HEADERS],
    ]
  categories << ['assembly', COLLECTION_ALL_ASSEMBLY] if (RELEASE_BUILD_USE_ASSEMBLY)
  
  categories.each do |category|
    name       = category[0]
    collection = category[1]
    
    namespace(name.to_sym) do
      desc "List all collected #{name} files."
      task(:list) { puts "#{name} files:"; collection.sort.each {|filepath| puts " - #{filepath}" } }

      desc "List collected #{name} file count."
      task(:count) { puts "#{name} file count: #{collection.size}" }  
    end
  end
  
end


