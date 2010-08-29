require 'constants'
require 'file_path_utils'


desc "Build release target."
task :release => [:directories] do
  objects = []
  
  @ceedling[:project_config_manager].process_release_config_change
  objects.concat( @ceedling[:release_invoker].setup_and_invoke_c_objects( COLLECTION_ALL_SOURCE ) )
  objects.concat( COLLECTION_RELEASE_ARTIFACT_EXTRA_LINK_OBJECTS )
  objects.concat( @ceedling[:release_invoker].setup_and_invoke_asm_objects( COLLECTION_ALL_ASSEMBLY ) )
  
  file( PROJECT_RELEASE_BUILD_TARGET => objects )
  Rake::Task[PROJECT_RELEASE_BUILD_TARGET].invoke
end


namespace :release do

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