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

class TestBuildSetup

  include TestInvokerTypes

  constructor(
    :configurator,
    :loginator,
    :reportinator,
    :batchinator,
    :test_context_extractor,
    :include_pathinator,
    :preprocessinator,
    :defineinator,
    :flaginator,
    :file_wrapper,
    :file_path_utils,
    :test_runner_manager
  )

  def setup()
    @context_extractor = @test_context_extractor
  end

  # Stage 1: Create per-test build/results/mock/partial directory structure
  # and populate the testables hash with initial entries.
  def stage_prepare_build_paths(state)
    results_path = @file_path_utils.form_test_results_path( context: state.context )

    @batchinator.exec(workload: :compile, things: state.tests) do |filepath|
      filepath = filepath.to_s
      key  = testable_symbolize( filepath )
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
      paths[:results]      = results_path
      paths[:dependencies] = @file_path_utils.form_test_dependencies_path( name, context: state.context )

      if @configurator.project_use_mocks
        paths[:mocks] = @file_path_utils.form_test_mocks_path( name )
      end

      if @configurator.project_use_partials
        paths[:partials] = @file_path_utils.form_test_partials_path( name )
      end

      if @configurator.project_use_test_preprocessor != :none
        testable.preprocess[:includes]         = []
        testable.preprocess[:directives_only]  = { filepath: nil }

        paths[:preprocess_incudes]                    = @file_path_utils.form_test_preprocess_includes_path( name )
        paths[:preprocess_files]                      = @file_path_utils.form_test_preprocess_files_path( name )
        paths[:preprocess_files_full_expansion]       = @file_path_utils.form_test_preprocess_files_full_expansion_path( name )
        paths[:preprocess_files_directives_only]      = @file_path_utils.form_test_preprocess_files_directives_only_path( name )
        paths[:preprocess_files_raw_directives_only]  = @file_path_utils.form_test_preprocess_files_raw_directives_only_path( name )
      end

      # Create all testable build paths
      testable.paths.each { |_, path| @file_wrapper.mkdir( path ) }
    end

    clean_test_results( results_path, state.testables.map { |_, t| t.name } )
  end

  # Stage 2: Collect includes, build directives, and test case context from each test file.
  def stage_collect_test_context(state)
    @batchinator.exec(workload: :compile, things: state.testables) do |_, testable|
      filepath = testable.filepath
      filename = File.basename( filepath )

      contexts = [TestContextExtractor::Context::INCLUDES]

      if @configurator.project_use_test_preprocessor_tests
        msg = @reportinator.generate_progress( "Parsing #{filename} for user & system #includes (fallback for preprocessing failures)" )
        @loginator.log( msg )

        contexts << TestContextExtractor::Context::BUILD_DIRECTIVE_INCLUDE_PATHS

        msg = @reportinator.generate_progress( "Parsing #{filename} for include path build directive macros" )
        @loginator.log( msg )

        msg = @reportinator.generate_progress( "Parsing #{filename} for Partials directive macros" )
        @loginator.log( msg )
        contexts << TestContextExtractor::Context::PARTIALS_CONFIGURATION
      else
        msg = @reportinator.generate_progress( "Parsing #{filename} for user & system #includes" )
        @loginator.log( msg )

        contexts << TestContextExtractor::Context::BUILD_DIRECTIVE_INCLUDE_PATHS
        contexts << TestContextExtractor::Context::BUILD_DIRECTIVE_SOURCE_FILES
        contexts << TestContextExtractor::Context::TEST_RUNNER_DETAILS

        msg = @reportinator.generate_progress( "Parsing #{filename} for build directive macros and test case names" )
        @loginator.log( msg )
      end

      @context_extractor.collect_simple_context_from_file( filepath, nil, *contexts )

      validate_mocks_in_use(
        filename: filename,
        mocks:    @context_extractor.lookup_mock_header_includes_list( filepath )
      )

      validate_partials_in_use(
        filename:        filename,
        partials_in_use: !(@context_extractor.lookup_partials_config( filepath )).empty?,
        includes:        @context_extractor.lookup_all_header_includes_list( filepath )
      )
    end

    process_project_include_paths()
  end

  # Stage 3: Collect flags, defines, and search paths for each test.
  def stage_ingest_configurations(state)
    fw_defines  = framework_defines()
    run_defines = runner_defines()

    @batchinator.exec(workload: :compile, things: state.testables) do |_, testable|
      filepath = testable.filepath

      srch_paths     = search_paths( filepath, testable.paths )
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

  # Stage 4 (conditional on preprocessing): Extract includes using the preprocessor.
  def stage_collect_preprocessor_context(state)
    # First pass: extract bare includes; create stand-in files for mocks and partials
    @batchinator.exec(workload: :compile, things: state.testables) do |_, testable|
      name     = testable.name
      filepath = testable.filepath

      if @preprocessinator.cached_includes_list?( test: name, filepath: filepath )
        msg = @reportinator.generate_module_progress(
          operation:   'Skipping preprocessing for #includes in favor of cached #includes for',
          module_name: name,
          filename:    File.basename( filepath )
        )
        @loginator.log( msg )
        next
      end

      arg_hash = {
        test:         name,
        filepath:     filepath,
        search_paths: [@configurator.project_build_vendor_ceedling_path],
        flags:        testable.preprocess_flags,
        defines:      testable.preprocess_defines
      }

      msg = @reportinator.generate_module_progress(
        operation:   'Extracting #includes from',
        module_name: name,
        filename:    File.basename( filepath )
      )
      @loginator.log( msg )

      includes = @preprocessinator.preprocess_bare_includes( **arg_hash )

      testable.preprocess[:includes] = includes

      generate_test_includes_standins( name, includes )
    end

    # Second pass: generate directives-only preprocessor output after stand-ins exist
    directives_only = @configurator.test_build_preprocess_directives_only_available
    @batchinator.exec(workload: :compile, things: state.testables) do |_, testable|
      next unless directives_only

      name     = testable.name
      filepath = testable.filepath

      arg_hash = {
        filepath:      filepath,
        test:          name,
        flags:         testable.preprocess_flags,
        include_paths: testable.search_paths,
        vendor_paths:  [@configurator.project_build_vendor_ceedling_path],
        defines:       testable.preprocess_defines
      }

      msg = @reportinator.generate_module_progress(
        operation:   'Preprocessing test files for follow-on details extraction steps',
        module_name: name,
        filename:    File.basename( filepath )
      )
      @loginator.log( msg, Verbosity::OBNOXIOUS )

      testable.preprocess[:directives_only][:filepath] =
        @preprocessinator.generate_directives_only_output( **arg_hash )
    end

    # Third pass: reconcile includes from all extraction sources and ingest
    directives_only = @configurator.test_build_preprocess_directives_only_available
    @batchinator.exec(workload: :compile, things: state.testables) do |_, testable|
      filepath = testable.filepath
      filename = File.basename( filepath )
      name     = testable.name

      cached, includes = @preprocessinator.load_includes_list( test: name, filepath: filepath )
      if cached
        @context_extractor.ingest_includes( filepath, includes )
        next
      end

      unless directives_only
        msg = @reportinator.generate_module_progress(
          operation:   'Using fallback text-only includes extracted for',
          module_name: name,
          filename:    filename
        )
        @loginator.log( msg, Verbosity::OBNOXIOUS, LogLabels::WARNING )
        next
      end

      directive_only_filepath = testable.preprocess[:directives_only][:filepath]
      system_includes = []
      user_includes   = []

      unless directive_only_filepath.nil?
        arg_hash = {
          name:                     name,
          filepath:                 filepath,
          directives_only_filepath: directive_only_filepath
        }

        user_includes   = @preprocessinator.preprocess_user_includes( **arg_hash )
        system_includes = @preprocessinator.preprocess_system_includes( **arg_hash )
      else
        msg = @reportinator.generate_module_progress(
          operation:   'Using fallback text-only includes extracted for',
          module_name: name,
          filename:    filename
        )
        @loginator.log( msg, Verbosity::OBNOXIOUS, LogLabels::WARNING )

        all_includes    = @context_extractor.lookup_all_header_includes_list( filepath )
        user_includes   = Includes.user( all_includes )
        system_includes = Includes.system( all_includes )
      end

      bare_includes = testable.preprocess[:includes]

      all_includes = Includes.reconcile(
        bare:   bare_includes,
        user:   user_includes,
        system: system_includes
      )

      header = "Extracted reconciled #include list from #{filepath}:"
      @loginator.log_list( all_includes, header, Verbosity::OBNOXIOUS )

      @context_extractor.ingest_includes( filepath, all_includes )

      @preprocessinator.store_includes_list(
        test:     name,
        filepath: filepath,
        includes: all_includes
      )
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

  def generate_test_includes_standins(test, includes)
    mocks    = Includes.filter( includes, /^#{@configurator.cmock_mock_prefix}/ )
    partials = Includes.filter( includes, /^#{PARTIAL_FILENAME_PREFIX}/ )

    mocks.each do |include|
      filepath = @file_path_utils.form_mock_header_filepath( test, include.filepath )
      msg = @reportinator.generate_module_progress(
        operation:   'Generating stand-in header for',
        module_name: test,
        filename:    include.filename
      )
      @loginator.log( msg, Verbosity::DEBUG )
      @file_wrapper.mkdir( File.dirname( filepath ) )
      @file_wrapper.write_blank_file( filepath )
    end

    partials.each do |include|
      filepath = @file_path_utils.form_partial_header_filepath( test, include.filename )
      msg = @reportinator.generate_module_progress(
        operation:   'Generating stand-in header for',
        module_name: test,
        filename:    include.filename
      )
      @loginator.log( msg, Verbosity::DEBUG )
      @file_wrapper.write_blank_file( filepath )
    end
  end

  def validate_mocks_in_use(filename:, mocks:)
    if !@configurator.project_use_mocks and !mocks.empty?
      _mocks = mocks.map { |include| include.filename }

      if _mocks.length > 1
        _mocks = "[#{_mocks.join(', ')}]"
      else
        _mocks = _mocks[0]
      end

      msg = "Your project is not configured for mocking, but #{filename} #includes #{_mocks}"
      raise CeedlingException.new( msg )
    end
  end

  def validate_partials_in_use(filename:, partials_in_use:, includes:)
    partials_header_in_use = Includes.contains?( includes, CEEDLING_HEADER_FILENAME )

    if partials_in_use && !@configurator.project_use_partials
      msg = "Your project is not configured for Partials, but #{filename} is attempting to use Partial features"
      raise CeedlingException.new( msg )
    end

    if partials_in_use && !partials_header_in_use
      msg = "Your test file #{filename} is attempting to use Partial features without #including #{CEEDLING_HEADER_FILENAME}"
      raise CeedlingException.new( msg )
    end
  end

  def search_paths(filepath, paths)
    _paths = []
    _paths << paths[:mocks]    if paths[:mocks]
    _paths << paths[:partials] if paths[:partials]
    _paths += @include_pathinator.lookup_test_directive_include_paths( filepath )
    _paths += @include_pathinator.collect_test_include_paths()
    _paths += @configurator.collection_paths_support
    _paths += @configurator.collection_paths_include
    _paths += @configurator.collection_paths_libraries
    _paths += @configurator.collection_paths_vendor
    _paths += @configurator.collection_paths_test_toolchain_include
    return _paths.uniq
  end

  def framework_defines()
    defines = []
    defines += @defineinator.defines( topkey: UNITY_SYM,     subkey: :defines )
    defines += @defineinator.defines( topkey: CMOCK_SYM,     subkey: :defines )
    defines += @defineinator.defines( topkey: CEXCEPTION_SYM, subkey: :defines )
    return defines.uniq
  end

  def runner_defines()
    return @test_runner_manager.collect_defines()
  end

  def compile_defines(context:, filepath:)
    context = TEST_SYM unless @defineinator.defines_defined?( context: context )
    defines  = @defineinator.generate_test_definition( filepath: filepath )
    defines += @defineinator.defines( subkey: context, filepath: filepath )
    return defines.uniq
  end

  def preprocess_defines(test_defines:, filepath:)
    preprocessing_defines = @defineinator.defines( subkey: PREPROCESS_SYM, filepath: filepath, default: nil )
    return test_defines if preprocessing_defines.nil?
    return preprocessing_defines
  end

  def flags(context:, operation:, filepath:, default:[])
    context = TEST_SYM unless @flaginator.flags_defined?( context: context, operation: operation )
    return @flaginator.flag_down( context: context, operation: operation, filepath: filepath, default: default )
  end

  def preprocess_flags(context:, compile_flags:, filepath:)
    preprocessing_flags = flags( context: context, operation: OPERATION_PREPROCESS_SYM, filepath: filepath, default: nil )
    return compile_flags if preprocessing_flags.nil?
    return preprocessing_flags
  end

  def clean_test_results(path, tests)
    tests.each do |test|
      @file_wrapper.rm_f( Dir.glob( File.join( path, test + '.*' ) ) )
    end
  end

  private

  def testable_symbolize(filepath)
    return (File.basename( filepath ).ext( '' )).to_sym
  end

end
