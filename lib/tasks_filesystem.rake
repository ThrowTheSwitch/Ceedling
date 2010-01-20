
CLEAN.include(EXTENSION_OBJECT)
CLEAN.include(EXTENSION_EXECUTABLE)
CLEAN.include(EXTENSION_TESTPASS)
CLEAN.include(EXTENSION_TESTFAIL)

CLOBBER.include(PROJECT_BUILD_PATHS.map{|path| File.join(path, '*')})


# create directories that hold build output and generated files
task :directories do
  
  PROJECT_BUILD_PATHS.each { |path| directory(path) }  
  PROJECT_BUILD_PATHS.each { |path| Rake::Task[path].invoke }
  
end


# list paths discovered at load time
namespace :paths do
  
  desc "List all test paths."
  task :test do
    COLLECTION_PATHS_TEST.each { |path| puts " - #{path}" }
  end
  
  desc "List all source paths."
  task :source do
    COLLECTION_PATHS_SOURCE.each { |path| puts " - #{path}" }
  end
  
  desc "List all include paths."
  task :include do
    COLLECTION_PATHS_INCLUDE.each { |path| puts " - #{path}" }
  end    
  
end