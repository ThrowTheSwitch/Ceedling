require File.dirname(__FILE__) + '/../unit_test_helper'
require 'test_invoker_helper'


class TestInvokerHelperTest < Test::Unit::TestCase

  def setup
    objects = create_mocks(:configurator, :task_invoker, :dependinator, :file_path_utils, :file_finder, :file_wrapper)
    create_mocks(:tests_list, :sources_list, :mocks_list, :runners_list, :pass_results_list, :fail_results_list)
    create_mocks(:dependencies_list1, :dependencies_list2, :dependencies_list3, :dependencies_list4)
    @test_invoker_helper = TestInvokerHelper.new(objects)
  end

  def teardown
  end


  should "clean all result files" do
    @file_wrapper.expects.rm_f(@fail_results_list)
    @file_wrapper.expects.rm_f(@pass_results_list)
    
    @test_invoker_helper.clean_results({:force_run => true}, @fail_results_list, @pass_results_list)
  end

  should "clean only fail result files" do
    @file_wrapper.expects.rm_f(@fail_results_list)
    
    @test_invoker_helper.clean_results({:force_run => false}, @fail_results_list, @pass_results_list)    
  end

  should "process no auxiliary dependencies" do
    @configurator.expects.project_use_auxiliary_dependencies.returns(false)
    
    @test_invoker_helper.process_auxiliary_dependencies(@tests_list)
  end

  should "process auxiliary dependencies" do
    @configurator.expects.project_use_auxiliary_dependencies.returns(true)
    
    @file_finder.expects.find_sources_from_tests(@tests_list).returns(@sources_list)
    
    @file_path_utils.expects.form_dependencies_filelist(@tests_list).returns(@dependencies_list1)
    @task_invoker.expects.invoke_dependencies_files(@dependencies_list1)
    @dependinator.expects.setup_test_object_dependencies(@dependencies_list1)

    @file_path_utils.expects.form_dependencies_filelist(@sources_list).returns(@dependencies_list2)
    @task_invoker.expects.invoke_dependencies_files(@dependencies_list2)
    @dependinator.expects.setup_test_object_dependencies(@dependencies_list2)

    @file_path_utils.expects.form_dependencies_filelist(@mocks_list).returns(@dependencies_list3)
    @task_invoker.expects.invoke_dependencies_files(@dependencies_list3)
    @dependinator.expects.setup_test_object_dependencies(@dependencies_list3)

    @file_path_utils.expects.form_dependencies_filelist(@runners_list).returns(@dependencies_list4)
    @task_invoker.expects.invoke_dependencies_files(@dependencies_list4)
    @dependinator.expects.setup_test_object_dependencies(@dependencies_list4)

    @test_invoker_helper.process_auxiliary_dependencies(@tests_list, @mocks_list, @runners_list)
  end


end
