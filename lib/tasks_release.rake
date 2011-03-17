require 'constants'
require 'file_path_utils'


desc "Build release target."
task RELEASE_CONTEXT => [:directories] do
  header = "Release build '#{File.basename(PROJECT_RELEASE_BUILD_TARGET)}'"
  @ceedling[:streaminator].stdout_puts("\n\n#{header}\n#{'-' * header.length}")  
  
  core_objects  = []
  extra_objects = @ceedling[:file_path_utils].form_release_build_c_objects_filelist( COLLECTION_RELEASE_ARTIFACT_EXTRA_LINK_OBJECTS )
  
  @ceedling[:project_config_manager].process_release_config_change
  core_objects.concat( @ceedling[:release_invoker].setup_and_invoke_c_objects( COLLECTION_ALL_SOURCE ) )
  core_objects.concat( @ceedling[:release_invoker].setup_and_invoke_asm_objects( COLLECTION_ALL_ASSEMBLY ) )
  
  file( PROJECT_RELEASE_BUILD_TARGET => (core_objects + extra_objects) )
  Rake::Task[PROJECT_RELEASE_BUILD_TARGET].invoke
end


namespace RELEASE_CONTEXT do

  namespace :compile do
    COLLECTION_ALL_SOURCE.each do |source|
      name = File.basename( source )
      task name.to_sym => [:directories] do
        @ceedling[:project_config_manager].process_release_config_change
        @ceedling[:release_invoker].setup_and_invoke_c_objects( [source] )
      end
    end
  end

  namespace :assemble do
    COLLECTION_ALL_ASSEMBLY.each do |source|
      name = File.basename( source )
      task name.to_sym => [:directories] do
        @ceedling[:project_config_manager].process_release_config_change
        @ceedling[:release_invoker].setup_and_invoke_asm_objects( [source] )
      end
    end
  end

end