
class TaskInvoker

  constructor :dependinator, :rake_wrapper


  def invoke_mocks(mocks)
    invoke_with_enhancements(mocks)
  end
  
  def invoke_runner(runner)
    invoke_with_enhancements(runner)
  end

  def invoke_shallow_include_lists(files)
    invoke_with_enhancements(files)    
  end

  def invoke_preprocessed_files(files)
    invoke_with_enhancements(files)
  end

  def invoke_dependencies_files(files)
    invoke_with_enhancements(files)
  end

  def invoke_results(results)
    # since everything needed to create results will have been regenerated
    # appropriately, there's no needed to enhance the dependencies -
    # they will always be superfluous
    @rake_wrapper[results].invoke
  end


  private #############################
  
  def invoke_with_enhancements(tasks)
    dependencies = @dependinator.test_environment_prerequisites
    
    tasks.each do |task|
      @rake_wrapper[task].enhance(dependencies)
      @rake_wrapper[task].invoke
    end
  end
  
end
