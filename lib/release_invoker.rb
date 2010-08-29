

class ReleaseInvoker

  constructor :configurator, :release_invoker_helper, :dependinator, :task_invoker, :file_path_utils


  def setup_and_invoke_c_objects(c_files)
    objects = ( @file_path_utils.form_release_build_c_objects_filelist( c_files ) )

    @release_invoker_helper.process_auxiliary_dependencies( @file_path_utils.form_release_dependencies_filelist( c_files ) )

    @dependinator.enhance_release_file_dependencies( objects )
    @task_invoker.invoke_release_objects( objects )

    return objects
  end


  def setup_and_invoke_asm_objects(asm_files)
    objects = @file_path_utils.form_release_build_asm_objects_filelist( asm_files )

    @dependinator.enhance_release_file_dependencies( objects )
    @task_invoker.invoke_release_objects( objects )
    
    return objects
  end

end
