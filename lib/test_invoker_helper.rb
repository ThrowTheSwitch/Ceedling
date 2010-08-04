require 'rubygems'
require 'rake' # for ext()


class TestInvokerHelper

  constructor :configurator, :project_config_manager, :setupinator, :task_invoker, :dependinator, :file_path_utils, :file_wrapper, :rake_wrapper

  def clean_results(options, test)
    @file_wrapper.rm_f(@file_path_utils.form_fail_results_filepath(test))
    @file_wrapper.rm_f(@file_path_utils.form_pass_results_filepath(test)) if (options[:force_run])
  end

  def preprocessing_setup_for_runner(runner)
    return if (not @configurator.project_use_test_preprocessor)

    @rake_wrapper.create_file_task(
      runner,
      @file_path_utils.form_preprocessed_file_filepath( @file_path_utils.form_test_filepath_from_runner(runner) ))
  end

  def process_auxiliary_dependencies(files)
    return if (not @configurator.project_use_auxiliary_dependencies)

    dependencies_list = @file_path_utils.form_test_dependencies_filelist(files)
    @task_invoker.invoke_dependencies_files(dependencies_list)
    @dependinator.setup_test_object_dependencies(dependencies_list)
  end
  
  def cache_input_config
    # save our configuration to determine configuration changes upon next run
    @project_config_manager.cache_project_config( @configurator.project_test_build_cache_path, @setupinator.config_hash )    
  end
  
end
