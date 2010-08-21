

class ReleaseInvoker

  constructor :configurator, :dependinator, :file_path_utils, :rake_wrapper


  def setup_and_invoke
    release_build_components = []
    
    release_build_components.concat( @file_path_utils.form_release_c_objects_filelist )
    release_build_components.concat( @file_path_utils.form_release_asm_objects_filelist )
    release_build_components << @file_path_utils.form_release_c_object_filepath('CException.c') if (@configurator.project_use_exceptions)

    @dependinator.setup_release_objects_dependencies(release_build_components)

    @rake_wrapper.create_file_task(PROJECT_RELEASE_BUILD_TARGET, release_build_components)

    @rake_wrapper[PROJECT_RELEASE_BUILD_TARGET].invoke
  end

end
