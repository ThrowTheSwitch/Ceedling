

COLLECTION_ALL_RELEASE_DEPENDENCIES_FILES = COLLECTION_ALL_SOURCE.pathmap("#{PROJECT_RELEASE_DEPENDENCIES_PATH}/%n#{EXTENSION_DEPENDENCIES}")

# add to the base :release task
task :release => [:directories] + COLLECTION_ALL_RELEASE_DEPENDENCIES_FILES

namespace :build do

  COLLECTION_ALL_SOURCE.each do |source|
    # by source file name
    object = @ceedling[:file_path_utils].form_release_c_object_filepath(source)
    name   = File.basename(source)

    dependency_path = @ceedling[:file_path_utils].form_release_dependencies_filepath(source)
    @ceedling[:rake_wrapper].load_dependencies( dependency_path ) if (@ceedling[:file_wrapper].exist?(dependency_path) )
    
    task name.to_sym => [:directories, dependency_path]
  end

end
