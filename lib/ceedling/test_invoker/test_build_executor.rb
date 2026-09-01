# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/exceptions'
require 'ceedling/test_invoker/test_invoker_types'
require 'ceedling/test_invoker/test_pipeline_helpers'

class TestBuildExecutor

  include TestInvokerTypes
  include TestPipelineHelpers

  constructor(
    :configurator,
    :loginator,
    :reportinator,
    :batchinator,
    :preprocessinator,
    :generator,
    :test_context_extractor,
    :plugin_manager,
    :file_path_utils,
    :file_finder,
    :file_wrapper,
    :dependinator,
    :test_source_file_directive_resolver
  )

  def setup()
    @context_extractor = @test_context_extractor
  end

  # Stage 9: Preprocess header files to be mocked.
  def stage_preprocess_mocks(state)
    directives_only = @configurator.test_build_preprocess_directives_only_available
    extras = (@configurator.cmock_treat_inlines == :include)
    skipped = 0

    # Register every mock's preprocessed-header target and settle its staleness
    # up front (sequentially -- cheap, no subprocess work), since it gates both
    # of the parallel batches below.
    state.mocks_list.each do |mock|
      details  = mock.details
      testable = mock.testable

      target = @file_path_utils.form_preprocessed_file_filepath( details.source, testable.name )

      @dependinator.register(
        target,
        files: [details.source],
        meta:  {
          flags:                     testable.preprocess_flags,
          defines:                   testable.preprocess_defines,
          search_paths:              testable.search_paths,
          extras:                    extras,
          tools:                     [@configurator.tools_test_bare_includes_preprocessor, @configurator.tools_test_file_directives_only_preprocessor],
          preprocess_force_fallback: @configurator.test_build_preprocess_force_fallback
        }
      )

      mock.preprocessed_target = target
      mock.stale               = @dependinator.stale?( target )

      next if mock.stale

      msg = @reportinator.generate_module_progress(
        operation:   'Skipping mock preprocessing for',
        module_name: testable.name,
        filename:    File.basename( details.source )
      )
      @loginator.log( msg, Verbosity::OBNOXIOUS )
      skipped += 1
    end

    log_skip_summary( task: "mock preprocessing", count: skipped, noun: "mocks" )

    # Generate directive-only preprocessor output if available
    @batchinator.exec(workload: :compile, things: state.mocks_list) do |mock|
      next unless mock.stale

      details  = mock.details
      testable = mock.testable
      name     = testable.name
      filepath = details.source

      arg_hash = {
        filepath:      filepath,
        test:          name,
        flags:         testable.preprocess_flags,
        include_paths: testable.search_paths,
        vendor_paths:  vendor_search_paths(),
        defines:       testable.preprocess_defines
      }

      _filepath = @preprocessinator.generate_directives_only_output( **arg_hash )

      if _filepath.nil?
        msg = "Failed to generate directive-only preprocessor output (fallback methods will be used) for #{filepath}"
        @loginator.log( msg, Verbosity::COMPLAIN )
      end

      mock.directives_only_filepath = _filepath
    end if directives_only

    # Preprocess and assemble header files to be mocked
    @batchinator.exec(workload: :compile, things: state.mocks_list) do |mock|
      next unless mock.stale

      details                  = mock.details
      testable                 = mock.testable
      directives_only_filepath = mock.directives_only_filepath

      arg_hash = {
        test:                     testable.name,
        filepath:                 details.source,
        directives_only_filepath: directives_only_filepath,
        fallback:                 directives_only_fallback?( directives_only, directives_only_filepath ),
        flags:                    testable.preprocess_flags,
        include_paths:            testable.search_paths,
        vendor_paths:             vendor_search_paths(),
        defines:                  testable.preprocess_defines,
        extras:                   extras
      }

      @preprocessinator.preprocess_mockable_header_file( **arg_hash )

      @dependinator.mark_fresh( mock.preprocessed_target )
    end
  end

  # Stage 10: Generate mocks for all tests.
  def stage_generate_mocks(state)
    # get_cmock_config, not project_config_hash[:cmock]: project_config_hash is
    # flattened -- CMock's own settings live there as individual top-level keys
    # like :cmock_mock_prefix, not as a :cmock section -- so this is the only
    # place that still holds CMock's configuration as a single value to compare.
    cmock_meta = @configurator.get_cmock_config
    skipped = 0

    @batchinator.exec(workload: :compile, things: state.mocks_list) do |mock|
      details  = mock.details
      testable = mock.testable

      output_path = File.join( testable.paths[:mocks], details.path )
      @file_wrapper.mkdir( output_path )

      # `details.input` -- not the stage 9 preprocessed target -- is the
      # correct antecedent here: it's exactly what CMock reads, whether or not
      # mock preprocessing is enabled for this project (see stage_determine_files).
      #
      # `details.name` (a String), not `mock.name` (the Symbol key T2 carried
      # the same value in for hash lookups) -- needed here as a real filename.
      target      = File.join( output_path, details.name + EXTENSION_CORE_SOURCE )
      mock_header = File.join( output_path, details.name + EXTENSION_CORE_HEADER )

      # `mock_header` is tracked here too, alongside `target` -- not
      # semantically an antecedent, but a file CMock writes atomically in the
      # same call below. Tracking it is what lets a stale header be detected
      # and regenerated on the next run: stage_collect_preprocessor_context's
      # includes stand-in generation (test_build_setup.rb) writes a blank
      # placeholder to this exact path whenever the *test* file's own
      # bare-includes cache misses, entirely independent of whether this
      # mock's own antecedents changed.
      @dependinator.register( target, files: [details.input, mock_header], meta: { cmock: cmock_meta } )

      unless @dependinator.stale?( target )
        msg = @reportinator.generate_module_progress(
          operation:   'Skipping mock generation for',
          module_name: testable.name,
          filename:    details.name
        )
        @loginator.log( msg, Verbosity::OBNOXIOUS )
        state.lock.synchronize { skipped += 1 }
        next
      end

      arg_hash = {
        context:        state.context,
        mock:           mock.name,
        test:           testable.name,
        input_filepath: details.input,
        output_path:    output_path
      }

      @generator.generate_mock( **arg_hash )

      @dependinator.mark_fresh( target )
    end

    log_skip_summary( task: "mock generation", count: skipped, noun: "mocks" )
  end

  # Stage 11: Preprocess test files and extract source build directives.
  #
  # A test file's TEST_SOURCE_FILE() results depend on exactly the same file,
  # flags, defines, and search paths already tracked for the preprocessing step
  # itself, so the same staleness answer covers both: when the preprocessed
  # output is already current, its build directive macros are recalled from a
  # small cache instead of being scanned again.
  def stage_preprocess_test_files(state)
    directives_only = @configurator.test_build_preprocess_directives_only_available
    skipped = 0

    @batchinator.exec(workload: :compile, things: state.testables) do |_, testable|
      filepath                 = testable.filepath
      filename                 = File.basename( filepath )
      name                     = testable.name
      directives_only_filepath = testable.preprocess[:directives_only][:filepath]

      fallback = directives_only_fallback?( directives_only, directives_only_filepath )

      # form_preprocessed_file_filepath is deterministic (same call
      # preprocess_test_file itself uses internally), so it can be registered
      # and checked before deciding whether to actually preprocess.
      target = @file_path_utils.form_preprocessed_file_filepath( filepath, name )
      @dependinator.register(
        target,
        files: [filepath],
        meta:  dependency_meta( flags: testable.preprocess_flags, defines: testable.preprocess_defines, search_paths: testable.search_paths )
      )

      stale = @dependinator.stale?( target )

      if stale
        arg_hash = {
          test:                     name,
          filepath:                 filepath,
          directives_only_filepath: directives_only_filepath,
          fallback:                 fallback,
          includes:                 @context_extractor.lookup_all_header_includes_list( testable.filepath ),
          flags:                    testable.preprocess_flags,
          include_paths:            testable.search_paths,
          vendor_paths:             vendor_search_paths(),
          defines:                  testable.preprocess_defines
        }

        _filepath = @preprocessinator.preprocess_test_file( **arg_hash )

        @dependinator.mark_fresh( target )
      else
        msg = @reportinator.generate_module_progress(
          operation:   'Skipping test file preprocessing for',
          module_name: name,
          filename:    filename
        )
        @loginator.log( msg, Verbosity::OBNOXIOUS )
        state.lock.synchronize { skipped += 1 }

        _filepath = target
      end

      state.lock.synchronize { testable.runner.input_filepath = _filepath }

      source_files_cache = @file_path_utils.form_preprocessed_source_files_cache_filepath( filepath, name )

      if stale
        msg = @reportinator.generate_progress( "Parsing #{filename} for test source directive macros" )
        @loginator.log( msg )

        if fallback
          _filepath = filepath
        else
          _filepath = @file_path_utils.form_preprocessed_file_compacted_directives_only_filepath( filepath, name )
        end

        @context_extractor.collect_simple_context_from_file(
          _filepath,
          filepath,
          TestContextExtractor::Context::BUILD_DIRECTIVE_SOURCE_FILES
        )
        @context_extractor.store_build_directives_cache( filepath: filepath, cache_filepath: source_files_cache )
      else
        msg = @reportinator.generate_progress( "Recalling cached source directive macros for #{filename}" )
        @loginator.log( msg, Verbosity::OBNOXIOUS )
        @context_extractor.load_build_directives_cache( filepath: filepath, cache_filepath: source_files_cache )
      end

      state.testables.each do |_, t|
        @test_source_file_directive_resolver.validate!( test: name, filepath: t.filepath )
      end
    end

    log_skip_summary( task: "test file preprocessing", count: skipped, noun: "test files" )
  end

  # Stage 12: Collect test runner details (test case names) from preprocessed test files.
  #
  # Test case names exist only to feed stage 13's runner generation, so this
  # stage checks the same runner target stage 13 uses and does nothing when
  # that target is already current -- there's nothing downstream left to feed.
  # Registering the same target twice across the two stages is harmless:
  # registration accumulates rather than overwrites, and only stage 13 ever
  # marks it fresh, so both stages agree on the same answer.
  def stage_collect_runner_details(state)
    skipped = 0

    @batchinator.exec(workload: :compile, things: state.testables) do |_, testable|
      target = testable.runner.output_filepath

      @dependinator.register( target, files: [testable.filepath], meta: runner_target_meta() )

      unless @dependinator.stale?( target )
        msg = @reportinator.generate_module_progress(
          operation:   'Skipping test case name parsing for',
          module_name: testable.name,
          filename:    File.basename( testable.filepath )
        )
        @loginator.log( msg, Verbosity::OBNOXIOUS )
        state.lock.synchronize { skipped += 1 }
        next
      end

      msg = @reportinator.generate_module_progress(
        operation:   'Parsing test case names',
        module_name: testable.name,
        filename:    File.basename( testable.filepath )
      )
      @loginator.log( msg )

      @context_extractor.collect_test_runner_details( testable.filepath, testable.runner.input_filepath )
    end

    log_skip_summary( task: "test case name parsing", count: skipped, noun: "test files" )
  end

  # Stage 13: Generate test runner files.
  #
  # Antecedent is the raw test file, not stage 11's preprocessed variant --
  # correct because the runner's mock/include lists are parsed fresh from this
  # same raw file every run (stage 2), never from the mock/header files' own
  # content, so an unchanged test file guarantees unchanged lists regardless
  # of what the preprocessed form of the file looks like.
  #
  # `test_preprocessor_tests` meta covers a different piece of runner content:
  # test case names. Stage 12 (gated by this same flag at the pipeline level,
  # test_invoker.rb) parses them from the preprocessed test file when this is
  # true, but when false that stage doesn't run at all -- stage 2 parses raw
  # test-file text for them instead. An unchanged raw test file says nothing
  # about which of those two sources actually fed the last-generated runner,
  # so toggling this flag between runs (with no other change) must still be
  # able to invalidate the target.
  def stage_generate_runners(state)
    skipped = 0

    @batchinator.exec(workload: :compile, things: state.testables) do |_, testable|
      target = testable.runner.output_filepath

      @dependinator.register( target, files: [testable.filepath], meta: runner_target_meta() )

      unless @dependinator.stale?( target )
        msg = @reportinator.generate_module_progress(
          operation:   'Skipping test runner generation for',
          module_name: testable.name,
          filename:    File.basename( testable.filepath )
        )
        @loginator.log( msg, Verbosity::OBNOXIOUS )
        state.lock.synchronize { skipped += 1 }
        next
      end

      arg_hash = {
        context:         state.context,
        mocks:           @context_extractor.lookup_mock_header_includes_list( testable.filepath ),
        includes:        @context_extractor.lookup_nonmock_header_includes_list( testable.filepath ),
        test_filepath:   testable.filepath,
        input_filepath:  testable.runner.input_filepath,
        runner_filepath: target
      }

      @generator.generate_test_runner( **arg_hash )

      @dependinator.mark_fresh( target )
    end

    log_skip_summary( task: "test runner generation", count: skipped, noun: "test runners" )
  end

  # Stage 15: Compile all test build objects in parallel.
  #
  # An unchanged object skips its compile-execute plugin hooks entirely (see
  # compile_test_component), so plugins that accumulate per-run state from
  # pre_compile_execute/post_compile_execute -- compile_commands_json_db,
  # report_build_warnings_log, bullseye, command_hooks -- only see objects
  # actually recompiled this run, not the full set. Same for stage 16's link
  # hooks. Contrast with stage 17, where Generator#generate_test_results
  # reports a skipped executable's cached result through both fixture-execute
  # hooks regardless, so consumers of *that* pair always see every test.
  def stage_build_objects(state)
    skipped = 0

    @batchinator.exec(workload: :compile, things: state.objects_list) do |obj|
      src = @file_finder.find_build_input_file( filepath: obj.obj, context: state.context, test: obj.test )
      compiled = compile_test_component(
        context: state.context,
        test:    obj.test,
        source:  src,
        object:  obj.obj,
        state:   state
      )
      state.lock.synchronize { skipped += 1 } unless compiled
    end

    log_skip_summary( task: "compilation", count: skipped, noun: "objects" )
  end

  # Stage 16: Link test executables.
  def stage_build_executables(state)
    lib_args  = convert_libraries_to_arguments()
    lib_paths = get_library_paths_to_arguments()
    skipped = 0

    @batchinator.exec(workload: :compile, things: state.testables) do |_, testable|
      remove_partials_source_objects( testable.objects, testable.partials.configs )

      link_flags = testable.link_flags
      tool, link_flags = resolve_link_tool( context: state.context, tool: @configurator.tools_test_linker, flags: link_flags, executable: testable.executable )

      @dependinator.register(
        testable.executable,
        files: testable.objects,
        meta:  { flags: link_flags, lib_args: lib_args, lib_paths: lib_paths, tools: [tool] }
      )
      stale = @dependinator.stale?( testable.executable )

      if stale
        arg_hash = {
          context:    state.context,
          build_path: testable.paths[:build],
          executable: testable.executable,
          objects:    testable.objects,
          flags:      link_flags,
          lib_args:   lib_args,
          lib_paths:  lib_paths,
          tool:       tool
        }

        generate_executable( **arg_hash )

        @dependinator.mark_fresh( testable.executable )
      else
        msg = @reportinator.generate_module_progress(
          operation:   'Skipping linking for',
          module_name: testable.name,
          filename:    File.basename( testable.executable )
        )
        @loginator.log( msg, Verbosity::OBNOXIOUS )
        state.lock.synchronize { skipped += 1 }
      end

      # Stage 17 relies on this rather than a second `stale?` call -- by the
      # time it runs, `mark_fresh` above (when `stale` was true) has already
      # updated the cache entry to match the executable's current state, so a
      # fresh `stale?` query would always answer false.
      state.lock.synchronize { testable.executable_rebuilt = stale }
    end

    log_skip_summary( task: "linking", count: skipped, noun: "executables" )
  end

  # Stage 17: Execute test fixtures and collect results.
  #
  # An executable that didn't need relinking (see stage 16) still has valid
  # cached results on disk from whenever it was last built -- Generator#generate_test_results
  # reports those instead of actually (re)running it, per `skipped:` below.
  #
  # `:force_test_rerun` and `:unity ↳ :shuffle_tests` both override that skip:
  # shuffled test-case order is decided at runtime inside the executable itself
  # (Unity's generated `main()` reshuffles on every invocation), not at compile
  # or link time, so an executable that's otherwise unchanged still needs to
  # actually run again for shuffling to have any effect at all.
  #
  # The dependency tracker gives a third reason to rerun, alongside those two:
  # `testable.executable` unchanged says nothing about whether the *tool* that
  # actually runs it -- :tools ↳ :test_fixture -- changed since the last run.
  # This target is registered separately from stage 16's own executable target
  # (not reusing it) so a tool-only change reruns the fixture without also
  # marking the executable itself stale and forcing an unnecessary relink.
  #
  # The target itself is a dedicated marker file, not either outcome-dependent
  # results file (.pass/.fail) -- which of those two actually gets written
  # depends on whether the test passes, so neither is guaranteed to exist after
  # every run, and a target `mark_fresh` can't hash is a crash on a failing
  # test, while a target `stale?` can't find is permanent, unwanted staleness
  # for a test that keeps failing the same way. The marker's own content is
  # irrelevant and never changes -- only its existence (written after every
  # real run, pass or fail alike) and the registered files/meta drive staleness.
  def stage_execute(state)
    skipped = 0
    force_rerun = @configurator.force_test_rerun || @configurator.unity_shuffle_tests

    overridden = state.testables.values.count { |t| !t.executable_rebuilt }

    if @configurator.unity_shuffle_tests && overridden > 0
      noun = overridden == 1 ? 'test executable' : 'test executables'
      @loginator.log(
        "Test shuffling is enabled -- rerunning #{overridden} already up-to-date #{noun} to randomize test case order.",
        Verbosity::NORMAL,
        LogLabels::NOTICE
      )
    end

    @batchinator.exec(workload: :test, things: state.testables) do |_, testable|
      begin
        # `paths[:results]` is only per-test-unique for a test mirrored into its own
        # subdirectory -- a test with no mirrored subdir shares that directory with
        # every other such test, so the marker's own filename (not just its directory)
        # must be test-specific too, matching clean_test_results' own `test + '.*'`
        # naming below.
        fixture_target = File.join( testable.paths[:results], "#{File.basename( testable.name )}.fixture_run" )

        fixture_tool = resolve_fixture_tool( context: state.context, tool: @configurator.tools_test_fixture, test_name: testable.name, target: fixture_target )

        # :use_backtrace doesn't swap the fixture tool itself (unlike Valgrind/Gcov's own
        # pre_test_fixture_register hooks) -- it only selects what happens *after*
        # run_fixture detects a crash (generator.rb's own case on :project_use_backtrace:
        # :gdb runs tools_test_backtrace_gdb, :simple runs tools_test_fixture_simple_backtrace,
        # :none does neither). Without capturing that selector (and the tool config(s) it
        # actually drives) as meta here, toggling :use_backtrace -- or editing a backtrace
        # tool's own executable/args -- would never invalidate this fixture_target, so a
        # delta build would keep reusing a stale crash-diagnosis result on the next crash.
        #
        # tools_test_backtrace_gdb only exists at all when :use_backtrace is :gdb --
        # Configurator only merges its defaults (DEFAULT_TOOLS_TEST_GDB_BACKTRACE) in that
        # case (configurator.rb) -- so it's only read here when actually relevant.
        # tools_test_fixture_simple_backtrace has no such gate (DEFAULT_TOOLS_TEST always
        # includes it) and is always safe to read.
        use_backtrace = @configurator.project_config_hash[:project_use_backtrace]
        backtrace_tools = [@configurator.tools_test_fixture_simple_backtrace]
        backtrace_tools << @configurator.tools_test_backtrace_gdb if use_backtrace == :gdb

        @dependinator.register(
          fixture_target, files: [testable.executable],
          meta: { tools: [fixture_tool], use_backtrace: use_backtrace, backtrace_tools: backtrace_tools }
        )

        run_now = testable.executable_rebuilt || force_rerun || @dependinator.stale?( fixture_target )

        # Clear out any stale prior result (e.g. a lingering `.fail` from a test
        # that now passes) immediately before an actual (re)run -- not upfront
        # for every test regardless of whether it's about to run, which would
        # destroy the still-valid cached result of a test left unchanged.
        clean_test_results( testable.paths[:results], File.basename( testable.name ) ) if run_now

        unless run_now
          msg = @reportinator.generate_module_progress(
            operation:   'Skipping test execution for',
            module_name: testable.name,
            filename:    File.basename( testable.executable )
          )
          @loginator.log( msg, Verbosity::OBNOXIOUS )
          state.lock.synchronize { skipped += 1 }
        end

        arg_hash = {
          context:       state.context,
          test_name:     testable.name,
          test_filepath: testable.filepath,
          executable:    testable.executable,
          result:        testable.results_pass,
          skipped:       !run_now,
          tool:          fixture_tool
        }

        run_fixture( **arg_hash )

        if run_now
          @file_wrapper.touch( fixture_target )
          @dependinator.mark_fresh( fixture_target )
        end

      ensure
        @plugin_manager.post_test( testable.filepath )
      end
    end

    log_skip_summary( task: "test execution", count: skipped, noun: "tests", reason: "reusing cached results" )
  end

  # -----------------------------------------------------------------------
  # Helper methods
  # -----------------------------------------------------------------------

  def generate_executable(context:, build_path:, executable:, objects:, flags:, lib_args:, lib_paths:, tool:)
    begin
      @generator.generate_executable_file(
        tool,
        context,
        objects.map { |v| "\"#{v}\"" },
        flags,
        executable,
        @file_path_utils.form_test_build_map_filepath( build_path, executable ),
        lib_args,
        lib_paths
      )
    rescue ShellException => ex
      if ex.shell_result[:output] =~ /symbol/i
        notice =    "If the linker reports missing symbols, the following may be to blame:\n" +
                    "  1. This test lacks #include statements corresponding to needed source files (see note below).\n" +
                    "  2. Project file paths omit source files corresponding to #include statements in this test.\n" +
                    "  3. Complex macros, #ifdefs, etc. have obscured correct #include statements in this test.\n" +
                    "  4. Your project is attempting to mix C++ and C file extensions (not supported).\n"
        if @configurator.project_use_mocks
          notice += "  5. This test does not #include needed mocks (that triggers their generation).\n"
        end

        notice +=   "\n"
        notice +=   "NOTE: A test file directs the build of a test executable with #include statements:\n" +
                    "  * By convention, Ceedling assumes header filenames correspond to source filenames.\n" +
                    "  * Which code files to compile and link are determined by #include statements.\n"
        if @configurator.project_use_mocks
          notice += "  * An #include statement convention directs the generation of mocks from header files.\n"
        end

        notice +=   "\n"
        notice +=   "OPTIONS:\n" +
                    "  1. Doublecheck this test's #include statements.\n" +
                    "  2. Simplify complex macros or fully specify symbols for this test in :project ↳ :defines.\n" +
                    "  3. If no header file corresponds to the needed source file, use the TEST_SOURCE_FILE()\n" +
                    "     build directive macro in this test to inject a source file into the build.\n\n" +
                    "See the docs on conventions, paths, preprocessing, compilation symbols, and build directive macros.\n\n"

        @loginator.log( notice, Verbosity::COMPLAIN, LogLabels::NOTICE )
      end

      raise ex
    end
  end

  def clean_test_results(path, test)
    @file_wrapper.rm_f( Dir.glob( File.join( path, test + '.*' ) ) )
  end

  def run_fixture(context:, test_name:, test_filepath:, executable:, result:, tool:, skipped: false)
    @generator.generate_test_results(
      tool:          tool,
      context:       context,
      test_name:     test_name,
      test_filepath: test_filepath,
      executable:    executable,
      result:        result,
      skipped:       skipped
    )
  end

  def convert_libraries_to_arguments()
    args = ((@configurator.project_config_hash[:libraries_test] || []) + ((defined? LIBRARIES_SYSTEM) ? LIBRARIES_SYSTEM : [])).flatten
    if (defined? LIBRARIES_FLAG)
      args.map! { |v| LIBRARIES_FLAG.gsub( /\$\{1\}/, v ) }
    end
    return args
  end

  def get_library_paths_to_arguments()
    paths = (defined? PATHS_LIBRARIES) ? (PATHS_LIBRARIES || []).clone : []
    if (defined? LIBRARIES_PATH_FLAG)
      paths.map! { |v| LIBRARIES_PATH_FLAG.gsub( /\$\{1\}/, v ) }
    end
    return paths
  end

  private

  # Compile a single C or assembly source file into an object file. Returns
  # whether a real compile actually happened, so the caller can report how
  # many objects across the whole build needed nothing done.
  def compile_test_component(context:, test:, source:, object:, state:)
    testable     = state.testables[test.to_sym]
    defines      = testable.compile_defines
    search_paths = tailor_search_paths( search_paths: testable.search_paths, filepath: source )
    dependencies = @file_path_utils.form_test_dependencies_filepath( object, name: test, context: context )

    if !@configurator.extension_assembly.match?( source )
      flags = testable.compile_flags
      tool, flags, defines = resolve_compile_tool(
        context: context, operation: OPERATION_COMPILE_SYM, tool: @configurator.tools_test_compiler,
        flags: flags, defines: defines, module_name: test, source: source, object: object
      )
      stale = register_and_check_object_staleness( object: object, source: source, dependencies: dependencies, flags: flags, defines: defines, search_paths: search_paths, tool: tool )

      return log_compile_skip( test: test, source: source ) unless stale

      # A module-under-test or support source mirrored into its own subdirectory needs that
      # subdirectory (and its dependencies-file counterpart) to actually exist before the
      # compiler can write there -- the test's own per-test directories are pre-created
      # upfront, but a mirrored subdirectory beneath one is not.
      @file_wrapper.mkdir( File.dirname( object ) )
      @file_wrapper.mkdir( File.dirname( dependencies ) )

      arg_hash = {
        tool:         tool,
        module_name:  test,
        context:      context,
        source:       source,
        object:       object,
        search_paths: search_paths,
        flags:        flags,
        defines:      defines,
        list:         @file_path_utils.form_test_build_list_filepath( object ),
        dependencies: dependencies
      }

      @generator.generate_object_file_c( **arg_hash )

    elsif @configurator.test_build_use_assembly
      flags = testable.assembler_flags
      tool, flags, defines = resolve_compile_tool(
        context: context, operation: OPERATION_ASSEMBLE_SYM, tool: @configurator.tools_test_assembler,
        flags: flags, defines: defines, module_name: test, source: source, object: object
      )
      stale = register_and_check_object_staleness( object: object, source: source, dependencies: dependencies, flags: flags, defines: defines, search_paths: search_paths, tool: tool )

      return log_compile_skip( test: test, source: source ) unless stale

      @file_wrapper.mkdir( File.dirname( object ) )
      @file_wrapper.mkdir( File.dirname( dependencies ) )

      arg_hash = {
        tool:         tool,
        module_name:  test,
        context:      context,
        source:       source,
        object:       object,
        search_paths: search_paths,
        flags:        flags,
        defines:      defines,
        list:         @file_path_utils.form_test_build_list_filepath( object ),
        dependencies: dependencies
      }

      @generator.generate_object_file_asm( **arg_hash )
    else
      return false
    end

    # A real (re)compile just happened -- register_gcc_deps_file again to pick
    # up the freshly-written `.d` file's current header set (only produced for
    # C compiles; a no-op call for assembly, whose tool has no -MMD/-MF) before
    # recording this target's new baseline.
    @dependinator.register_gcc_deps_file( dependencies ) if @file_wrapper.exist?( dependencies )
    @dependinator.mark_fresh( object )

    true
  end

  def log_compile_skip(test:, source:)
    msg = @reportinator.generate_module_progress(
      operation:   'Skipping compilation for',
      module_name: test,
      filename:    File.basename( source )
    )
    @loginator.log( msg, Verbosity::OBNOXIOUS )
    false
  end

  # Lets a plugin swap in its own compiler tool (and adjust flags/defines) for a
  # particular build context -- e.g. Gcov/Bullseye's instrumented compilers -- via
  # pre_test_compile_register, *before* dependency-tracker meta is computed below, so a
  # plugin's own tool config is what actually drives that target's staleness rather
  # than the plain test compiler it's about to be swapped out for. The resolved
  # values are also what the real compile itself uses (see the two call sites
  # above), so the two can never disagree about which tool actually ran.
  def resolve_compile_tool(context:, operation:, tool:, flags:, defines:, module_name:, source:, object:)
    arg_hash = {
      context: context, operation: operation, tool: tool, flags: flags, defines: defines,
      module_name: module_name, source: source, object: object
    }
    @plugin_manager.pre_test_compile_register( arg_hash )
    return arg_hash[:tool], arg_hash[:flags], arg_hash[:defines]
  end

  # As resolve_compile_tool above, for the link step's own tool swap (pre_test_link_register),
  # e.g. Gcov/Bullseye's instrumented linkers.
  def resolve_link_tool(context:, tool:, flags:, executable:)
    arg_hash = { context: context, tool: tool, flags: flags, executable: executable }
    @plugin_manager.pre_test_link_register( arg_hash )
    return arg_hash[:tool], arg_hash[:flags]
  end

  # As resolve_compile_tool/resolve_link_tool above, for the test-fixture step's own
  # tool swap (pre_test_fixture_register), e.g. Valgrind wrapping the executable.
  # `target` (the fixture-run marker target -- see stage_execute) is included so a
  # plugin can register additional meta of its own against the same target, merging
  # with what this stage registers immediately after -- Dependinator#register is
  # additive across multiple calls for one target regardless of call order.
  def resolve_fixture_tool(context:, tool:, test_name:, target:)
    arg_hash = { context: context, tool: tool, test_name: test_name, target: target }
    @plugin_manager.pre_test_fixture_register( arg_hash )
    return arg_hash[:tool]
  end

  # Registers `object`'s antecedents (its source file, plus whatever headers
  # gcc's `-MMD -MF` discovered on the *previous* successful compile, if any)
  # and reports whether it needs (re)building. The previous run's `.d` file is
  # the only header list available before this run's compile has happened --
  # if headers changed, that's exactly what makes this stale.
  def register_and_check_object_staleness(object:, source:, dependencies:, flags:, defines:, search_paths:, tool:)
    @dependinator.register( object, files: [source], meta: dependency_meta( flags: flags, defines: defines, search_paths: search_paths, tools: [tool] ) )
    @dependinator.register_gcc_deps_file( dependencies ) if @file_wrapper.exist?( dependencies )
    @dependinator.stale?( object )
  end

  # Each framework/support source needs its own vendor path (and, for CMock and a
  # support file, other frameworks' vendor paths too, when those frameworks are also in
  # play) spliced in ahead of a test's ordinary search paths -- the vendor sources
  # themselves live outside any configured :test/:source/:support/:include root, so
  # without this they'd never resolve. An ordinary test source matches none of the
  # cases below and falls through to `search_paths` unchanged.
  def tailor_search_paths(filepath:, search_paths:)
    _search_paths =
      if filepath == File.join( PROJECT_BUILD_VENDOR_UNITY_PATH, UNITY_C_FILE )
        unity_search_paths()
      elsif @configurator.project_use_mocks and
            (filepath == File.join( PROJECT_BUILD_VENDOR_CMOCK_PATH, CMOCK_C_FILE ))
        cmock_search_paths()
      elsif @configurator.project_use_exceptions and
            (filepath == File.join( PROJECT_BUILD_VENDOR_CEXCEPTION_PATH, CEXCEPTION_C_FILE ))
        cexception_search_paths()
      elsif @configurator.collection_all_support.include?( filepath )
        support_file_search_paths( search_paths )
      else
        []
      end

    return search_paths if _search_paths.empty?

    return _search_paths.uniq
  end

  def unity_search_paths()
    @configurator.collection_paths_support + [PROJECT_BUILD_VENDOR_UNITY_PATH]
  end

  def cmock_search_paths()
    paths = @configurator.collection_paths_support + [PROJECT_BUILD_VENDOR_UNITY_PATH, PROJECT_BUILD_VENDOR_CMOCK_PATH]
    paths << PROJECT_BUILD_VENDOR_CEXCEPTION_PATH if @configurator.project_use_exceptions
    paths
  end

  def cexception_search_paths()
    @configurator.collection_paths_support + [PROJECT_BUILD_VENDOR_CEXCEPTION_PATH]
  end

  def support_file_search_paths(search_paths)
    paths = search_paths + @configurator.collection_paths_support + [PROJECT_BUILD_VENDOR_UNITY_PATH]
    paths << PROJECT_BUILD_VENDOR_CMOCK_PATH      if @configurator.project_use_mocks
    paths << PROJECT_BUILD_VENDOR_CEXCEPTION_PATH if @configurator.project_use_exceptions
    paths
  end

  # A test runner's content comes from two configuration sections plus a flag
  # governing where its test case names came from -- shared here so stages 12
  # and 13 always register the exact same meta for the same target.
  #
  # `get_runner_config`/`get_unity_config`, not `project_config_hash[:test_runner]`/
  # `[:unity]`: project_config_hash is flattened -- each nested section's fields
  # become individual top-level keys like `:unity_use_param_tests` -- so it never
  # holds a `:test_runner` or `:unity` section of its own to read back here.
  def runner_target_meta()
    {
      test_runner:              @configurator.get_runner_config,
      unity:                    @configurator.get_unity_config,
      test_preprocessor_tests:  @configurator.project_use_test_preprocessor_tests
    }
  end

end
