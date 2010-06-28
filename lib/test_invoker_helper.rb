require 'rubygems'
require 'rake' # for ext()


class TestInvokerHelper

  constructor :configurator, :task_invoker, :dependinator, :file_finder, :file_path_utils, :file_wrapper, :rake_wrapper

  def clean_results(options, fail_results_list, pass_results_list)
    @file_wrapper.rm_f(fail_results_list)
    @file_wrapper.rm_f(pass_results_list) if (options[:force_run])
  end

  def preprocessing_setup_for_runners(runner_list)
    return if (not @configurator.project_use_test_preprocessor)

    runner_list.each do |runner|
      @rake_wrapper.create_file_task(runner, @file_path_utils.form_preprocessed_file_path( runner.sub(/#{TEST_RUNNER_FILE_SUFFIX}/, '') ))
    end
  end

  def process_auxiliary_dependencies(test_list, *more_lists)
    return if (not @configurator.project_use_auxiliary_dependencies)

    ([test_list] + more_lists).each do |file_list|
      dependencies_list = @file_path_utils.form_test_dependencies_filelist(file_list)
      @task_invoker.invoke_dependencies_files(dependencies_list)
      @dependinator.setup_object_dependencies(dependencies_list)
    end
  end
  
end
