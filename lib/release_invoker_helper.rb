

class ReleaseInvokerHelper

  constructor :configurator, :dependinator, :task_invoker


  def process_auxiliary_dependencies(dependencies_list)
    return if (not @configurator.project_use_auxiliary_dependencies)

    @dependinator.enhance_release_file_dependencies( dependencies_list )
    @task_invoker.invoke_release_dependencies_files( dependencies_list )
    @dependinator.load_release_object_deep_dependencies( dependencies_list )
  end

end
