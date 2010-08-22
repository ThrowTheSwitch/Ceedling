require File.dirname(__FILE__) + '/../unit_test_helper'
require 'test_invoker'


class TestInvokerTest < Test::Unit::TestCase

  def setup
    objects = create_mocks(:test_invoker_helper, :configurator, :preprocessinator, :task_invoker, :dependinator, :file_wrapper)
    create_mocks(:tests_list, :mocks_list, :runners_list, :pass_results_list, :fail_results_list)
    @test_invoker = TestInvoker.new(objects)
  end

  def teardown
  end
    
  
  should "run tests" do
    @file_wrapper.expects.instantiate_file_list(['project/tests/TestIng.c', 'project/tests/TestIcular.c']).returns(@tests_list)

    @configurator.expects.project_test_results_path.returns('project/build/results')
    @configurator.expects.extension_testfail.returns('.fail')
    @tests_list.expects.pathmap('project/build/results/%n.fail').returns(@fail_results_list)
    @configurator.expects.project_test_results_path.returns('project/build/results')
    @configurator.expects.extension_testpass.returns('.pass')
    @tests_list.expects.pathmap('project/build/results/%n.pass').returns(@pass_results_list)

    @test_invoker_helper.expects.clean_results({:force_run => true}, @fail_results_list, @pass_results_list)

    @preprocessinator.expects.preprocess_tests_and_invoke_mocks(@tests_list).returns(@mocks_list)

    @configurator.expects.project_test_runners_path.returns('project/build/runners')
    @configurator.expects.test_runner_file_suffix.returns('_runner')
    @tests_list.expects.pathmap('project/build/runners/%n_runner%x').returns(@runners_list)

    @task_invoker.expects.invoke_runners(@runners_list)

    @test_invoker_helper.expects.process_auxiliary_dependencies(@tests_list, @mocks_list, @runners_list)

    @dependinator.expects.setup_test_executable_dependencies(@tests_list)

    @task_invoker.expects.invoke_results(@pass_results_list)

    @test_invoker.setup_and_invoke(['project/tests/TestIng.c', 'project/tests/TestIcular.c'])
  end


end
