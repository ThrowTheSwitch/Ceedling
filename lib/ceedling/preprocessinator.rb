# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

class Preprocessinator

  constructor :preprocessinator_includes_handler,
              :preprocessinator_file_handler,
              :task_invoker,
              :file_finder,
              :file_path_utils,
              :file_wrapper,
              :plugin_manager,
              :configurator,
              :test_context_extractor,
              :loginator,
              :reportinator,
              :rake_wrapper


  def setup
    # Aliases
    @includes_handler = @preprocessinator_includes_handler
    @file_handler = @preprocessinator_file_handler

    # Thread-safe per-file locking for YAML cache operations
    # Key: includes_list_filepath (String), Value: Mutex
    @file_locks = {}
    @file_locks_mutex = Mutex.new
  end


  # Uses a simple version of preprocessing able to extract a good-enough list of includes
  def simple_preprocess_file_includes(filepath:, test:, flags:, include_paths:, vendor_paths:, defines:)
    includes = @includes_handler.simple_extract_includes(
      filepath:      filepath,
      test:          test,
      flags:         flags,
      include_paths: include_paths,
      vendor_paths:  vendor_paths,
      defines:       defines
      )

    header = "Extracted #include list from #{filepath}"
    @loginator.log_list( includes, header, Verbosity::DEBUG )
      
    return includes
  end


  def full_preprocess_file_includes(filepath:, test:, flags:, include_paths:, vendor_paths:, defines:)
    includes_list_filepath = @file_path_utils.form_preprocessed_includes_list_filepath( filepath, test )

    # Get or create a mutex for this specific cache file
    file_lock = @file_locks_mutex.synchronize do
      @file_locks[includes_list_filepath] ||= Mutex.new
    end

    includes = []

    # Wrap the entire check-read-or-extract-write operation in a mutex
    # This prevents race conditions when multiple threads process the same file
    file_lock.synchronize do
      # If existing YAML file of includes is newer than the file we're processing, skip preprocessing
      if @file_wrapper.newer?( includes_list_filepath, filepath )
        msg = @reportinator.generate_module_progress(
          operation: "Loading #include statement listing file for",
          module_name: test,
          filename: File.basename(filepath)
          )
        @loginator.log( msg, Verbosity::OBNOXIOUS )
      
        includes = @includes_handler.load_includes_list( includes_list_filepath )

        header = "Loaded existing #include list from #{includes_list_filepath}"
        @loginator.log_list( includes, header, Verbosity::DEBUG )

      # Full preprocessing-based #include extraction with saving to YAML file
      else
        includes = @includes_handler.full_extract_includes(
          filepath:      filepath,
          test:          test,
          flags:         flags,
          include_paths: include_paths,
          vendor_paths:  vendor_paths,
          defines:       defines
          )

        header = "Extracted #include list from #{filepath}"
        @loginator.log_list( includes, header, Verbosity::DEBUG )
      
        @includes_handler.write_includes_list( includes_list_filepath, includes )
      end
    end

    return includes
  end

  def preprocess_partial_header_file(filepath:, test:, flags:, include_paths:, vendor_paths:, defines:)
    preprocessed_filepath = @file_path_utils.form_preprocessed_file_filepath( filepath, test )

    arg_hash = {
      filepath:       filepath,
      test:           test,
      flags:          flags,
      include_paths:  include_paths,
      vendor_paths:   vendor_paths,
      defines:        defines
    }

    # Extract includes & log progress and details   
    includes = preprocess_file_common( **arg_hash )

    arg_hash = {
      source_filepath:       filepath,
      test:                  test,
      flags:                 flags,
      include_paths:         include_paths,
      defines:               defines,
      extras:                false
    }

    contents, extras = @file_handler.collect_header_file_contents( **arg_hash )

    arg_hash = {
      filename:              File.basename( filepath ),
      preprocessed_filepath: preprocessed_filepath,
      contents:              contents,
      extras:                extras,
      includes:              includes                       
    }

    # Create a reconstituted header file from preprocessing expansion and preserving any extras
    @file_handler.assemble_preprocessed_header_file( **arg_hash )

    return preprocessed_filepath, includes
  end

  def preprocess_mockable_header_file(filepath:, test:, flags:, include_paths:, vendor_paths:, defines:)
    preprocessed_filepath = @file_path_utils.form_preprocessed_file_filepath( filepath, test )

    plugin_arg_hash = {
      header_file:              filepath,
      preprocessed_header_file: preprocessed_filepath,
      test:                     test,
      flags:                    flags,
      include_paths:            include_paths,
      defines:                  defines      
    }

    # Trigger pre_mock_preprocessing plugin hook
    @plugin_manager.pre_mock_preprocess( plugin_arg_hash )

    arg_hash = {
      filepath:       filepath,
      test:           test,
      flags:          flags,
      include_paths:  include_paths,
      vendor_paths:   vendor_paths,
      defines:        defines
    }

    # Extract includes & log progress and details   
    includes = preprocess_file_common( **arg_hash )

    arg_hash = {
      source_filepath:       filepath,
      test:                  test,
      flags:                 flags,
      include_paths:         include_paths,
      defines:               defines,
      extras:                (@configurator.cmock_treat_inlines == :include)
    }

    # `contents` & `extras` are arrays of text strings to be assembled in generating a new header file.
    # `extras` are macro definitions, pragmas, etc. needed for the special case of mocking `inline` function declarations.
    # `extras` are empty for any cases other than mocking `inline` function declarations
    #  (We don't want to increase our chances of a badly generated file--extracting extras could fail in complex files.)
    contents, extras = @file_handler.collect_header_file_contents( **arg_hash )

    arg_hash = {
      filename:              File.basename( filepath ),
      preprocessed_filepath: preprocessed_filepath,
      contents:              contents,
      extras:                extras,
      includes:              includes                       
    }

    # Create a reconstituted header file from preprocessing expansion and preserving any extras
    @file_handler.assemble_preprocessed_header_file( **arg_hash )

    # Trigger post_mock_preprocessing plugin hook
    @plugin_manager.post_mock_preprocess( plugin_arg_hash )

    return preprocessed_filepath
  end

  def preprocess_partial_source_file(filepath:, test:, flags:, include_paths:, vendor_paths:, defines:)
    preprocessed_filepath = @file_path_utils.form_preprocessed_file_filepath( filepath, test )

    arg_hash = {
      filepath:      filepath,
      test:          test,
      flags:         flags,
      include_paths: include_paths,
      vendor_paths:  vendor_paths,
      defines:       defines
    }

    # Extract includes & log progress and info
    includes = preprocess_file_common( **arg_hash )

    arg_hash = {
      source_filepath:       filepath,
      test:                  test,
      flags:                 flags,
      include_paths:         include_paths,
      defines:               defines      
    }

    # TODO: Use TBD new method for collecting a fully preprocessed C file
    contents, _ = @file_handler.collect_test_file_contents( **arg_hash )

    arg_hash = {
      filename:              File.basename( filepath ),
      preprocessed_filepath: preprocessed_filepath,
      contents:              contents,
      extras:                [],
      includes:              includes                       
    }

    # Create a reconstituted test file from preprocessing expansion and preserving any extras
    @file_handler.assemble_preprocessed_source_file( **arg_hash )

    return preprocessed_filepath, includes
  end

  def preprocess_test_file(filepath:, test:, flags:, include_paths:, vendor_paths:, defines:)
    preprocessed_filepath = @file_path_utils.form_preprocessed_file_filepath( filepath, test )

    plugin_arg_hash = {
      test_file:              filepath,
      preprocessed_test_file: preprocessed_filepath,
      test:                   test,
      flags:                  flags,
      include_paths:          include_paths,
      defines:                defines      
    }

    # Trigger pre_test_preprocess plugin hook
    @plugin_manager.pre_test_preprocess( plugin_arg_hash )

    arg_hash = {
      filepath:      filepath,
      test:          test,
      flags:         flags,
      include_paths: include_paths,
      vendor_paths:  vendor_paths,
      defines:       defines
    }

    # Extract includes & log progress and info
    includes = preprocess_file_common( **arg_hash )

    arg_hash = {
      source_filepath:       filepath,
      test:                  test,
      flags:                 flags,
      include_paths:         include_paths,
      defines:               defines      
    }

    # `contents` & `extras` are arrays of text strings to be assembled in generating a new test file.
    # `extras` are test build directives TEST_SOURCE_FILE() and TEST_INCLUDE_PATH().
    contents, extras = @file_handler.collect_test_file_contents( **arg_hash )

    arg_hash = {
      filename:              File.basename( filepath ),
      preprocessed_filepath: preprocessed_filepath,
      contents:              contents,
      extras:                extras,
      includes:              includes                       
    }

    # Create a reconstituted test file from preprocessing expansion and preserving any extras
    @file_handler.assemble_preprocessed_source_file( **arg_hash )

    # Trigger post_test_preprocess plugin hook
    @plugin_manager.post_test_preprocess( plugin_arg_hash )

    return preprocessed_filepath
  end

  ### Private ###
  private

  def preprocess_file_common(filepath:, test:, flags:, include_paths:, vendor_paths:, defines:)
    msg = @reportinator.generate_module_progress(
      operation: "Preprocessing",
      module_name: test,
      filename: File.basename(filepath)
    )

    @loginator.log( msg, Verbosity::NORMAL )

    # Extract includes
    includes = full_preprocess_file_includes(
      filepath:      filepath,
      test:          test,
      flags:         flags,
      include_paths: include_paths,
      vendor_paths:  vendor_paths,
      defines:       defines
    ) 

    return includes
  end

end
