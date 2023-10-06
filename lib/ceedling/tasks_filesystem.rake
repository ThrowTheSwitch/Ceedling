
# rather than require 'rake/clean' & try to override, we replicate for finer control
CLEAN   = Rake::FileList["**/*~", "**/*.bak"]
CLOBBER = Rake::FileList.new

CLEAN.clear_exclude.exclude { |fn| fn.pathmap("%f") == 'core' && File.directory?(fn) }

CLEAN.include(File.join(PROJECT_TEST_BUILD_OUTPUT_PATH, '*'))
CLEAN.include(File.join(PROJECT_TEST_RESULTS_PATH, '*'))
CLEAN.include(File.join(PROJECT_TEST_DEPENDENCIES_PATH, '*'))
CLEAN.include(File.join(PROJECT_BUILD_RELEASE_ROOT, '*.*'))
CLEAN.include(File.join(PROJECT_RELEASE_BUILD_OUTPUT_PATH, '*'))
CLEAN.include(File.join(PROJECT_RELEASE_DEPENDENCIES_PATH, '*'))

CLOBBER.include(File.join(PROJECT_BUILD_ARTIFACTS_ROOT, '**/*'))
CLOBBER.include(File.join(PROJECT_BUILD_TESTS_ROOT, '**/*'))
CLOBBER.include(File.join(PROJECT_BUILD_RELEASE_ROOT, '**/*'))
CLOBBER.include(File.join(PROJECT_LOG_PATH, '**/*'))

# just in case they're using git, let's make sure we allow them to preserved the build directory if desired.
CLOBBER.exclude(File.join(TESTS_BASE_PATH), '**/.gitkeep')

# because of cmock config, mock path can optionally exist apart from standard test build paths
CLOBBER.include(File.join(CMOCK_MOCK_PATH, '*'))

REMOVE_FILE_PROC = Proc.new { |fn| rm_r fn rescue nil }

# redefine clean so we can override how it advertises itself
desc "Delete all build artifacts and temporary products."
task(:clean) do
  # because :clean is a prerequisite for :clobber, intelligently display the progress message
  if (not @ceedling[:task_invoker].invoked?(/^clobber$/))
    @ceedling[:streaminator].stdout_puts("\nCleaning build artifacts...\n(For large projects, this task may take a long time to complete)\n\n")
  end
  CLEAN.each { |fn| REMOVE_FILE_PROC.call(fn) }
end

# redefine clobber so we can override how it advertises itself
desc "Delete all generated files (and build artifacts)."
task(:clobber => [:clean]) do
  @ceedling[:streaminator].stdout_puts("\nClobbering all generated files...\n(For large projects, this task may take a long time to complete)\n\n")
  CLOBBER.each { |fn| REMOVE_FILE_PROC.call(fn) }
end

# create a directory task for each of the paths, so we know how to build them
PROJECT_BUILD_PATHS.each { |path| directory(path) }

# create a single directory task which verifies all the others get built
task :directories => PROJECT_BUILD_PATHS

# list paths discovered at load time
namespace :paths do
  standard_paths = ['test', 'source', 'include', 'support']
  paths = @ceedling[:setupinator].config_hash[:paths].keys.map{|n| n.to_s.downcase}
  paths.each do |name|
    desc "List all collected #{name} paths." if standard_paths.include?(name)
    task(name.to_sym) do
      path_list = Object.const_get("COLLECTION_PATHS_#{name.upcase}")
      puts "#{name.capitalize} paths:"
      path_list.sort.each {|path| puts " - #{path}" }
      puts "path count: #{path_list.size}"
    end
  end
end


# list files & file counts discovered at load time
namespace :files do

  categories = ['tests', 'source', 'assembly', 'include', 'support']

  categories.each do |category|
    desc "List all collected #{category.chomp('s')} files."
    task(category.chomp('s').to_sym) do
      files_list = Object.const_get("COLLECTION_ALL_#{category.upcase}")
      puts "#{category.chomp('s').capitalize} files:"
      files_list.sort.each { |filepath| puts " - #{filepath}" }
      puts "file count: #{files_list.size}"
    end
  end

end


