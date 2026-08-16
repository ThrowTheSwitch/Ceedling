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
require 'ceedling/path_mirror'

class TestBuildSetup

  include TestInvokerTypes
  include TestPipelineHelpers

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
    :file_finder,
    :test_runner_manager,
    :dependinator
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
        testable.preprocess[:includes]         = []
        testable.preprocess[:directives_only]  = { filepath: nil }

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

      srch_paths     = search_paths( filepath, testable.paths, testable.mock_search_paths )
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
  #
  # All three passes below are dependency-tracker-gated (or, for the third,
  # cheap enough not to need its own gate at all -- see its comment). The
  # first two passes each invoke a real, separate preprocessor subprocess
  # (bare-includes extraction uses `-MM -MG -MP`; directives-only generation
  # uses `-fdirectives-only`) and are exactly the "expensive" work worth
  # skipping when nothing relevant changed.
  def stage_collect_preprocessor_context(state)
    # First pass: extract bare includes; create stand-in files for mocks and partials.
    #
    # The extracted list is needed immediately (stand-in generation, below) and
    # again by the third pass's reconciliation -- on a cache hit, it's recalled
    # via `load_includes_list` rather than just leaving a file on disk for
    # something else to notice, since nothing else reads this list back off
    # disk on its own the way stage 9/11's plain preprocessed-output targets do.
    skipped_includes = 0

    @batchinator.exec(workload: :compile, things: state.testables) do |_, testable|
      name     = testable.name
      filepath = testable.filepath

      target = @file_path_utils.form_preprocessed_includes_list_filepath( filepath, name )

      @dependinator.register(
        target,
        files: [filepath],
        meta:  { flags: testable.preprocess_flags, defines: testable.preprocess_defines, search_paths: testable.search_paths }
      )

      if @dependinator.stale?( target )
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

        @preprocessinator.store_includes_list( test: name, filepath: filepath, includes: includes )
        @dependinator.mark_fresh( target )

        generate_test_includes_standins( testable, includes )
      else
        msg = @reportinator.generate_module_progress(
          operation:   'Skipping preprocessing for #includes in favor of cached #includes for',
          module_name: name,
          filename:    File.basename( filepath )
        )
        @loginator.log( msg, Verbosity::OBNOXIOUS )
        state.lock.synchronize { skipped_includes += 1 }

        testable.preprocess[:includes] = @preprocessinator.load_includes_list( test: name, filepath: filepath )
      end
    end

    log_skip_summary( task: "#include extraction", count: skipped_includes, noun: "test files" )

    # Second pass: generate directives-only preprocessor output after stand-ins exist
    directives_only = @configurator.test_build_preprocess_directives_only_available
    skipped_directives_only = 0

    @batchinator.exec(workload: :compile, things: state.testables) do |_, testable|
      next unless directives_only

      name     = testable.name
      filepath = testable.filepath

      # The raw output path is deterministic (form_preprocessed_file_raw_directives_only_filepath),
      # so it can be registered and checked before deciding whether to actually
      # (re)run the preprocessor. `generate_directives_only_output` also writes a
      # second, compacted file derived atomically from the same run -- covered
      # by this same staleness check since both come from the same inputs.
      target = @file_path_utils.form_preprocessed_file_raw_directives_only_filepath( filepath, name )

      @dependinator.register(
        target,
        files: [filepath],
        meta:  { flags: testable.preprocess_flags, defines: testable.preprocess_defines, search_paths: testable.search_paths }
      )

      unless @dependinator.stale?( target )
        msg = @reportinator.generate_module_progress(
          operation:   'Skipping directives-only preprocessing for',
          module_name: name,
          filename:    File.basename( filepath )
        )
        @loginator.log( msg, Verbosity::OBNOXIOUS )
        state.lock.synchronize { skipped_directives_only += 1 }

        testable.preprocess[:directives_only][:filepath] = target
        next
      end

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

      # A nil result means the preprocessor failed (see generate_directives_only_output) --
      # nothing was actually written, so there's nothing to mark fresh; the next
      # run will correctly see this target as still missing and retry.
      @dependinator.mark_fresh( target ) unless testable.preprocess[:directives_only][:filepath].nil?
    end

    log_skip_summary( task: "directives-only preprocessing", count: skipped_directives_only, noun: "test files" ) if directives_only

    # Third pass: reconcile includes from all extraction sources and ingest.
    #
    # No dependency-tracker gate of its own: the user/system extraction below
    # either parses the second pass's already-gated output or (fallback) does
    # a cheap in-Ruby text scan, and reconciling that with the first pass's
    # (fresh-or-recalled) bare-includes list is plain list-merging -- there's
    # no expensive subprocess step here left to skip.
    directives_only = @configurator.test_build_preprocess_directives_only_available
    @batchinator.exec(workload: :compile, things: state.testables) do |_, testable|
      filepath = testable.filepath
      filename = File.basename( filepath )
      name     = testable.name

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
        bare:          bare_includes,
        user:          user_includes,
        system:        system_includes,
        test_filepath: filepath
      ) do |bare_filepath, chosen, passed_over|
        msg = "Multiple files satisfy #include '#{bare_filepath}' within #{filepath}; chose '#{chosen}' " \
              "by search-path priority. Other candidates passed over: #{passed_over.join(', ')}. If this " \
              "choice is wrong, add more path to that #include statement to select a different file -- or " \
              "watch for a compilation error naming the real mismatch."
        @loginator.log( msg, Verbosity::COMPLAIN, LogLabels::NOTICE )
      end

      header = "Extracted reconciled #include list from #{filepath}:"
      @loginator.log_list( all_includes, header, Verbosity::OBNOXIOUS )

      @context_extractor.ingest_includes( filepath, all_includes )
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

  # Writes placeholder header files for any mock or partial a test #includes,
  # so early preprocessing/context-extraction steps have something to resolve
  # before the real mock (stage 10) or partial (stage 8) exists yet. Later
  # stages overwrite these paths with real generated content; a test build
  # that never runs those later stages (e.g. :sources_only) is left with only
  # the placeholder, which is sufficient for its purposes.
  #
  # A path already holding a file -- real generated content from a prior run,
  # or an earlier placeholder -- is left untouched rather than blanked. Only
  # gcc's need for *something* resolvable at the #include path depends on this
  # file at all; nothing reads its content for meaning. Overwriting it
  # unconditionally would needlessly perturb it as a hash antecedent (mock
  # generation, stage 10, tracks its own stand-in header as one of the inputs
  # it hashes), invalidating a target purely because this stand-in step ran,
  # independent of whether anything the mock or partial actually depends on
  # changed. Whether real regeneration is warranted stays entirely up to each
  # later stage's own dependency-tracker check.
  def generate_test_includes_standins(testable, includes)
    test = testable.name
    mocks    = Includes.filter( includes, /^#{@configurator.cmock_mock_prefix}/ )
    partials = Includes.filter( includes, /^#{PARTIAL_FILENAME_PREFIX}/ )

    # Reconstructs the mock-search-path-free ordering collect_mock_search_paths (stage 2)
    # originally saw when it first resolved these same mocks' real headers -- this test's own
    # generated mock directories weren't spliced into search_paths yet at that point.
    collection = @include_pathinator.ordered_header_files(
      testable.search_paths - testable.mock_search_paths
    )

    mocks.each do |include|
      # A Partial mock is Ceedling's own generated content with no real header to resolve
      # against, always flat per test. An ordinary mock's stand-in mirrors wherever its real
      # header actually lives, matching the real mock (stage 10) -- both are findable by the
      # compiler only via a search path pointing directly at that mirrored directory (already
      # collected into this test's own search paths, stage 3, before either one is written).
      if mock_partial?( include )
        filepath = @file_path_utils.form_mock_header_filepath( test, include.filepath )
      else
        _source, subdir = @file_finder.resolve_mock( include.filepath, collection: collection )
        mock_dir = subdir.empty? ? test : File.join( test, subdir )
        filepath = @file_path_utils.form_mock_header_filepath( mock_dir, include.filename )
      end

      next if @file_wrapper.exist?( filepath )

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
      next if @file_wrapper.exist?( filepath )

      msg = @reportinator.generate_module_progress(
        operation:   'Generating stand-in header for',
        module_name: test,
        filename:    include.filename
      )
      @loginator.log( msg, Verbosity::DEBUG )
      @file_wrapper.write_blank_file( filepath )
    end
  end

  # A Partial mock is Ceedling's own generated content, identifiable by its own naming
  # convention rather than by any real header it corresponds to (it has none).
  def mock_partial?(include)
    include.filename.start_with?( @configurator.cmock_mock_prefix + PARTIAL_FILENAME_PREFIX )
  end

  # Every mocked header's own mirrored directory below this test's mock root -- a mock is
  # only ever findable by the compiler via a search path pointing directly at wherever it
  # actually lives, since C's own #include resolution has no notion of a recursive search
  # path, so this feeds directly into this test's own search paths (search_paths, below).
  def collect_mock_search_paths(testable)
    return [] unless testable.paths[:mocks]

    # testable.search_paths doesn't exist yet -- this method is itself one of that value's own
    # inputs (stage 2, ahead of stage 3) -- so the ordering it needs is rebuilt directly, with
    # mock_search_paths deliberately empty since none of this test's own mocks are placed yet.
    # generate_test_includes_standins (stage 4) and stage_determine_files (stage 5) must
    # resolve each of these same mocks identically, so both reconstruct this exact ordering by
    # subtracting testable.mock_search_paths back out of the real testable.search_paths once it
    # exists, rather than each independently re-deriving it.
    collection = @include_pathinator.ordered_header_files(
      search_paths( testable.filepath, testable.paths, [] )
    )

    dirs = []
    @context_extractor.lookup_mock_header_includes_list( testable.filepath ).each do |include|
      next if mock_partial?( include )
      _source, subdir = @file_finder.resolve_mock( include.filepath, collection: collection )
      dirs << (subdir.empty? ? testable.paths[:mocks] : File.join( testable.paths[:mocks], subdir ))
    end
    return dirs.uniq
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

  def search_paths(filepath, paths, mock_search_paths = [])
    _paths = []
    _paths << paths[:mocks]    if paths[:mocks]
    _paths += mock_search_paths
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

  def compile_defines(context:, filepath:)
    context = TEST_SYM unless @defineinator.defines_defined?( context: context )
    defines  = @defineinator.generate_test_definition( filepath: filepath )
    defines += @defineinator.defines( subkey: context, filepath: filepath )
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
