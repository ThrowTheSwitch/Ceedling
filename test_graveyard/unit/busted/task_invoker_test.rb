require File.dirname(__FILE__) + '/../unit_test_helper'
require 'task_invoker'


class TaskInvokerTest < Test::Unit::TestCase

  def setup
    objects = create_mocks(:configurator, :rake_wrapper)
    create_mocks(:task1, :task2)
    @task_list = ['task1', 'task2']
    @task_invoker = TaskInvoker.new(objects)
  end

  def teardown
  end
  
  def invoke_helper(enhance=true)
    environment_files = ['tasks.rake', 'file_wrapper.rb']
    
    if (enhance)
      @rake_wrapper.expects(:[], @task_list[0]).returns(@task1)
      @configurator.expects.collection_code_generation_dependencies.returns(environment_files)
      @task1.expects.enhance(environment_files)
    end
    @rake_wrapper.expects(:[], @task_list[0]).returns(@task1)
    @task1.expects.invoke
    
    if (enhance)
      @rake_wrapper.expects(:[], @task_list[1]).returns(@task2)
      @configurator.expects.collection_code_generation_dependencies.returns(environment_files)
      @task2.expects.enhance(environment_files)
    end
    @rake_wrapper.expects(:[], @task_list[1]).returns(@task2)
    @task2.expects.invoke
  end


  should "enhance dependencies and invoke mocks" do
    invoke_helper
    @task_invoker.invoke_mocks(@task_list)
  end

  should "enhance dependencies and invoke runners" do
    invoke_helper
    @task_invoker.invoke_runners(@task_list)
  end

  should "enhance dependencies and invoke shallow include lists" do
    invoke_helper
    @task_invoker.invoke_shallow_include_lists(@task_list)
  end

  should "enhance dependencies and invoke preprocessed files" do
    invoke_helper
    @task_invoker.invoke_preprocessed_files(@task_list)
  end

  should "enhance dependencies and invoke auxiliary dependencies" do
    invoke_helper
    @task_invoker.invoke_dependencies_files(@task_list)
  end

  should "not enhance dependencies and invoke results" do
    invoke_helper(false)
    @task_invoker.invoke_results(@task_list)
  end


end
