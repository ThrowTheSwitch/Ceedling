# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/includes/includes'
require 'ceedling/exceptions'

class Preprocessinator

  constructor(
    :preprocessinator_includes_handler,
    :preprocessinator_comment_stripper,
    :preprocessinator_file_assembler,
    :preprocessinator_reconstructor,
    :file_path_utils,
    :tool_executor,
    :file_wrapper,
    :plugin_manager,
    :configurator,
    :loginator,
    :reportinator
  )

  def setup
    # Aliases
    @includes_handler = @preprocessinator_includes_handler
    @file_assembler = @preprocessinator_file_assembler
    @comment_stripper = @preprocessinator_comment_stripper
    @reconstructor = @preprocessinator_reconstructor

    # Thread-safe per-file locking for YAML cache operations
    # Key: includes list filepath (String), Value: Mutex
    @file_locks = {}
    @file_locks_mutex = Mutex.new
  end

  # Extract bare includes (does not differentiate user/system) from a file.
  # Called externally.
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
    raw_preprocessed_filepath = 
      @file_path_utils.form_preprocessed_file_raw_directives_only_filepath( filepath, test )

    compacted_preprocessed_fileapth =
      @file_path_utils.form_preprocessed_file_compacted_directives_only_filepath( filepath, test )

    # Run GCC with directives-only preprocessor expansion
    command = @tool_executor.build_command_line(
      @configurator.tools_test_file_directives_only_preprocessor,
      # Additional arguments
      flags,
      # Argument replacement
      filepath,
      raw_preprocessed_filepath,
      defines,
      (include_paths + vendor_paths)
    )
    command[:options][:boom] = false
    results = @tool_executor.exec( command )

    # Preprocessor did not succeed
    if results[:exit_code] != 0
      msg = "Failed to generate directive-only preprocessor output (fallback methods will be used) for #{filepath}"
      @loginator.log( msg, Verbosity::OBNOXIOUS, LogLabels::ERROR )
      return nil
    end

    # Remove comments from directives-only file in filesystem.
    # Directives-only output keeps our most essential details (include directives & macros) and handles #ifdefs, etc.
    # However, it does not strip out comments.
    @comment_stripper.strip_file( raw_preprocessed_filepath )

    # Collect all code from between line markers into a clean file
    @reconstructor.compact_file_from_expansion(
      input_filepath: raw_preprocessed_filepath,
      source_filepath: filepath,
      output_filepath: compacted_preprocessed_fileapth
    )

    return raw_preprocessed_filepath
  end

  # Extract user includes from a file using directives-only output (or text-only fallback).
  # Called externally and internally by `preprocess_common`.
  def preprocess_user_includes(name:, filepath:, directives_only_filepath:, fallback: false, defines: [])
    includes = []

    if !fallback
      includes = @includes_handler.extract_user_includes_preprocess(
        name:                   name,
        filepath:               filepath,
        preprocessed_filepath:  directives_only_filepath
      )
    else
      includes = @includes_handler.extract_user_includes_from_text(
        name:     name,
        filepath: filepath,
        defines:  defines
      )
    end

    header = "Extracted user #includes from #{filepath}:"
    @loginator.log_list( includes, header, Verbosity::DEBUG )

    return includes
  end

  # Extract system includes from a file using directives-only output (or text-only fallback).
  # Called externally and internally by `preprocess_common`.
  def preprocess_system_includes(name:, filepath:, directives_only_filepath:, fallback: false, defines: [])
    includes = []

    if !fallback
      includes = @includes_handler.extract_system_includes_preprocess(
        name:                   name,
        filepath:               filepath,
        preprocessed_filepath:  directives_only_filepath
      )
    else
      includes = @includes_handler.extract_system_includes_from_text(
        name:     name,
        filepath: filepath,
        defines:  defines
      )
    end

    header = "Extracted system #includes from #{filepath}:"
    @loginator.log_list( includes, header, Verbosity::DEBUG )

    return includes
  end

  # Persists `includes` under a cache file keyed by `test`/`filepath` so
  # `load_includes_list` can recall it later. Independent callers share this
  # pair of methods against different `filepath`s, each gated its own way:
  #  - Stage 4 (test_build_setup.rb), for a test file's own bare-includes list
  #    -- DependencyTracker-gated there, so this write only happens when that
  #    stage has already determined its target is stale.
  #  - `preprocess_file_includes_common` below, for a Partial header/source
  #    file's includes -- gated by this class's own `cached_includes_list?`
  #    mtime check.
  #  - The same method, for a mocked header's includes -- DependencyTracker-
  #    gated one level up in stage 9 (test_build_executor.rb) instead, via
  #    `use_cache: false` (see `preprocess_mockable_header_file` below).
  # Caller-gated either way: this method itself performs no freshness check.
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

  # Recalls an includes list previously written by `store_includes_list`.
  # Caller-gated: only meaningful once the caller has already established
  # freshness some other way (see `store_includes_list` above for the
  # different mechanisms in play), since no freshness check is performed here.
  def load_includes_list(test:, filepath:)
    _filepath = @file_path_utils.form_preprocessed_includes_list_filepath( filepath, test )

    # Get or create a mutex for this specific cache file
    file_lock = @file_locks_mutex.synchronize do
      @file_locks[_filepath] ||= Mutex.new
    end

    file_lock.synchronize do
      msg = @reportinator.generate_module_progress(
        operation: "Loading #include statement listing file for",
        module_name: test,
        filename: File.basename(filepath)
        )
      @loginator.log( msg, Verbosity::OBNOXIOUS )

      includes = @includes_handler.load_includes_list( _filepath )

      header = "Loaded existing #include list from #{_filepath}:"
      @loginator.log_list( includes, header, Verbosity::DEBUG )

      includes
    end
  end

  def preprocess_mockable_header_file(
      test:,
      filepath:,
      directives_only_filepath:,
      fallback:,
      flags:,
      include_paths:,
      vendor_paths:,
      defines:,
      extras: false
  )
    msg = @reportinator.generate_module_progress(
      operation: 'Preprocessing header file for follow-on mock handling',
      module_name: test,
      filename: File.basename( filepath )
    )
    @loginator.log( msg )

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

    # Extract includes & log progress and details.
    # `use_cache: false` -- stage_preprocess_mocks (test_build_executor.rb)
    # only ever calls this method once it has already determined, via its own
    # DependencyTracker target (antecedent + flags/defines/search_paths/extras
    # meta), that this header's preprocessing is stale. Reusing this class's
    # separate mtime-based cache on top of that would be redundant at best and
    # wrong at worst: it can't see a meta-only change (e.g. defines toggling
    # which #includes are active under #ifdef), so it could return an
    # includes list extracted under stale defines even though the caller
    # correctly identified this exact header/test pair as needing fresh work.
    includes = preprocess_file_includes_common( **arg_hash, use_cache: false )

    header = "Discovered #includes for mockable header from #{filepath}:"
    @loginator.log_list( includes, header, Verbosity::OBNOXIOUS )

    arg_hash = {
      test:                      test,
      filepath:                  filepath,
      directives_only_filepath:  directives_only_filepath,
      fallback:                  fallback,
      flags:                     flags,
      include_paths:             include_paths,
      defines:                   defines,
      extras:                    extras
    }

    # `contents` & `extras` are arrays of text strings to be assembled in generating a new header file.
    # `extras` are macro definitions, pragmas, etc. needed for the special case of mocking `inline` function declarations.
    # `extras` are empty for any cases other than mocking `inline` function declarations
    # (We don't want to increase our chances of a badly generated file--extracting extras could fail in complex files.)
    contents, extras, include_guard = @file_assembler.collect_mockable_header_file_contents( **arg_hash )

    arg_hash = {
      filename:              File.basename( filepath ),
      preprocessed_filepath: preprocessed_filepath,
      contents:              contents,
      extras:                extras,
      includes:              includes,
      include_guard:         include_guard
    }

    # Create a reconstituted header file from preprocessing expansion and preserving any extras
    @file_assembler.assemble_preprocessed_header_file( **arg_hash )

    # Trigger post_mock_preprocessing plugin hook
    @plugin_manager.post_mock_preprocess( plugin_arg_hash )

    return preprocessed_filepath
  end

  def preprocess_partial_header_file_preserve_macros(
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
      operation: 'Preprocessing header file for follow-on Partials handling',
      module_name: test,
      filename: File.basename( filepath )
    )
    @loginator.log( msg )

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
    includes = preprocess_file_includes_common( **arg_hash )

    header = "Discovered #includes for Partial header from #{filepath}:"
    @loginator.log_list( includes, header, Verbosity::OBNOXIOUS )

    contents =
      if fallback
        @file_assembler.collect_file_contents_fallback( source_filepath: filepath, defines: defines )
      else
        @file_assembler.collect_file_contents_from_directives_only_preprocessing( source_filepath: filepath, test: test )
      end

    # In fallback mode, #define macros are stripped from contents (all '#' lines skipped).
    # Re-extract them so the CExtractor can see them when parsing the reconstituted file.
    extras = fallback ? @file_assembler.collect_macros_and_pragmas_fallback( source_filepath: filepath, defines: defines ) : []

    arg_hash = {
      filename:              File.basename( filepath ),
      preprocessed_filepath: preprocessed_filepath,
      contents:              contents,
      extras:                extras,
      includes:              includes
    }

    # Create a reconstituted header file
    @file_assembler.assemble_preprocessed_header_file( **arg_hash )

    return preprocessed_filepath, includes
  end

  def preprocess_partial_source_file_preserve_macros(
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
      operation: 'Preprocessing source file for follow-on Partials handling',
      module_name: test,
      filename: File.basename( filepath )
    )
    @loginator.log( msg )

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
    includes = preprocess_file_includes_common( **arg_hash )

    header = "Discovered #includes for Partial source from #{filepath}:"
    @loginator.log_list( includes, header, Verbosity::OBNOXIOUS )

    contents =
      if fallback
        @file_assembler.collect_file_contents_fallback( source_filepath: filepath, defines: defines )
      else
        @file_assembler.collect_file_contents_from_directives_only_preprocessing( source_filepath: filepath, test: test )
      end

    # In fallback mode, #define macros are stripped from contents (all '#' lines skipped).
    # Re-extract them so the CExtractor can see them when parsing the reconstituted file.
    extras = fallback ? @file_assembler.collect_macros_and_pragmas_fallback( source_filepath: filepath, defines: defines ) : []

    arg_hash = {
      filename:              File.basename( filepath ),
      preprocessed_filepath: preprocessed_filepath,
      contents:              contents,
      extras:                extras,
      includes:              includes
    }

    # Create a reconstituted source file
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
    msg = @reportinator.generate_module_progress(
      operation: 'Preprocessing test file',
      module_name: test,
      filename: File.basename( filepath )
    )
    @loginator.log( msg )

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

    # NOTE: No call to `preprocess_file_includes_common()` because we already have includes

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

  def preprocess_partial_header_expand_macros(filepath:, test:, flags:, include_paths:, vendor_paths:, defines:)
    _preprocess_partial_expand_macros(
      filepath:      filepath,
      test:          test,
      flags:         flags,
      include_paths: include_paths,
      vendor_paths:  vendor_paths,
      defines:       defines
    )
  end

  def preprocess_partial_source_expand_macros(filepath:, test:, flags:, include_paths:, vendor_paths:, defines:)
    _preprocess_partial_expand_macros(
      filepath:      filepath,
      test:          test,
      flags:         flags,
      include_paths: include_paths,
      vendor_paths:  vendor_paths,
      defines:       defines
    )
  end

  ### Private ###
  private

  def _preprocess_partial_expand_macros(filepath:, test:, flags:, include_paths:, vendor_paths:, defines:)
    msg = @reportinator.generate_module_progress(
      operation: 'Full-preprocessing for expanded Partial signature extraction',
      module_name: test,
      filename: File.basename( filepath )
    )
    @loginator.log( msg )

    full_expansion_filepath = @file_path_utils.form_preprocessed_file_full_expansion_filepath( filepath, test )

    command = @tool_executor.build_command_line(
      @configurator.tools_test_file_full_preprocessor,
      flags,
      filepath,
      full_expansion_filepath,
      defines,
      (include_paths + vendor_paths)
    )
    result = @tool_executor.exec( command )

    if result[:exit_code] != 0
      msg = "Failed to generate full expansion for Partial signature extraction (directives-only signatures will be used) for #{filepath}"
      @loginator.log( msg, Verbosity::COMPLAIN )
      return nil
    end

    contents = @file_assembler.collect_file_contents_from_full_expansion( source_filepath: filepath, test: test )

    @file_assembler.assemble_preprocessed_code_file(
      filename:              File.basename( filepath ),
      preprocessed_filepath: full_expansion_filepath,
      contents:              contents,
      extras:                [],
      includes:              []
    )

    return full_expansion_filepath
  end

  # `use_cache:` lets a caller that has already established freshness some
  # other way (see `preprocess_mockable_header_file` above) skip this
  # method's own mtime-based `cached_includes_list?` check entirely, rather
  # than layering a second, less precise freshness check on top of a
  # decision the caller already made correctly.
  def preprocess_file_includes_common(
      test:,
      filepath:,
      directives_only_filepath:,
      fallback:,
      flags:,
      include_paths:,
      vendor_paths:,
      defines:,
      use_cache: true
  )
    msg = @reportinator.generate_module_progress(
      operation: "Extracting includes",
      module_name: test,
      filename: File.basename(filepath)
    )
    @loginator.log( msg, Verbosity::OBNOXIOUS )

    includes = []

    if use_cache && cached_includes_list?( test: test, filepath: filepath )
      includes = load_includes_list( test: test, filepath: filepath )
    else
      # Full preprocessing-based #include extraction with saving to YAML file

      # Extract bare includes
      bare_includes = @includes_handler.extract_bare_includes(
        filepath:      filepath,
        test:          test,
        flags:         flags,
        search_paths:  vendor_paths,
        defines:       defines
      )

      # Extract user includes
      user_includes = preprocess_user_includes(
        name:                     test,
        filepath:                 filepath,
        directives_only_filepath: directives_only_filepath,
        fallback:                 fallback,
        defines:                  defines
      )

      # Extract system includes
      system_includes = preprocess_system_includes(
        name:                     test,
        filepath:                 filepath,
        directives_only_filepath: directives_only_filepath,
        fallback:                 fallback,
        defines:                  defines
      )

      # Reconcile includes with overlapping information
      includes = Includes.reconcile(
        bare: bare_includes,
        user: user_includes,
        system: system_includes
      )

      # Sanitize the final list and remove any includes that have been mocked
      Includes.sanitize!(includes) do |include, all|
        all.include?( "#{@configurator.cmock_mock_prefix}#{include.filename}" )
      end
    
      store_includes_list( filepath: filepath, test: test, includes: includes )
    end

    return includes
  end

  # Self-contained mtime-based freshness check for the Partial header/source
  # file includes cache written/read by `store_includes_list`/
  # `load_includes_list` above, reached only via `preprocess_file_includes_common`
  # with its default `use_cache: true` -- i.e. only for Partials (stages 6-7),
  # which always run in full with no DependencyTracker gate of their own, so
  # this mtime check is that cache's only freshness signal. Mocked headers
  # (stage 9) bypass this check entirely (`use_cache: false`) in favor of the
  # DependencyTracker target that stage has already resolved.
  def cached_includes_list?(test:, filepath:)
    _filepath = @file_path_utils.form_preprocessed_includes_list_filepath( filepath, test )

    # Get or create a mutex for this specific cache file
    file_lock = @file_locks_mutex.synchronize do
      @file_locks[_filepath] ||= Mutex.new
    end

    file_lock.synchronize do
      # If existing YAML file of includes is newer than the file we're processing, skip preprocessing
      @file_wrapper.newer?( _filepath, filepath )
    end
  end

end
