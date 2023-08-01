
class Preprocessinator

  constructor :preprocessinator_includes_handler,
              :preprocessinator_file_handler,
              :task_invoker,
              :file_finder,
              :file_path_utils,
              :yaml_wrapper,
              :project_config_manager,
              :configurator,
              :test_context_extractor,
              :rake_wrapper


  def setup
    # Aliases
    @includes_handler = @preprocessinator_includes_handler
    @file_handler = @preprocessinator_file_handler
  end

  def fetch_shallow_source_includes(test)
    return @test_context_extractor.lookup_source_includes_list(test)
  end

  def preprocess_test_file(test)
    # Extract all context from test file
    @test_context_extractor.parse_test_file(test)

    if (@configurator.project_use_test_preprocessor)
      preprocessed_includes_list = @file_path_utils.form_preprocessed_includes_list_filepath(test)
      preprocess_shallow_includes( @file_finder.find_test_from_file_path(preprocessed_includes_list) )
      # Replace includes & mocks context with preprocessing results
      @test_context_extractor.parse_includes_list(preprocessed_includes_list)
    end
  end

  def fetch_mock_list_for_test_file(test)
    return @file_path_utils.form_mocks_source_filelist( @test_context_extractor.lookup_raw_mock_list(test) )
  end

  def fetch_include_search_paths_for_test_file(test)
    return @test_context_extractor.lookup_include_paths_list(test)
  end

  def preprocess_mockable_header(mockable_header)
    if (@configurator.project_use_test_preprocessor)
      if (@configurator.project_use_deep_dependencies)
        @task_invoker.invoke_test_preprocessed_files([mockable_header])
      else
        preprocess_file(@file_finder.find_header_file(mockable_header)) 
      end
    end
  end

  def preprocess_remainder(test)
    if (@configurator.project_use_test_preprocessor)
      if (@configurator.project_use_preprocessor_directives)
        preprocess_file_directives(test)
      else
        preprocess_file(test)
      end
    end
  end

  def preprocess_shallow_includes(filepath)
    includes = @includes_handler.extract_includes(filepath)

    @includes_handler.write_shallow_includes_list(
      @file_path_utils.form_preprocessed_includes_list_filepath(filepath), includes)
  end

  def preprocess_file(filepath)
    # Attempt to directly run shallow includes instead of TODO@includes_handler.invoke_shallow_includes_list(filepath)
    pre = @file_path_utils.form_preprocessed_includes_list_filepath(filepath)
    if (@rake_wrapper[pre].needed?)
      src = @file_finder.find_test_or_source_or_header_file(pre)
      preprocess_shallow_includes(src) 
    end

    # Reload it and 
    includes = @yaml_wrapper.load(pre)
    @file_handler.preprocess_file( filepath, includes )
  end

  def preprocess_file_directives(filepath)
    @includes_handler.invoke_shallow_includes_list( filepath )
    @file_handler.preprocess_file_directives( filepath,
      @yaml_wrapper.load( @file_path_utils.form_preprocessed_includes_list_filepath( filepath ) ) )
  end
end
