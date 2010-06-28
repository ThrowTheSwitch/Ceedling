
release_build_components =
    (COLLECTION_ALL_SOURCE.pathmap("#{PROJECT_RELEASE_BUILD_OUTPUT_C_PATH}/%n#{EXTENSION_OBJECT}") + 
     COLLECTION_ALL_ASSEMBLY.pathmap("#{PROJECT_RELEASE_BUILD_OUTPUT_ASM_PATH}/%n#{EXTENSION_OBJECT}"))

release_build_components << @ceedling[:file_path_utils].form_release_c_object_filepath('CException.c') if (PROJECT_USE_EXCEPTIONS)


file PROJECT_RELEASE_BUILD_TARGET => release_build_components

desc "Build release target."
task :release => [:directories, PROJECT_RELEASE_BUILD_TARGET]

namespace :compile do
  COLLECTION_ALL_SOURCE.each do |source|
    # by source file name
    object = @ceedling[:file_path_utils].form_release_c_object_filepath(source)
    name   = File.basename(source)
    task name.to_sym => [:directories, object]
  end
end

namespace :assemble do
  COLLECTION_ALL_ASSEMBLY.each do |source|
    # by source file name
    object = @ceedling[:file_path_utils].form_release_asm_object_filepath(source)
    name   = File.basename(source)
    task name.to_sym => [:directories, object]
  end
end
