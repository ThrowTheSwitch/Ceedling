
class Preprocessinator

  constructor :preprocessinator_includes_handler,
              :preprocessinator_file_handler,
              :task_invoker,
              :file_finder,
              :file_path_utils,
              :file_wrapper,
              :yaml_wrapper,
              :project_config_manager,
              :configurator,
              :test_context_extractor,
              :streaminator,
              :rake_wrapper


  def setup
    # Aliases
    @includes_handler = @preprocessinator_includes_handler
    @file_handler = @preprocessinator_file_handler
  end

  def extract_test_build_directives(filepath:)
    # Parse file in Ruby to extract build directives
    @streaminator.stdout_puts( "Parsing #{File.basename(filepath)}...", Verbosity::NORMAL)
    @test_context_extractor.collect_build_directives( filepath )
  end

  def extract_testing_context(filepath:, subdir:, flags:, include_paths:, defines:)
    # Parse file in Ruby to extract testing details (e.g. header files, mocks, etc.)
    if (not @configurator.project_use_test_preprocessor)
      @streaminator.stdout_puts( "Parsing & processing #include statements within #{File.basename(filepath)}...", Verbosity::NORMAL)
      @test_context_extractor.collect_testing_details( filepath )
    # Run test file through preprocessor to parse out include statements and then collect header files, mocks, etc.
    else
      includes = preprocess_shallow_includes(
        filepath:      filepath,
        subdir:        subdir,
        flags:         flags,
        include_paths: include_paths,
        defines:       defines)
      @streaminator.stdout_puts( "Processing #include statements for #{File.basename(filepath)}...", Verbosity::NORMAL)
      @test_context_extractor.ingest_includes_and_mocks( filepath, includes )
    end
  end

  def preprocess_shallow_includes(filepath:, subdir:, flags:, include_paths:, defines:)
    includes_list_filepath = @file_path_utils.form_preprocessed_includes_list_filepath( filepath, subdir )

    includes = []

    if @file_wrapper.newer?(includes_list_filepath, filepath)
      @streaminator.stdout_puts( "Loading existing #include statement listing file for #{File.basename(filepath)}...", Verbosity::NORMAL)
      includes = @yaml_wrapper.load(includes_list_filepath)
    else
      includes = @includes_handler.extract_includes(filepath:filepath, subdir:subdir, flags:flags, include_paths:include_paths, defines:defines)
      @includes_handler.write_shallow_includes_list(includes_list_filepath, includes)
    end

    return includes
  end

  def preprocess_file(filepath:, test:, flags:, include_paths:, defines:)
    # Extract shallow includes
    includes = preprocess_shallow_includes(
      filepath:      filepath,
      subdir:        test,
      flags:         flags,
      include_paths: include_paths,
      defines:       defines) 

    file = File.basename(filepath)
    @streaminator.stdout_puts(
      "Preprocessing #{file}#{" as #{test} build component" unless file.include?(test)}...",
      Verbosity::NORMAL)

    # Run file through preprocessor & further process result
    return @file_handler.preprocess_file(
      filepath:      filepath,
      subdir:        test,
      includes:      includes,
      flags:         flags,
      include_paths: include_paths,
      defines:       defines )
  end

  def preprocess_file_directives(filepath)
    @includes_handler.invoke_shallow_includes_list( filepath )
    @file_handler.preprocess_file_directives( filepath,
      @yaml_wrapper.load( @file_path_utils.form_preprocessed_includes_list_filepath( filepath ) ) )
  end
end
