require 'rubygems'
require 'rake' # for ext()


class TestInvoker

  constructor :test_invoker_helper, :configurator, :preprocessinator, :task_invoker, :dependinator, :file_finder, :file_wrapper
  attr_reader :source_list, :test_list, :mock_list

  def invoke_tests(tests, options={:force_run => true})
    @test_list        = @file_wrapper.instantiate_file_list(tests)
    fail_results_list = @test_list.pathmap("#{@configurator.project_test_results_path}/%n#{@configurator.extension_testfail}")
    pass_results_list = @test_list.pathmap("#{@configurator.project_test_results_path}/%n#{@configurator.extension_testpass}")

    @test_invoker_helper.clean_results(options, fail_results_list, pass_results_list)

    @mock_list   = @preprocessinator.preprocess_tests_and_invoke_mocks(@test_list)
    runner_list = @test_list.pathmap("#{@configurator.project_test_runners_path}/%n#{@configurator.test_runner_file_suffix}%x")
    @source_list = @file_finder.find_sources_from_tests(@test_list)

    @task_invoker.invoke_runners(runner_list)

    @test_invoker_helper.process_auxiliary_dependencies(@test_list, @source_list, @mock_list, runner_list)

    @dependinator.enhance_objects_with_environment_dependencies(@source_list)

    @dependinator.setup_executable_dependencies(@test_list)

    @task_invoker.invoke_results(pass_results_list)
  end

end
