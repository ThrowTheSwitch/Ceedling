
class Preprocessinator

  attr_reader :preprocess_file_proc
  
  constructor :configurator, :preprocessinator_helper, :preprocessinator_includes_handler, :preprocessinator_file_handler, :task_invoker, :file_path_utils, :yaml_wrapper


  def setup
    # fashion ourselves a call back @preprocessinator_helper can use
    @preprocess_file_proc = Proc.new {|filepath| self.preprocess_file(filepath)}  
  end


  def preprocess_tests_and_invoke_mocks(tests)
    tests_list = @preprocessinator_helper.assemble_test_list(tests)
    
    @preprocessinator_helper.preprocess_includes(tests_list)
    mocks_list = @preprocessinator_helper.assemble_mocks_list

    @preprocessinator_helper.preprocess_mockable_headers(mocks_list, @preprocess_file_proc)

    @task_invoker.invoke_mocks(mocks_list)

    @preprocessinator_helper.preprocess_test_files(tests_list, @preprocess_file_proc)
    
    return mocks_list
  end

  def preprocess_shallow_includes(filepath)
    dependencies_rule = @preprocessinator_includes_handler.form_shallow_dependencies_rule(filepath)
    includes          = @preprocessinator_includes_handler.extract_shallow_includes(dependencies_rule)
    
    @preprocessinator_includes_handler.write_shallow_includes_list(
      @file_path_utils.form_preprocessed_includes_list_path(filepath), includes)
  end

  def preprocess_file(filepath)
    @preprocessinator_includes_handler.invoke_shallow_includes_list(filepath)
    @preprocessinator_file_handler.preprocess_file( filepath, @yaml_wrapper.load(@file_path_utils.form_preprocessed_includes_list_path(filepath)) )
  end

  def form_file_path(filepath)
    return @file_path_utils.form_preprocessed_file_path(filepath) if (@configurator.project_use_preprocessor)
    return filepath
  end

end
