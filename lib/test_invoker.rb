require 'rubygems'
require 'rake' # for ext()


class TestInvoker

  constructor :test_invoker_helper, :configurator, :preprocessinator, :task_invoker, :dependinator, :file_wrapper

  def invoke_tests(tests, options={:force_run => true})
    test_list         = @file_wrapper.instantiate_file_list(tests)
    fail_results_list = test_list.pathmap("#{@configurator.project_test_results_path}/%n#{@configurator.extension_testfail}")
    pass_results_list = test_list.pathmap("#{@configurator.project_test_results_path}/%n#{@configurator.extension_testpass}")

    @test_invoker_helper.clean_results(options, fail_results_list, pass_results_list)

    mock_list   = @preprocessinator.preprocess_tests_and_invoke_mocks(test_list)    
    runner_list = test_list.pathmap("#{@configurator.project_test_runners_path}/%n#{@configurator.test_runner_file_suffix}%x")

    @task_invoker.invoke_runners(runner_list)
    
    @test_invoker_helper.process_auxiliary_dependencies(test_list, mock_list, runner_list)
    
    @dependinator.setup_executable_dependencies(test_list)

    @task_invoker.invoke_results(pass_results_list)
  end
  
end
