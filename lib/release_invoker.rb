

class ReleaseInvoker

  constructor :configurator, :release_invoker_helper, :dependinator, :file_path_utils, :rake_wrapper


  def setup_and_invoke
    release_build_objects = []
    
    source_files = @configurator.collection_all_source.clone
    source_files << 'CException.c' if (@configurator.project_use_exceptions)
    
    release_build_objects.concat( @file_path_utils.form_release_c_objects_filelist )
    release_build_objects.concat( @file_path_utils.form_release_asm_objects_filelist )
    release_build_objects << @file_path_utils.form_release_c_object_filepath( 'CException.c' ) if (@configurator.project_use_exceptions)

    dependencies_list = @file_path_utils.form_release_dependencies_filelist( source_files )
    @release_invoker_helper.process_auxiliary_dependencies( dependencies_list )

    @dependinator.enhance_release_dependencies( release_build_objects )

    @rake_wrapper.create_file_task(PROJECT_RELEASE_BUILD_TARGET, release_build_objects)
    @rake_wrapper[PROJECT_RELEASE_BUILD_TARGET].invoke
  end

end
