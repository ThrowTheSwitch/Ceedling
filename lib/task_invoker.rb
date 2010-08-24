
class TaskInvoker

  constructor :rake_wrapper


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

  def invoke_results(results)
    results.each { |result| @rake_wrapper[result].invoke }
  end
  
end
