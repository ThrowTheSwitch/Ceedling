
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
              :reportinator,
              :rake_wrapper


  def setup
    # Aliases
    @includes_handler = @preprocessinator_includes_handler
    @file_handler = @preprocessinator_file_handler
  end

  def extract_test_build_directives(filepath:)
    # Parse file in Ruby to extract build directives
    msg = @reportinator.generate_progress( "Parsing #{File.basename(filepath)}" )
    @streaminator.stdout_puts( msg, Verbosity::NORMAL )
    @test_context_extractor.collect_build_directives( filepath )
  end

  def extract_testing_context(filepath:, test:, flags:, include_paths:, defines:)
    if (not @configurator.project_use_test_preprocessor)
      # Parse file in Ruby to extract testing details (e.g. header files, mocks, etc.)
      msg = @reportinator.generate_progress( "Parsing & processing #include statements within #{File.basename(filepath)}" )
      @streaminator.stdout_puts( msg, Verbosity::NORMAL )
      @test_context_extractor.collect_includes( filepath )
    else
      # Run test file through preprocessor to parse out include statements and then collect header files, mocks, etc.
      includes = preprocess_includes(
        filepath:      filepath,
        test:          test,
        flags:         flags,
        include_paths: include_paths,
        defines:       defines)

      msg = @reportinator.generate_progress( "Processing #include statements for #{File.basename(filepath)}" )
      @streaminator.stdout_puts( msg, Verbosity::NORMAL )

      @test_context_extractor.ingest_includes( filepath, includes )
    end
  end

  def preprocess_header_file(filepath:, test:, flags:, include_paths:, defines:)
    # Extract shallow includes & print status message
    includes = preprocess_file_common(
      filepath:      filepath,
      test:          test,
      flags:         flags,
      include_paths: include_paths,
      defines:       defines
      )

    # Run file through preprocessor & further process result
    return @file_handler.preprocess_header_file(
      filepath:      filepath,
      subdir:        test,
      includes:      includes,
      flags:         flags,
      include_paths: include_paths,
      defines:       defines
      )
  end

  def preprocess_test_file(filepath:, test:, flags:, include_paths:, defines:)
    # Extract shallow includes & print status message
    includes = preprocess_file_common(
      filepath:      filepath,
      test:          test,
      flags:         flags,
      include_paths: include_paths,
      defines:       defines
      )

    # Run file through preprocessor & further process result
    return @file_handler.preprocess_test_file(
      filepath:      filepath,
      subdir:        test,
      includes:      includes,
      flags:         flags,
      include_paths: include_paths,
      defines:       defines
      )
  end

  def preprocess_file_directives(filepath)
    @includes_handler.invoke_shallow_includes_list( filepath )
    @file_handler.preprocess_file_directives( filepath,
      @yaml_wrapper.load( @file_path_utils.form_preprocessed_includes_list_filepath( filepath ) ) )
  end

  ### Private ###
  private

  def preprocess_file_common(filepath:, test:, flags:, include_paths:, defines:)
    msg = @reportinator.generate_module_progress(
      operation: "Preprocessing",
      module_name: test,
      filename: File.basename(filepath)
    )

    @streaminator.stdout_puts(msg, Verbosity::NORMAL)

    # Extract includes
    includes = preprocess_includes(
      filepath:      filepath,
      test:          test,
      flags:         flags,
      include_paths: include_paths,
      defines:       defines) 

    return includes
  end

  def preprocess_includes(filepath:, test:, flags:, include_paths:, defines:)
    includes_list_filepath = @file_path_utils.form_preprocessed_includes_list_filepath( filepath, test )

    includes = []

    if @file_wrapper.newer?(includes_list_filepath, filepath)
      msg = @reportinator.generate_module_progress(
        operation: "Loading #include statement listing file for",
        module_name: test,
        filename: File.basename(filepath)
        )
      @streaminator.stdout_puts( msg, Verbosity::NORMAL )
      includes = @yaml_wrapper.load(includes_list_filepath)
    else
      includes = @includes_handler.extract_includes(
        filepath:      filepath,
        test:          test,
        flags:         flags,
        include_paths: include_paths,
        defines:       defines
        )
      
      @includes_handler.write_includes_list(includes_list_filepath, includes)
    end

    return includes
  end

end
