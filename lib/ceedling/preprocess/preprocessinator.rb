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
    :file_wrapper,
    :tool_executor,
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

  # Extract bare includes (does not differentiate user/system) from a file, or nil when
  # the preprocessor failed. Called externally.
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

  # A file run with -fdirectives-only, which evaluates #if and follows #includes while
  # keeping macros and line markers. Gives the raw output's path, or nil when the
  # preprocessor fails so the caller falls back for this file alone. `tool_args` are the
  # run's flags:, include_paths:, vendor_paths:, and defines:.
  def generate_directives_only_output(filepath:, test:, **tool_args)
    raw    = ensure_output_dir( @file_path_utils.form_preprocessed_file_raw_directives_only_filepath( filepath, test ) )
    result = run_preprocessor( @configurator.tools_test_file_directives_only_preprocessor, filepath, raw, **tool_args )

    if @tool_executor.failed?( result )
      return log_failure( "Failed to generate directive-only preprocessor output (fallback methods will be used) for #{filepath}", Verbosity::OBNOXIOUS, LogLabels::ERROR )
    end

    strip_and_compact( filepath, test, raw )
    return raw
  end

  # Fallback's best-effort stand-in for directives-only output, from a preprocessor without
  # -fdirectives-only: a plain expansion whose line markers still name every file it
  # entered. Only those markers are read, so the expansion is neither stripped nor
  # compacted. Gives its path, or nil when the preprocessor fails.
  def generate_fallback_expansion_output(filepath:, test:, **tool_args)
    output = ensure_output_dir( @file_path_utils.form_preprocessed_file_fallback_expansion_filepath( filepath, test ) )
    result = run_preprocessor( @configurator.tools_test_file_full_preprocessor, filepath, output, **tool_args )

    if @tool_executor.failed?( result )
      return log_failure( "Failed to generate fallback preprocessor expansion (text-scan #includes will be used) for #{filepath}", Verbosity::OBNOXIOUS, LogLabels::ERROR )
    end

    return output
  end

  # Extract user includes from a file using directives-only output (or text-only fallback).
  # Called externally and internally by `preprocess_file_includes_common`.
  def preprocess_user_includes(name:, filepath:, directives_only_filepath:, fallback: false, defines: [])
    _preprocess_includes( :user, name: name, filepath: filepath,
                          directives_only_filepath: directives_only_filepath,
                          fallback: fallback, defines: defines )
  end

  # Extract system includes from a file using directives-only output (or text-only fallback).
  # Called externally and internally by `preprocess_file_includes_common`.
  def preprocess_system_includes(name:, filepath:, directives_only_filepath:, fallback: false, defines: [])
    _preprocess_includes( :system, name: name, filepath: filepath,
                          directives_only_filepath: directives_only_filepath,
                          fallback: fallback, defines: defines )
  end

  # Persists `includes` under a cache file keyed by `test`/`filepath` so
  # `load_includes_list` can recall it later. Independent callers share this
  # pair of methods against different `filepath`s, each already knowing its
  # target is stale before writing here:
  #  - Stage 4's first pass (TestBareIncludesExtractinator), for a test file's own
  #    bare-includes list.
  #  - `preprocess_file_includes_common` below, for a mocked header's or a
  #    Partial header/source file's includes -- called from stage 9 and
  #    stages 6/7 (test_build_executor.rb) respectively, both of which
  #    register their own DependencyTracker target and only call in once
  #    they've determined it stale.
  # This method itself performs no freshness check of its own.
  def store_includes_list(test:, filepath:, includes:)
    _filepath = ensure_output_dir(
      @file_path_utils.form_preprocessed_includes_list_filepath( filepath, test )
    )

    cache_file_lock( _filepath ).synchronize do
      @includes_handler.write_includes_list( _filepath, includes )
    end
  end

  # Recalls an includes list previously written by `store_includes_list`.
  # Caller-gated the same way (see `store_includes_list` above): meaningful
  # only once the caller has already established the target is not stale,
  # since no freshness check is performed here.
  def load_includes_list(test:, filepath:)
    _filepath = @file_path_utils.form_preprocessed_includes_list_filepath( filepath, test )

    cache_file_lock( _filepath ).synchronize do
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

    # Extract includes & log progress and details. stage_preprocess_mocks
    # (test_build_executor.rb) only ever calls this method once it has
    # already determined, via its own DependencyTracker target (antecedent +
    # flags/defines/search_paths/extras meta), that this header's
    # preprocessing is stale, so the extraction below always runs for real.
    includes = preprocess_file_includes_common( **arg_hash )

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
      filepath:              @file_path_utils.preprocessed_file_subpath( filepath ),
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
      filepath:              @file_path_utils.preprocessed_file_subpath( filepath ),
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

  # Runs a preprocessor `tool` over `filepath` into `output`. A file's own search paths
  # come ahead of vendor paths, so a project header wins a name clash. `boom: false` keeps
  # a failing run from raising: ToolExecutor#exec would otherwise stop the build before the
  # caller could fall back in its own way.
  def run_preprocessor(tool, filepath, output, flags:, include_paths:, vendor_paths:, defines:)
    command = @tool_executor.build_command_line( tool, flags, filepath, output, defines, (include_paths + vendor_paths) )
    command[:options][:boom] = false

    return @tool_executor.exec( command )
  end

  # Logs why a preprocessor run failed and gives the nil its caller returns
  def log_failure(msg, *log_args)
    @loginator.log( msg, *log_args )
    return nil
  end

  # Directives-only output keeps comments, so they are stripped before the code between
  # line markers is collected into a compacted file
  def strip_and_compact(filepath, test, raw)
    compacted = ensure_output_dir( @file_path_utils.form_preprocessed_file_compacted_directives_only_filepath( filepath, test ) )

    @comment_stripper.strip_file( raw )
    @reconstructor.compact_file_from_expansion( input_filepath: raw, source_filepath: filepath, output_filepath: compacted )
  end

  # Creates a preprocessed artifact's own directory and hands the path back, so a caller
  # wraps it around the path it is already assigning. The directory may not exist yet: an
  # artifact mirrors its source's own namespace, while a test's flat preprocess
  # directories are created with the rest of its build paths, before any source is known.
  # The preprocessor tools write their output directly and would otherwise fail.
  def ensure_output_dir(filepath)
    @file_wrapper.mkdir( File.dirname( filepath ) )
    return filepath
  end

  # One Mutex per includes-cache file, so concurrent testables serialize on the exact
  # file they touch and nothing more. The map itself is guarded by @file_locks_mutex.
  def cache_file_lock(cache_filepath)
    @file_locks_mutex.synchronize { @file_locks[cache_filepath] ||= Mutex.new }
  end

  # User and system include extraction differ only in which handler pair they call and
  # one word in the debug log. `kind` is :user or :system; the accurate line-marker
  # extraction runs unless `fallback`, in which case the original file's text is scanned.
  def _preprocess_includes(kind, name:, filepath:, directives_only_filepath:, fallback:, defines:)
    includes =
      if fallback
        @includes_handler.public_send(
          "extract_#{kind}_includes_from_text",
          name: name, filepath: filepath, defines: defines
        )
      else
        @includes_handler.public_send(
          "extract_#{kind}_includes_preprocess",
          name: name, filepath: filepath, preprocessed_filepath: directives_only_filepath
        )
      end

    @loginator.log_list( includes, "Extracted #{kind} #includes from #{filepath}:", Verbosity::DEBUG )
    includes
  end

  # A Partial's file in full expansion, reassembled in place as plain code. Nil when the
  # preprocessor fails, so its caller uses directives-only signatures instead.
  def _preprocess_partial_expand_macros(filepath:, test:, **tool_args)
    progress = { operation: 'Full-preprocessing for expanded Partial signature extraction', module_name: test, filename: File.basename( filepath ) }
    @loginator.log( @reportinator.generate_module_progress( **progress ) )

    output = ensure_output_dir( @file_path_utils.form_preprocessed_file_full_expansion_filepath( filepath, test ) )
    result = run_preprocessor( @configurator.tools_test_file_full_preprocessor, filepath, output, **tool_args )

    if @tool_executor.failed?( result )
      return log_failure( "Failed to generate full expansion for Partial signature extraction (directives-only signatures will be used) for #{filepath}", Verbosity::COMPLAIN )
    end

    assemble_full_expansion( filepath, test, output )
    return output
  end

  def assemble_full_expansion(filepath, test, output)
    contents = @file_assembler.collect_file_contents_from_full_expansion( source_filepath: filepath, test: test )
    @file_assembler.assemble_preprocessed_code_file(
      filename: File.basename( filepath ), preprocessed_filepath: output, contents: contents, extras: [], includes: []
    )
  end

  # Extracts, reconciles, and persists a header or source file's user/system
  # includes. Called only once a caller has already determined, via its own
  # DependencyTracker target, that this exact file/test pair is stale --
  # see `preprocess_mockable_header_file` above and stages 6/7 in
  # test_build_executor.rb -- so the extraction below always runs for real.
  def preprocess_file_includes_common(
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
      operation: "Extracting includes",
      module_name: test,
      filename: File.basename(filepath)
    )
    @loginator.log( msg, Verbosity::OBNOXIOUS )

    # Extract bare includes. The text scan below stands in for a failed run.
    bare_includes = @includes_handler.extract_bare_includes(
      filepath:      filepath,
      test:          test,
      flags:         flags,
      search_paths:  vendor_paths,
      defines:       defines
    ) || []

    # Fallback has no directives-only output to resolve computed #includes from
    bare_includes = supplement_with_text_includes( filepath: filepath, bare: bare_includes )
    unless fallback
      bare_includes = supplement_with_computed_includes(
        filepath: filepath, bare: bare_includes, directives_only_filepath: directives_only_filepath
      )
    end

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

    includes = reconcile_includes(
      bare: bare_includes, user: user_includes, system: system_includes, test_filepath: filepath
    )

    store_includes_list( filepath: filepath, test: test, includes: includes )

    return includes
  end

  # A bare list with the file's own literal #include lines added. The gcc bare pass runs
  # on an isolated copy that can never open another header, so an #include guarded by a
  # macro another header defines evaluates false there and drops out. The text scan
  # evaluates nothing and still lists it. Each added entry is only a candidate:
  # reconciliation keeps it only if the accurate directives-only pass also reports it.
  #
  # A supplement, not a replacement: gcc resolves an #include whose target is a macro
  # given on the command line, where a text scan finds no filename at all.
  def supplement_with_text_includes(filepath:, bare:)
    return union_includes( bare, @includes_handler.extract_bare_includes_from_text( filepath: filepath ) )
  end

  # A bare list with the #includes a macro names, as the preprocessor's line-marker output
  # resolved them. Neither bare pass sees one whose macro comes from another header: the
  # gcc pass can't open that header, and the text scan has no filename to find. The same
  # reconciliation safety applies. Without line-marker output there is nothing to add.
  def supplement_with_computed_includes(filepath:, bare:, directives_only_filepath:)
    computed = @includes_handler.extract_computed_includes( filepath: filepath, directives_only_filepath: directives_only_filepath )
    return union_includes( bare, computed )
  end

  # The user files a preprocessor's output entered, which that output depends on
  def preprocessed_dependencies(preprocessed_filepath:)
    return @includes_handler.extract_preprocessed_dependencies( preprocessed_filepath: preprocessed_filepath )
  end

  # The merge step every includes-reconciliation site shares: intersect a bare list
  # against the accurate user/system lists, log a NOTICE on any genuinely ambiguous
  # `#include` (more than one file on the search path satisfies it), and -- for the
  # mockable-header/Partial path -- drop a header whose mock is also present.
  # `preprocess_file_includes_common` above and stage 4's third pass
  # (TestIncludesReconcilinator) build their own three lists and own their own caching;
  # only this middle is common.
  def reconcile_includes(bare:, user:, system:, test_filepath:, drop_mocked: true)
    includes = Includes.reconcile(
      bare: bare, user: user, system: system, test_filepath: test_filepath
    ) do |bare_filepath, chosen, passed_over|
      msg = "Multiple files satisfy #include '#{bare_filepath}' within #{test_filepath}; chose '#{chosen}' " \
            "by search-path priority. Other candidates passed over: #{passed_over.join(', ')}. If this " \
            "choice is wrong, add more path to that #include statement to select a different file -- or " \
            "watch for a compilation error naming the real mismatch."
      @loginator.log( msg, Verbosity::COMPLAIN, LogLabels::NOTICE )
    end

    if drop_mocked
      Includes.sanitize!( includes ) do |include, all|
        all.include?( "#{@configurator.cmock_mock_prefix}#{include.filename}" )
      end
    end

    includes
  end

  # Deduplicated by filepath, not filename: two entries sharing only a basename, such as
  # "hw/config.h" and "app/config.h", are different files, and reconciliation tells them
  # apart by their resolved paths (Includes.reconcile)
  def union_includes(bare, more)
    return (bare + more).uniq( &:filepath )
  end

  # These sit beside the orchestration that first used them, but each is self-contained.
  # Stage 4's passes call the supplements, reconciliation, and dependency extraction, and
  # the integration tier drives `preprocess_file_includes_common` against real GCC output.
  public :preprocess_file_includes_common, :reconcile_includes, :supplement_with_text_includes, :supplement_with_computed_includes, :preprocessed_dependencies

end
