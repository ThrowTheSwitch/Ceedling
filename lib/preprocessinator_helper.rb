

class PreprocessinatorHelper
  
  constructor :configurator, :preprocessinator_includes_handler, :preprocessinator_file_handler, :test_includes_extractor, :task_invoker, :file_finder, :file_path_utils, :yaml_wrapper, :file_wrapper


  def assemble_test_list(test_list)
    return @file_path_utils.form_preprocessed_files_filelist(test_list) if (@configurator.project_use_preprocessor)
    return test_list
  end

  def preprocess_includes(test_list)
    if (@configurator.project_use_preprocessor)
      includes_lists = @file_path_utils.form_preprocessed_includes_list_filelist(test_list)
      @task_invoker.invoke_shallow_include_lists(includes_lists)
      @test_includes_extractor.parse_includes_lists(includes_lists)
    else
      @test_includes_extractor.parse_test_files(test_list)      
    end  
  end

  def assemble_mocks_list
    return @file_path_utils.form_mocks_filelist(@test_includes_extractor.lookup_all_mocks)
  end

  def preprocess_mockable_headers(mock_list)
    preprocess_files_smartly { @file_path_utils.form_preprocessed_mockable_headers_filelist(mock_list) }
  end

  def preprocess_test_files(test_list)
    preprocess_files_smartly { test_list }
  end
  
  def preprocess_file(filepath)
    @preprocessinator_includes_handler.invoke_shallow_includes_list(filepath)
    @preprocessinator_file_handler.preprocess_file(
      filepath,
      @yaml_wrapper.load(@file_path_utils.form_preprocessed_includes_list_path(filepath)))    
  end

  private ############################

  def preprocess_files_smartly
    if (@configurator.project_use_preprocessor)
      file_list = yield
      if (@configurator.project_use_auxiliary_dependencies)
        @task_invoker.invoke_preprocessed_files(file_list)
      else
        file_list.each { |file| preprocess_file( @file_finder.find_any_file(file) ) }
      end
    end        
  end

end
