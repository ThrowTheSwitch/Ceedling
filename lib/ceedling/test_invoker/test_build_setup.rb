# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/exceptions'
require 'ceedling/test_context_extractor'
require 'ceedling/includes/includes'
require 'ceedling/partials/partials'
require 'ceedling/test_invoker/test_invoker_types'
require 'ceedling/test_invoker/test_pipeline_helpers'
require 'ceedling/test_invoker/test_build_validations'
require 'ceedling/path_mirror'

class TestBuildSetup

  include TestInvokerTypes
  include TestPipelineHelpers
  include TestBuildValidations

  constructor(
    :configurator,
    :loginator,
    :reportinator,
    :batchinator,
    :test_context_extractor,
    :include_pathinator,
    :defineinator,
    :flaginator,
    :file_wrapper,
    :file_path_utils,
    :file_finder,
    :test_runner_manager,
    :dependinator,
    :test_search_paths,
    :mock_locator
  )

  def setup()
    @context_extractor = @test_context_extractor
  end

  # Stage 1: Create per-test build/results/mock/partial directory structure
  # and populate the testables hash with initial entries.
  def stage_prepare_build_paths(state)
    clean_test_roots = PathMirror.clean_roots( @configurator.paths_test )

    @batchinator.exec(workload: :compile, things: state.tests) do |filepath|
      filepath = filepath.to_s
      key  = testable_symbolize( filepath, clean_test_roots )
      name = key.to_s

      state.lock.synchronize do
        state.testables[key] = Testable.new(
          filepath:  filepath,
          name:      name,
          preprocess: {},
          paths:      {}
        )
      end

      testable = state.testables[key]
      paths = testable.paths

      # Assemble all needed testable build paths
      paths[:build]        = @file_path_utils.form_test_build_path( name, context: state.context )
      paths[:results]      = @file_path_utils.form_test_results_path( name, context: state.context )
      paths[:dependencies] = @file_path_utils.form_test_dependencies_path( name, context: state.context )
      paths[:runners]      = @file_path_utils.form_test_runners_path( name )

      if @configurator.project_use_mocks
        paths[:mocks] = @file_path_utils.form_test_mocks_path( name )
      end

      if @configurator.project_use_partials
        paths[:partials] = @file_path_utils.form_test_partials_path( name )
      end

      if @configurator.project_use_test_preprocessor != :none
        testable.preprocess[:includes]           = []
        testable.preprocess[:directives_only]    = { filepath: nil }
        testable.preprocess[:fallback_expansion] = { filepath: nil }

        paths[:preprocess_includes]                   = @file_path_utils.form_test_preprocess_includes_path( name )
        paths[:preprocess_files]                      = @file_path_utils.form_test_preprocess_files_path( name )
        paths[:preprocess_files_full_expansion]       = @file_path_utils.form_test_preprocess_files_full_expansion_path( name )
        paths[:preprocess_files_directives_only]      = @file_path_utils.form_test_preprocess_files_directives_only_path( name )
        paths[:preprocess_files_raw_directives_only]  = @file_path_utils.form_test_preprocess_files_raw_directives_only_path( name )
      end

      # A test file's own build directive macros are cached here regardless of whether
      # preprocessing is enabled, so this path is always present.
      paths[:preprocess_build_directives] = @file_path_utils.form_test_preprocess_build_directives_path( name )

      # Create all testable build paths
      testable.paths.each { |_, path| @file_wrapper.mkdir( path ) }
    end
  end

  # Stage 2: Collect includes, build directives, and test case context from each test file.
  #
  # A test file's #includes and Partials configuration are read fresh every run, since
  # they carry richer information than a simple cache can hold. Its build directive
  # macros -- TEST_INCLUDE_PATH() always, and (when preprocessing is off)
  # TEST_SOURCE_FILE() -- are plain lists of strings, so those are recalled from a small
  # cache instead of being scanned again when nothing about the file itself has changed.
  def stage_collect_test_context(state)
    skipped = 0

    @batchinator.exec(workload: :compile, things: state.testables) do |_, testable|
      filepath = testable.filepath
      filename = File.basename( filepath )

      cache_target = @file_path_utils.form_test_build_directives_cache_filepath( filepath, testable.name )
      @dependinator.register( cache_target, files: [filepath] )
      directives_stale = @dependinator.stale?( cache_target )

      contexts = [TestContextExtractor::Context::INCLUDES]

      if @configurator.project_use_test_preprocessor_tests
        msg = @reportinator.generate_progress( "Parsing #{filename} for user & system #includes (fallback for preprocessing failures)" )
        @loginator.log( msg )

        if directives_stale
          contexts << TestContextExtractor::Context::BUILD_DIRECTIVE_INCLUDE_PATHS

          msg = @reportinator.generate_progress( "Parsing #{filename} for include path build directive macros" )
          @loginator.log( msg )
        end

        msg = @reportinator.generate_progress( "Parsing #{filename} for Partials directive macros" )
        @loginator.log( msg )
        contexts << TestContextExtractor::Context::PARTIALS_CONFIGURATION
      else
        msg = @reportinator.generate_progress( "Parsing #{filename} for user & system #includes" )
        @loginator.log( msg )

        if directives_stale
          contexts << TestContextExtractor::Context::BUILD_DIRECTIVE_INCLUDE_PATHS
          contexts << TestContextExtractor::Context::BUILD_DIRECTIVE_SOURCE_FILES

          msg = @reportinator.generate_progress( "Parsing #{filename} for build directive macros" )
          @loginator.log( msg )
        end

        contexts << TestContextExtractor::Context::TEST_RUNNER_DETAILS

        msg = @reportinator.generate_progress( "Parsing #{filename} for test case names" )
        @loginator.log( msg )
      end

      unless directives_stale
        msg = @reportinator.generate_progress( "Recalling cached build directive macros for #{filename}" )
        @loginator.log( msg, Verbosity::OBNOXIOUS )
      end

      @context_extractor.collect_simple_context_from_file( filepath, nil, *contexts )

      if directives_stale
        @context_extractor.store_build_directives_cache( filepath: filepath, cache_filepath: cache_target )
        @dependinator.mark_fresh( cache_target )
      else
        @context_extractor.load_build_directives_cache( filepath: filepath, cache_filepath: cache_target )
        state.lock.synchronize { skipped += 1 }
      end

      validate_mocks_in_use(
        filename: filename,
        mocks:    @context_extractor.lookup_mock_header_includes_list( filepath )
      )

      validate_partials_in_use(
        filename:        filename,
        partials_in_use: !(@context_extractor.lookup_partials_config( filepath )).empty?,
        includes:        @context_extractor.lookup_all_header_includes_list( filepath )
      )

      testable.mock_search_paths = collect_mock_search_paths( testable )
    end

    log_skip_summary( task: "build directive macro scanning", count: skipped, noun: "test files" )

    process_project_include_paths()
  end

  # Stage 3: Collect flags, defines, and search paths for each test.
  def stage_ingest_configurations(state)
    fw_defines  = framework_defines()
    run_defines = runner_defines()

    @batchinator.exec(workload: :compile, things: state.testables) do |_, testable|
      filepath = testable.filepath

      srch_paths     = @test_search_paths.compose( filepath, testable.paths, testable.mock_search_paths )
      cmp_flags      = flags( context: state.context, operation: OPERATION_COMPILE_SYM,    filepath: filepath )
      pre_flags      = preprocess_flags( context: state.context, compile_flags: cmp_flags, filepath: filepath )
      asm_flags      = flags( context: state.context, operation: OPERATION_ASSEMBLE_SYM,   filepath: filepath )
      lnk_flags      = flags( context: state.context, operation: OPERATION_LINK_SYM,       filepath: filepath )
      cmp_defines    = compile_defines( context: state.context, filepath: filepath )
      pre_defines    = preprocess_defines( test_defines: cmp_defines,                      filepath: filepath )

      msg = @reportinator.generate_module_progress(
        operation:   'Collecting search paths, flags, and defines for',
        module_name: testable.name,
        filename:    File.basename( filepath )
      )
      @loginator.log( msg )

      state.lock.synchronize do
        testable.search_paths      = srch_paths
        testable.preprocess_flags  = pre_flags
        testable.compile_flags     = cmp_flags
        testable.assembler_flags   = asm_flags
        testable.link_flags        = lnk_flags
        testable.compile_defines   = cmp_defines + fw_defines + run_defines
        testable.preprocess_defines = pre_defines + fw_defines
      end
    end
  end

  # -----------------------------------------------------------------------
  # Helper methods
  # -----------------------------------------------------------------------

  def process_project_include_paths()
    @include_pathinator.validate_test_build_directive_paths()
    headers = @include_pathinator.validate_header_files_collection()
    @include_pathinator.augment_environment_header_files( headers )
  end

  # Every mocked header's own mirrored directory below this test's mock root -- a mock is
  # only ever findable by the compiler via a search path pointing directly at wherever it
  # actually lives, since C's own #include resolution has no notion of a recursive search
  # path, so this feeds directly into this test's own search paths (TestSearchPaths).
  #
  # These come from the text-scanned #includes, which ignore #if. With test preprocessing
  # on, stage 4 settles which mocks the build uses, and where it reconciles it sets these
  # paths again from the preprocessor's list. A scanned mock without a header, or with one
  # matching only in letter case, may be one the preprocessor discards, so it is skipped
  # here silently. With preprocessing off, the scanned list is the build's own, and a
  # missing or mis-cased header stops the build.
  def collect_mock_search_paths(testable)
    return [] unless testable.paths[:mocks]

    complain = @configurator.project_use_test_preprocessor_tests ? :silent : :error

    # This test's search paths don't exist until stage 3, so they are composed here
    # without mock directories, the same collection later stages resolve against
    collection = @mock_locator.header_collection( @test_search_paths.compose( testable.filepath, testable.paths ) )

    return @mock_locator.directories(
      @context_extractor.lookup_mock_header_includes_list( testable.filepath ),
      mocks_root: testable.paths[:mocks], collection: collection, complain: complain
    )
  end

  def framework_defines()
    defines = []
    defines += @defineinator.defines( topkey: UNITY_SYM,     subkey: :defines )
    defines += @defineinator.defines( topkey: CMOCK_SYM,     subkey: :defines )
    defines += @defineinator.defines( topkey: CEXCEPTION_SYM, subkey: :defines )

    # Partials' own macro-based #includes require this symbol to be defined
    # for every file, both at compile time and preprocess time. It's added
    # here unconditionally, alongside Unity/CMock/CException's own framework
    # defines above, so its presence never depends on whether a file happens
    # to match any entry in a project's own :defines: matcher configuration.
    defines << "CEEDLING_PARTIALS_PREFIX=#{PARTIAL_FILENAME_PREFIX}" if @configurator.project_use_partials

    return defines.uniq
  end

  def runner_defines()
    return @test_runner_manager.collect_defines()
  end

  # A build context without defines of its own takes those of :test. Matchers resolve
  # against `filepath`.
  def context_defines(context:, filepath:)
    context = TEST_SYM unless @defineinator.defines_defined?( context: context )
    return @defineinator.defines( subkey: context, filepath: filepath )
  end

  def compile_defines(context:, filepath:)
    defines  = @defineinator.generate_test_definition( filepath: filepath )
    defines += context_defines( context: context, filepath: filepath )
    return defines.uniq
  end

  # A file matching nothing in a Hash-shaped `:preprocess:` section falls back
  # to `test_defines`, its compile-time defines, exactly as if the section
  # didn't apply to it at all -- see ConfigMatchinator#matches?'s
  # `no_match_default`. This keeps a file's preprocess-defines meta entirely
  # explained by its own configuration, so a `:preprocess:` matcher targeting
  # one file has no bearing on any other file's dependency-tracker meta.
  def preprocess_defines(test_defines:, filepath:)
    return @defineinator.defines(
      subkey: PREPROCESS_SYM, filepath: filepath, default: test_defines, no_match_default: test_defines
    )
  end

  def flags(context:, operation:, filepath:, default:[], no_match_default: nil)
    context = TEST_SYM unless @flaginator.flags_defined?( context: context, operation: operation )
    return @flaginator.flag_down(
      context: context, operation: operation, filepath: filepath, default: default, no_match_default: no_match_default
    )
  end

  # Mirrors #preprocess_defines: a file matching nothing in a Hash-shaped
  # `:preprocess:` flags section falls back to `compile_flags`, its
  # compile-time flags, exactly as if the section didn't apply to it at all.
  def preprocess_flags(context:, compile_flags:, filepath:)
    return flags(
      context: context, operation: OPERATION_PREPROCESS_SYM, filepath: filepath,
      default: compile_flags, no_match_default: compile_flags
    )
  end

  private

  def testable_symbolize(filepath, clean_roots)
    basename = File.basename( filepath ).ext( '' )
    subdir   = PathMirror.relative_subdir_from_clean_roots( filepath, clean_roots )
    name     = subdir.empty? ? basename : File.join( subdir, basename )

    return name.to_sym
  end

end
