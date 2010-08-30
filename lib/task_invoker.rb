
class TaskInvoker

  constructor :dependinator, :rake_utils, :rake_wrapper

  def test_invoked?
    return @rake_utils.task_invoked?(/^#{TESTS_TASKS_ROOT_NAME}:/)
  end
  
  def release_invoked?
    return @rake_utils.task_invoked?(/^#{RELEASE_TASKS_ROOT_NAME}/)
  end

  def invoked?(regex)
    return @rake_utils.task_invoked?(regex)
  end

  
  def invoke_test_mocks(mocks)
    @dependinator.enhance_mock_dependencies( mocks )
    mocks.each { |mock| @rake_wrapper[mock].invoke }
  end
  
  def invoke_test_runner(runner)
    @dependinator.enhance_runner_dependencies( runner )
    @rake_wrapper[runner].invoke
  end

  def invoke_test_shallow_include_lists(files)
    @dependinator.enhance_shallow_include_lists_dependencies( files )
    files.each { |file| @rake_wrapper[file].invoke }
  end

  def invoke_test_preprocessed_files(files)
    @dependinator.enhance_preprocesed_file_dependencies( files )
    files.each { |file| @rake_wrapper[file].invoke }
  end

  def invoke_test_dependencies_files(files)
    @dependinator.enhance_dependencies_dependencies( files )
    files.each { |file| @rake_wrapper[file].invoke }
  end

  def invoke_test_results(results)
    @dependinator.enhance_results_dependencies( results )
    results.each { |result| @rake_wrapper[result].invoke }
  end


  def invoke_release_dependencies_files(files)
    files.each { |file| @rake_wrapper[file].invoke }
  end
  
  def invoke_release_objects(objects)
    objects.each { |object| @rake_wrapper[object].invoke }
  end
  
end
