# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/includes'

class Preprocessinator

  constructor :preprocessinator_includes_handler,
              :preprocessinator_file_assembler,
              :file_path_utils,
              :tool_executor,
              :file_wrapper,
              :plugin_manager,
              :configurator,
              :loginator,
              :reportinator


  def setup
    # Aliases
    @includes_handler = @preprocessinator_includes_handler
    @file_assembler = @preprocessinator_file_assembler

    # Thread-safe per-file locking for YAML cache operations
    # Key: includes list filepath (String), Value: Mutex
    @file_locks = {}
    @file_locks_mutex = Mutex.new

    @directives_only_available = true
  end

  def directives_only_available?
    return @directives_only_available
  end

  # Extract bare includes (does not differentiate user/system) from a file
  def preprocess_bare_includes(filepath:, test:, search_paths:, flags:, defines:)
    # Pass-through
    return @includes_handler.extract_bare_includes(
      filepath:      filepath,
      test:          test,
      flags:         flags,
      search_paths:  search_paths,
      defines:       defines
      )
  end

  def generate_directives_only_output(filepath:, test:, flags:, include_paths:, vendor_paths:, defines:)
    preprocessed_filepath = @file_path_utils.form_preprocessed_file_directives_only_filepath( filepath, test )

    # Run GCC with directives-only preprocessor expansion
    command = @tool_executor.build_command_line(
      @configurator.tools_test_file_directives_only_preprocessor,
      # Additional arguments
      flags,
      # Argument replacement
      filepath,
      preprocessed_filepath,
      defines,
      (include_paths + vendor_paths)
    )
    command[:options][:boom] = false
    results = @tool_executor.exec( command )

    # Handle warning from preprocessor saying that clang can't handle directives-only (common with older clang)
    if results[:output].match /warning[^\n]+-fdirectives-only/
      msg = "Ceedling will rely on fallback details extraction because your C preprocessor lacks support for directives-only output"
      @loginator.log( msg, Verbosity::WARNING )
      @directives_only_available = false
      return nil

    elsif results[:exit_code] != 0
      msg = "Ceedling will rely on fallback details extraction because C preprocessing failed for #{filepath}"
      @loginator.log(msg, Verbosity::WARNING)
      return nil
    end

    return preprocessed_filepath
  end

  # Extract system includes from a file
  def preprocess_system_includes(filepath:, directives_only_filepath:, fallback: false)
    name = File.basename(filepath)

    # Pass-through
    return @includes_handler.extract_system_includes(
      name:                   name,
      filepath:               filepath,
      preprocessed_filepath:  directives_only_filepath,
      fallback:               fallback
      )
  end

  def store_includes_list(test:, filepath:, includes:)
    _filepath = @file_path_utils.form_preprocessed_includes_list_filepath( filepath, test )

    # Get or create a mutex for this specific cache file
    file_lock = @file_locks_mutex.synchronize do
      @file_locks[_filepath] ||= Mutex.new
    end

    file_lock.synchronize do
      @includes_handler.write_includes_list( _filepath, includes )
    end
  end

  def cached_includes_list?(test:, filepath:)
    _filepath = @file_path_utils.form_preprocessed_includes_list_filepath( filepath, test )

    # Get or create a mutex for this specific cache file
    file_lock = @file_locks_mutex.synchronize do
      @file_locks[_filepath] ||= Mutex.new
    end

    file_lock.synchronize do
      # If existing YAML file of includes is newer than the file we're processing, skip preprocessing
      return @file_wrapper.newer?( _filepath, filepath )
    end
  end

  def load_includes_list(test:, filepath:)
    includes = []

    _filepath = @file_path_utils.form_preprocessed_includes_list_filepath( filepath, test )

    # Get or create a mutex for this specific cache file
    file_lock = @file_locks_mutex.synchronize do
      @file_locks[_filepath] ||= Mutex.new
    end

    file_lock.synchronize do
      # If existing YAML file of includes is newer than the file we're processing, skip preprocessing
      if @file_wrapper.newer?( _filepath, filepath )
        msg = @reportinator.generate_module_progress(
          operation: "Loading #include statement listing file for",
          module_name: test,
          filename: File.basename(filepath)
          )
        @loginator.log( msg, Verbosity::OBNOXIOUS )
      
        includes = @includes_handler.load_includes_list( _filepath )

        header = "Loaded existing #include list from #{_filepath}"
        @loginator.log_list( includes, header, Verbosity::DEBUG )
      end
    end

    return !includes.empty?, includes
  end

  def preprocess_partial_header_file(
      test:,
      filepath:,
      directives_only_filepath:,
      fallback:,
      flags:,
      include_paths:,
      vendor_paths:,
      defines:
  )
    preprocessed_filepath = @file_path_utils.form_preprocessed_file_filepath( filepath, test )

    arg_hash = {
      test:                      test,
      filepath:                  filepath,
      directives_only_filepath:  directives_only_filepath,
      fallback:                  fallback,
      flags:                     flags,
      include_paths:             include_paths,
      vendor_paths:              vendor_paths,
      defines:                   defines
    }

    # Extract includes & log progress and details   
    includes = preprocess_file_common( **arg_hash )

    header = "Discovered #includes for Partial header from #{filepath}"
    @loginator.log_list( includes, header, Verbosity::OBNOXIOUS )
    
    arg_hash = {
      test:                      test,
      filepath:                  filepath,
      directives_only_filepath:  directives_only_filepath,
      fallback:                  fallback,
      flags:                     flags,
      include_paths:             include_paths,
      defines:                   defines,
      extras:                    false
    }

    contents, extras = @file_assembler.collect_header_file_contents( **arg_hash )

    arg_hash = {
      filename:              File.basename( filepath ),
      preprocessed_filepath: preprocessed_filepath,
      contents:              contents,
      extras:                extras,
      includes:              includes                       
    }

    # Create a reconstituted header file from preprocessing expansion and preserving any extras
    @file_assembler.assemble_preprocessed_header_file( **arg_hash )

    return preprocessed_filepath, includes
  end

  def preprocess_mockable_header_file(
      test:,
      filepath:,
      directives_only_filepath:,
      fallback:,
      flags:,
      include_paths:,
      vendor_paths:,
      defines:
  )
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
      test:                      test,
      filepath:                  filepath,
      directives_only_filepath:  directives_only_filepath,
      fallback:                  fallback,
      flags:                     flags,
      include_paths:             include_paths,
      vendor_paths:              vendor_paths,
      defines:                   defines
    }

    # Extract includes & log progress and details   
    includes = preprocess_file_common( **arg_hash )

    header = "Discovered #includes for mockable header from #{filepath}"
    @loginator.log_list( includes, header, Verbosity::OBNOXIOUS )

    arg_hash = {
      test:                      test,
      filepath:                  filepath,
      directives_only_filepath:  directives_only_filepath,
      fallback:                  fallback,
      flags:                     flags,
      include_paths:             include_paths,
      defines:                   defines,
      extras:                    (@configurator.cmock_treat_inlines == :include)
    }

    # `contents` & `extras` are arrays of text strings to be assembled in generating a new header file.
    # `extras` are macro definitions, pragmas, etc. needed for the special case of mocking `inline` function declarations.
    # `extras` are empty for any cases other than mocking `inline` function declarations
    # (We don't want to increase our chances of a badly generated file--extracting extras could fail in complex files.)
    contents, extras = @file_assembler.collect_header_file_contents( **arg_hash )

    arg_hash = {
      filename:              File.basename( filepath ),
      preprocessed_filepath: preprocessed_filepath,
      contents:              contents,
      extras:                extras,
      includes:              includes                       
    }

    # Create a reconstituted header file from preprocessing expansion and preserving any extras
    @file_assembler.assemble_preprocessed_header_file( **arg_hash )

    # Trigger post_mock_preprocessing plugin hook
    @plugin_manager.post_mock_preprocess( plugin_arg_hash )

    return preprocessed_filepath
  end

  def preprocess_partial_source_file(
      test:,
      filepath:,
      directives_only_filepath:,
      fallback:,
      flags:,
      include_paths:,
      vendor_paths:,
      defines:
  )
    preprocessed_filepath = @file_path_utils.form_preprocessed_file_filepath( filepath, test )

    arg_hash = {
      test:                      test,
      filepath:                  filepath,
      directives_only_filepath:  directives_only_filepath,
      fallback:                  fallback,
      flags:                     flags,
      include_paths:             include_paths,
      vendor_paths:              vendor_paths,
      defines:                   defines
    }

    # Extract includes & log progress and info
    includes = preprocess_file_common( **arg_hash )

    header = "Discovered #includes for Partial source from #{filepath}"
    @loginator.log_list( includes, header, Verbosity::OBNOXIOUS )

    arg_hash = {
      source_filepath:       filepath,
      test:                  test,
      flags:                 flags,
      include_paths:         include_paths,
      defines:               defines      
    }

    contents = @file_assembler.collect_source_file_contents( **arg_hash )

    arg_hash = {
      filename:              File.basename( filepath ),
      preprocessed_filepath: preprocessed_filepath,
      contents:              contents,
      extras:                [],
      includes:              includes                       
    }

    # Create a reconstituted test file from preprocessing expansion and preserving any extras
    @file_assembler.assemble_preprocessed_code_file( **arg_hash )

    return preprocessed_filepath, includes
  end

  def preprocess_test_file(
      test:,
      filepath:,
      directives_only_filepath:,
      fallback:,
      includes:,
      flags:,
      include_paths:,
      vendor_paths:,
      defines:
    )
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

    # NOTE: No call to `preprocess_file_common()` because we already have includes

    arg_hash = {
      test:                      test,
      filepath:                  filepath,
      directives_only_filepath:  directives_only_filepath,
      fallback:                  fallback,
      flags:                     flags,
      include_paths:             include_paths,
      defines:                   defines      
    }

    # `contents` & `extras` are arrays of text strings to be assembled in generating a new test file.
    # `extras` are test build directives TEST_SOURCE_FILE() and TEST_INCLUDE_PATH().
    contents, extras = @file_assembler.collect_test_file_contents( **arg_hash )

    arg_hash = {
      filename:              File.basename( filepath ),
      preprocessed_filepath: preprocessed_filepath,
      contents:              contents,
      extras:                extras,
      includes:              includes                       
    }

    # Create a reconstituted test file from preprocessing expansion and preserving any extras
    @file_assembler.assemble_preprocessed_code_file( **arg_hash )

    # Trigger post_test_preprocess plugin hook
    @plugin_manager.post_test_preprocess( plugin_arg_hash )

    return preprocessed_filepath
  end

  ### Private ###
  private

  def preprocess_file_common(
      test:,
      filepath:,
      directives_only_filepath:,
      fallback:,
      flags:,
      include_paths:,
      vendor_paths:,
      defines:
  )
    msg = @reportinator.generate_module_progress(
      operation: "Preprocessing",
      module_name: test,
      filename: File.basename(filepath)
    )
    @loginator.log( msg, Verbosity::NORMAL )

    includes = []
    success, includes = load_includes_list( test: test, filepath: filepath )

    if !success
      # Full preprocessing-based #include extraction with saving to YAML file
      # Extract bare includes
      bare_includes = @includes_handler.extract_bare_includes(
        filepath:      filepath,
        test:          test,
        flags:         flags,
        search_paths:  vendor_paths,
        defines:       defines
        )

      # Add extracted system includes
      system_includes = @includes_handler.extract_system_includes(
        name:                  test,
        filepath:              filepath,
        preprocessed_filepath: directives_only_filepath,
        fallback:              fallback
        )

      # Reconcile includes with overlapping information from imperfect extraction
      includes = Includes.reconcile( bare: bare_includes, system: system_includes )

      # Sanitize the final list and remove any includes that have been mocked
      Includes.sanitize!(includes) do |include, all|
        all.include?( "#{@configurator.cmock_mock_prefix}#{include.filename}" )
      end
    
      store_includes_list( filepath: filepath, test: test, includes: includes )
    end

    return includes
  end

end
