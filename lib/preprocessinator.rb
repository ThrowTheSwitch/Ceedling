
class Preprocessinator
  
  constructor :configurator, :preprocessinator_helper, :preprocessinator_includes_handler, :task_invoker, :file_path_utils


  def preprocess_tests_and_invoke_mocks(tests)
    test_list = @preprocessinator_helper.assemble_test_list(tests)
    
    @preprocessinator_helper.preprocess_includes(test_list)
    mocks_list = @preprocessinator_helper.assemble_mocks_list

    @preprocessinator_helper.preprocess_mockable_headers(mocks_list)

    @task_invoker.invoke_mocks(mocks_list)

    @preprocessinator_helper.preprocess_test_files(test_list)
    
    return mocks_list
  end

  def preprocess_shallow_includes(filepath)
    dependencies_rule = @preprocessinator_includes_handler.form_shallow_dependencies_rule(filepath)
    includes          = @preprocessinator_includes_handler.extract_shallow_includes(dependencies_rule)
    
    @preprocessinator_includes_handler.write_shallow_includes_list(
      @file_path_utils.form_preprocessed_includes_list_path(filepath),
      includes)
  end

  def preprocess_file(filepath)
    @preprocessinator_helper.preprocess_file(filepath)
  end

  def form_file_path(filepath)
    return @file_path_utils.form_preprocessed_file_path(filepath) if (@configurator.project_use_preprocessor)
    return filepath
  end

end
