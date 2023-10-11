require 'ceedling/constants'
require 'ceedling/file_path_utils'


desc "Build release target."
task RELEASE_SYM => [:directories] do
  header = "Release build '#{File.basename(PROJECT_RELEASE_BUILD_TARGET)}'"
  @ceedling[:streaminator].stdout_puts("\n\n#{header}\n#{'-' * header.length}")  
  
  begin
    @ceedling[:plugin_manager].pre_release

    core_objects  = []
    extra_objects = @ceedling[:file_path_utils].form_release_build_c_objects_filelist( COLLECTION_RELEASE_ARTIFACT_EXTRA_LINK_OBJECTS )

    @ceedling[:project_config_manager].process_release_config_change
    core_objects.concat( @ceedling[:release_invoker].setup_and_invoke_c_objects( COLLECTION_ALL_SOURCE ) )
  
    # If assembler use isn't enabled, COLLECTION_ALL_ASSEMBLY is empty array & nothing happens
    core_objects.concat( @ceedling[:release_invoker].setup_and_invoke_asm_objects( COLLECTION_ALL_ASSEMBLY ) )
  
    # If we're using libraries, we need to add those to our collection as well
    library_objects = (defined? LIBRARIES_RELEASE && !LIBRARIES_RELEASE.empty?) ? LIBRARIES_RELEASE.flatten.compact : []
    file( PROJECT_RELEASE_BUILD_TARGET => (core_objects + extra_objects + library_objects) )
    Rake::Task[PROJECT_RELEASE_BUILD_TARGET].invoke

  rescue StandardError => e
    @ceedling[:streaminator].stderr_puts("Error ==> #{e.class}:: #{e.message}")

    # Debug backtrace
    @ceedling[:streaminator].stderr_puts("Backtrace ==>", Verbosity::DEBUG)
    if @ceedling[:verbosinator].should_output?(Verbosity::DEBUG)
      $stderr.puts(e.backtrace) # Formats properly when directly passed to puts()
    end

  ensure
    @ceedling[:plugin_manager].post_release  
  end
end

