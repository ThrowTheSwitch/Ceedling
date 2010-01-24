

class PreprocessinatorHelper
  
  constructor :configurator, :test_includes_extractor, :task_invoker, :file_finder, :file_path_utils


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

  def preprocess_mockable_headers(mock_list, preprocess_file_proc)
    if (@configurator.project_use_preprocessor)
      preprocess_files_smartly(
        @file_path_utils.form_preprocessed_mockable_headers_filelist(mock_list),
        preprocess_file_proc) { |file| @file_finder.find_mockable_header(file) }
    end
  end

  def preprocess_test_files(test_list, preprocess_file_proc)
    if (@configurator.project_use_preprocessor)
      preprocess_files_smartly(test_list, preprocess_file_proc) { |file| @file_finder.find_test_from_file_path(file) }
    end
  end
  
  private ############################

  def preprocess_files_smartly(file_list, preprocess_file_proc)
    if (@configurator.project_use_auxiliary_dependencies)
      @task_invoker.invoke_preprocessed_files(file_list)
    else
      file_list.each { |file| preprocess_file_proc.call( yield(file) ) }
    end
  end

end
