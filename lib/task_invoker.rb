
class TaskInvoker

  constructor :rake_utils, :rake_wrapper

  def test_invoked?
    return @rake_utils.task_invoked?(/^#{TESTS_TASKS_ROOT_NAME}:/)
  end
  
  def release_invoked?
    return @rake_utils.task_invoked?(/^#{RELEASE_TASKS_ROOT_NAME}/)
  end

  def invoke_mocks(mocks)
    mocks.each { |mock| @rake_wrapper[mock].invoke }
  end
  
  def invoke_runner(runner)
    @rake_wrapper[runner].invoke
  end

  def invoke_shallow_include_lists(files)
    files.each { |file| @rake_wrapper[file].invoke }
  end

  def invoke_preprocessed_files(files)
    files.each { |file| @rake_wrapper[file].invoke }
  end

  def invoke_dependencies_files(files)
    files.each { |file| @rake_wrapper[file].invoke }
  end

  def invoke_objects(objects)
    objects.each { |object| @rake_wrapper[object].invoke }
  end

  def invoke_executable(executable)
      @rake_wrapper[executable].invoke
  end

  def invoke_results(results)
    results.each { |result| @rake_wrapper[result].invoke }
  end
  
end
