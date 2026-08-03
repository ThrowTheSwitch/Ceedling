# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/exceptions'
require 'ceedling/test_invoker/test_invoker_types'

class TestBuildExecutor

  include TestInvokerTypes

  constructor(
    :configurator,
    :loginator,
    :reportinator,
    :batchinator,
    :preprocessinator,
    :partializer,
    :generator,
    :test_context_extractor,
    :plugin_manager,
    :file_path_utils,
    :file_finder,
    :file_wrapper,
    :dependinator
  )

  def setup()
    @context_extractor = @test_context_extractor
  end

  # Stage 6: Preprocess partial header files for extract-and-generate pass.
  #
  # Unlike every other generation stage in this file, stages 6-8 (partials)
  # always run in full and register nothing with the dependency tracker.
  # Stage 8 consumes `config.includes`/`directives_only_filepath`/
  # `full_expansion_filepath` as in-memory state these stages return directly,
  # not a stable file path read back on a later run -- the pattern every other
  # stage here relies on for skipping unchanged work doesn't apply without
  # first reconstructing that state some other way.
  def stage_preprocess_partial_headers(state)
    directives_only = @configurator.test_build_preprocess_directives_only_available

    # Generate directive-only preprocessor output if available
    @batchinator.exec(workload: :compile, things: state.partials_headers) do |details|
      config   = details[:config]
      testable = details[:testable]
      name     = testable.name

      arg_hash = {
        filepath:      config.filepath,
        test:          name,
        flags:         testable.preprocess_flags,
        include_paths: testable.search_paths,
        vendor_paths:  [@configurator.project_build_vendor_ceedling_path],
        defines:       testable.preprocess_defines
      }

      details[:directives_only_filepath] = @preprocessinator.generate_directives_only_output( **arg_hash )
    end if directives_only

    # Preprocess and assemble header files
    @batchinator.exec(workload: :compile, things: state.partials_headers) do |details|
      config                   = details[:config]
      testable                 = details[:testable]
      name                     = testable.name
      directives_only_filepath = details[:directives_only_filepath]

      arg_hash = {
        test:                     name,
        filepath:                 config.filepath,
        directives_only_filepath: directives_only_filepath,
        fallback:                 (!directives_only or directives_only_filepath.nil?),
        flags:                    testable.preprocess_flags,
        include_paths:            testable.search_paths,
        vendor_paths:             [@configurator.project_build_vendor_ceedling_path],
        defines:                  testable.preprocess_defines
      }

      config.directives_only_filepath, config.includes = @preprocessinator.preprocess_partial_header_file_preserve_macros( **arg_hash )
    end

    # Full-preprocess partial header files for expanded signature extraction.
    @batchinator.exec(workload: :compile, things: state.partials_headers) do |details|
      config   = details[:config]
      testable = details[:testable]
      name     = testable.name

      arg_hash = {
        filepath:      config.filepath,
        test:          name,
        flags:         testable.preprocess_flags,
        include_paths: testable.search_paths,
        vendor_paths:  [@configurator.project_build_vendor_ceedling_path],
        defines:       testable.preprocess_defines
      }

      config.full_expansion_filepath = @preprocessinator.preprocess_partial_header_expand_macros( **arg_hash )
    end
  end

  # Stage 7: Preprocess partial source files for extract-and-generate pass.
  def stage_preprocess_partial_sources(state)
    directives_only = @configurator.test_build_preprocess_directives_only_available

    # Generate directive-only preprocessor output if available
    @batchinator.exec(workload: :compile, things: state.partials_sources) do |details|
      config   = details[:config]
      testable = details[:testable]
      name     = testable.name

      arg_hash = {
        filepath:      config.filepath,
        test:          name,
        flags:         testable.preprocess_flags,
        include_paths: testable.search_paths,
        vendor_paths:  [@configurator.project_build_vendor_ceedling_path],
        defines:       testable.preprocess_defines
      }

      details[:directives_only_filepath] = @preprocessinator.generate_directives_only_output( **arg_hash )
    end if directives_only

    # Preprocess and assemble source files
    @batchinator.exec(workload: :compile, things: state.partials_sources) do |details|
      config                   = details[:config]
      testable                 = details[:testable]
      name                     = testable.name
      directives_only_filepath = details[:directives_only_filepath]

      arg_hash = {
        test:                     name,
        filepath:                 config.filepath,
        directives_only_filepath: directives_only_filepath,
        fallback:                 (!directives_only or directives_only_filepath.nil?),
        flags:                    testable.preprocess_flags,
        include_paths:            testable.search_paths,
        vendor_paths:             [@configurator.project_build_vendor_ceedling_path],
        defines:                  testable.preprocess_defines
      }

      config.directives_only_filepath, config.includes = @preprocessinator.preprocess_partial_source_file_preserve_macros( **arg_hash )
    end

    # Full-preprocess partial source files for expanded signature extraction.
    @batchinator.exec(workload: :compile, things: state.partials_sources) do |details|
      config   = details[:config]
      testable = details[:testable]
      name     = testable.name

      arg_hash = {
        filepath:      config.filepath,
        test:          name,
        flags:         testable.preprocess_flags,
        include_paths: testable.search_paths,
        vendor_paths:  [@configurator.project_build_vendor_ceedling_path],
        defines:       testable.preprocess_defines
      }

      config.full_expansion_filepath = @preprocessinator.preprocess_partial_source_expand_macros( **arg_hash )
    end
  end

  # Stage 8: Extract and generate partial implementation and interface files.
  def stage_generate_partials(state)
    directives_only = @configurator.test_build_preprocess_directives_only_available

    partials = []
    state.testables.each do |_, testable|
      next if testable.partials.configs.empty?
      testable.partials.configs.each do |_, config|
        partials << { config: config, testable: testable }
      end
    end

    @batchinator.exec(workload: :compile, things: partials) do |partial|
      config   = partial[:config]
      testable = partial[:testable]
      name     = testable.name

      module_contents = @partializer.extract_module_contents(
        name,
        config,
        !directives_only
      )

      @partializer.validate_config( c_module: module_contents, config: config, name: name )

      @partializer.sanitize( module_contents )

      implementation = @partializer.extract_implementation_functions(
        test:        name,
        partial:     config.module,
        definitions: module_contents.function_definitions,
        config:      config
      )

      interface = @partializer.extract_interface_functions(
        test:         name,
        partial:      config.module,
        definitions:  module_contents.function_definitions,
        declarations: module_contents.function_declarations,
        config:       config
      )

      @partializer.validate_extracted_functions(
        name:      name,
        partial:   config.module,
        impl:      implementation,
        interface: interface
      )

      arg_hash = {
        test:                 name,
        partial:              config.module,
        function_definitions: implementation,
        c_module:             module_contents,
        header_includes:      @partializer.remap_implementation_header_includes(
                                name:     config.module,
                                includes: (config.source.includes + config.header.includes),
                                partials: testable.partials.configs,
                                test:     name
                              ),
        source_includes:      @partializer.remap_implementation_source_includes(
                                name:     config.module,
                                includes: (config.source.includes + config.header.includes),
                                partials: testable.partials.configs,
                                test:     name
                              ),
        input_filepath:       config.source.filepath,
        output_path:          testable.paths[:partials]
      }

      unless implementation.nil?
        @generator.generate_partial_implementation( **arg_hash )
        state.lock.synchronize { testable.partials.tests << config.module }
      end

      arg_hash = {
        test:                  name,
        partial:               config.module,
        function_declarations: interface,
        includes:              @partializer.remap_interface_header_includes(
                                 name:     config.module,
                                 includes: (config.source.includes + config.header.includes),
                                 partials: testable.partials.configs,
                                 test:     name
                               ),
        c_module:              module_contents,
        input_filepath:        config.header.filepath,
        output_path:           testable.paths[:partials]
      }

      unless interface.nil?
        @generator.generate_partial_interface( **arg_hash )
        state.lock.synchronize { testable.partials.mocks << config.module }
      end
    end
  end

  # Stage 9: Preprocess header files to be mocked.
  def stage_preprocess_mocks(state)
    directives_only = @configurator.test_build_preprocess_directives_only_available
    extras = (@configurator.cmock_treat_inlines == :include)

    # Register every mock's preprocessed-header target and settle its staleness
    # up front (sequentially -- cheap, no subprocess work), since it gates both
    # of the parallel batches below.
    state.mocks_list.each do |mock|
      details  = mock[:details]
      testable = mock[:testable]

      target = @file_path_utils.form_preprocessed_file_filepath( details[:source], testable.name )

      @dependinator.register(
        target,
        files: [details[:source]],
        meta:  {
          flags:        testable.preprocess_flags,
          defines:      testable.preprocess_defines,
          search_paths: testable.search_paths,
          extras:       extras
        }
      )

      mock[:preprocessed_target] = target
      mock[:stale]               = @dependinator.stale?( target )
    end

    # Generate directive-only preprocessor output if available
    @batchinator.exec(workload: :compile, things: state.mocks_list) do |mock|
      next unless mock[:stale]

      details  = mock[:details]
      testable = mock[:testable]
      name     = testable.name
      filepath = details[:source]

      arg_hash = {
        filepath:      filepath,
        test:          name,
        flags:         testable.preprocess_flags,
        include_paths: testable.search_paths,
        vendor_paths:  [@configurator.project_build_vendor_ceedling_path],
        defines:       testable.preprocess_defines
      }

      _filepath = @preprocessinator.generate_directives_only_output( **arg_hash )

      if _filepath.nil?
        msg = "Failed to generate directive-only preprocessor output (fallback methods will be used) for #{filepath}"
        @loginator.log( msg, Verbosity::COMPLAIN )
      end

      mock[:directives_only_filepath] = _filepath
    end if directives_only

    # Preprocess and assemble header files to be mocked
    @batchinator.exec(workload: :compile, things: state.mocks_list) do |mock|
      next unless mock[:stale]

      details                  = mock[:details]
      testable                 = mock[:testable]
      directives_only_filepath = mock[:directives_only_filepath]

      arg_hash = {
        test:                     testable.name,
        filepath:                 details[:source],
        directives_only_filepath: directives_only_filepath,
        fallback:                 (!directives_only or directives_only_filepath.nil?),
        flags:                    testable.preprocess_flags,
        include_paths:            testable.search_paths,
        vendor_paths:             [@configurator.project_build_vendor_ceedling_path],
        defines:                  testable.preprocess_defines,
        extras:                   extras
      }

      @preprocessinator.preprocess_mockable_header_file( **arg_hash )

      @dependinator.mark_fresh( mock[:preprocessed_target] )
    end
  end

  # Stage 10: Generate mocks for all tests.
  def stage_generate_mocks(state)
    cmock_meta = @configurator.project_config_hash[:cmock]

    @batchinator.exec(workload: :compile, things: state.mocks_list) do |mock|
      details  = mock[:details]
      testable = mock[:testable]

      output_path = File.join( testable.paths[:mocks], details[:path] )
      @file_wrapper.mkdir( output_path )

      # `details[:input]` -- not the stage 9 preprocessed target -- is the
      # correct antecedent here: it's exactly what CMock reads, whether or not
      # mock preprocessing is enabled for this project (see stage_determine_files).
      #
      # `details[:name]` (a String), not `mock[:name]` (the Symbol key T2 carried
      # the same value in for hash lookups) -- needed here as a real filename.
      target      = File.join( output_path, details[:name] + EXTENSION_CORE_SOURCE )
      mock_header = File.join( output_path, details[:name] + EXTENSION_CORE_HEADER )

      # `mock_header` is tracked here too, alongside `target` -- not
      # semantically an antecedent, but a file CMock writes atomically in the
      # same call below. Tracking it is what lets a stale header be detected
      # and regenerated on the next run: stage_collect_preprocessor_context's
      # includes stand-in generation (test_build_setup.rb) writes a blank
      # placeholder to this exact path whenever the *test* file's own
      # bare-includes cache misses, entirely independent of whether this
      # mock's own antecedents changed.
      @dependinator.register( target, files: [details[:input], mock_header], meta: { cmock: cmock_meta } )

      next unless @dependinator.stale?( target )

      arg_hash = {
        context:        state.context,
        mock:           mock[:name],
        test:           testable.name,
        input_filepath: details[:input],
        output_path:    output_path
      }

      @generator.generate_mock( **arg_hash )

      @dependinator.mark_fresh( target )
    end
  end

  # Stage 11: Preprocess test files and extract source build directives.
  def stage_preprocess_test_files(state)
    directives_only = @configurator.test_build_preprocess_directives_only_available

    @batchinator.exec(workload: :compile, things: state.testables) do |_, testable|
      filepath                 = testable.filepath
      filename                 = File.basename( filepath )
      name                     = testable.name
      directives_only_filepath = testable.preprocess[:directives_only][:filepath]

      fallback = (!directives_only or directives_only_filepath.nil?)

      # form_preprocessed_file_filepath is deterministic (same call
      # preprocess_test_file itself uses internally), so it can be registered
      # and checked before deciding whether to actually preprocess.
      target = @file_path_utils.form_preprocessed_file_filepath( filepath, name )
      @dependinator.register(
        target,
        files: [filepath],
        meta:  { flags: testable.preprocess_flags, defines: testable.preprocess_defines, search_paths: testable.search_paths }
      )

      if @dependinator.stale?( target )
        arg_hash = {
          test:                     name,
          filepath:                 filepath,
          directives_only_filepath: directives_only_filepath,
          fallback:                 fallback,
          includes:                 @context_extractor.lookup_all_header_includes_list( testable.filepath ),
          flags:                    testable.preprocess_flags,
          include_paths:            testable.search_paths,
          vendor_paths:             [@configurator.project_build_vendor_ceedling_path],
          defines:                  testable.preprocess_defines
        }

        _filepath = @preprocessinator.preprocess_test_file( **arg_hash )

        @dependinator.mark_fresh( target )
      else
        _filepath = target
      end

      state.lock.synchronize { testable.runner[:input_filepath] = _filepath }

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

      state.testables.each do |_, t|
        validate_build_directive_source_files( test: name, filepath: t.filepath )
      end
    end
  end

  # Stage 12: Collect test runner details (test case names) from preprocessed test files.
  def stage_collect_runner_details(state)
    @batchinator.exec(workload: :compile, things: state.testables) do |_, testable|
      msg = @reportinator.generate_module_progress(
        operation:   'Parsing test case names',
        module_name: testable.name,
        filename:    File.basename( testable.filepath )
      )
      @loginator.log( msg )

      @context_extractor.collect_test_runner_details( testable.filepath, testable.runner[:input_filepath] )
    end
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
    test_runner_meta = @configurator.project_config_hash[:test_runner]
    unity_meta       = @configurator.project_config_hash[:unity]

    @batchinator.exec(workload: :compile, things: state.testables) do |_, testable|
      target = testable.runner[:output_filepath]

      @dependinator.register(
        target,
        files: [testable.filepath],
        meta:  {
          test_runner:              test_runner_meta,
          unity:                    unity_meta,
          test_preprocessor_tests:  @configurator.project_use_test_preprocessor_tests
        }
      )

      next unless @dependinator.stale?( target )

      arg_hash = {
        context:         state.context,
        mocks:           @context_extractor.lookup_mock_header_includes_list( testable.filepath ),
        includes:        @context_extractor.lookup_nonmock_header_includes_list( testable.filepath ),
        test_filepath:   testable.filepath,
        input_filepath:  testable.runner[:input_filepath],
        runner_filepath: target
      }

      @generator.generate_test_runner( **arg_hash )

      @dependinator.mark_fresh( target )
    end
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
    @batchinator.exec(workload: :compile, things: state.objects_list) do |obj|
      src = @file_finder.find_build_input_file( filepath: obj[:obj], context: state.context )
      compile_test_component(
        context: state.context,
        test:    obj[:test],
        source:  src,
        object:  obj[:obj],
        state:   state
      )
    end
  end

  # Stage 16: Link test executables.
  def stage_build_executables(state)
    lib_args  = convert_libraries_to_arguments()
    lib_paths = get_library_paths_to_arguments()

    @batchinator.exec(workload: :compile, things: state.testables) do |_, testable|
      remove_partials_source_objects( testable.objects, testable.partials.configs )

      @dependinator.register(
        testable.executable,
        files: testable.objects,
        meta:  { flags: testable.link_flags, lib_args: lib_args, lib_paths: lib_paths }
      )
      stale = @dependinator.stale?( testable.executable )

      if stale
        arg_hash = {
          context:    state.context,
          build_path: testable.paths[:build],
          executable: testable.executable,
          objects:    testable.objects,
          flags:      testable.link_flags,
          lib_args:   lib_args,
          lib_paths:  lib_paths,
          options:    state.options
        }

        generate_executable_now( **arg_hash )

        @dependinator.mark_fresh( testable.executable )
      end

      # Stage 17 relies on this rather than a second `stale?` call -- by the
      # time it runs, `mark_fresh` above (when `stale` was true) has already
      # updated the cache entry to match the executable's current state, so a
      # fresh `stale?` query would always answer false.
      state.lock.synchronize { testable.executable_rebuilt = stale }
    end
  end

  # Stage 17: Execute test fixtures and collect results.
  #
  # An executable that didn't need relinking (see stage 16) still has valid
  # cached results on disk from whenever it was last built -- Generator#generate_test_results
  # reports those instead of actually (re)running it, per `skipped:` below.
  def stage_execute(state)
    @batchinator.exec(workload: :test, things: state.testables) do |_, testable|
      begin
        # Clear out any stale prior result (e.g. a lingering `.fail` from a test
        # that now passes) immediately before an actual (re)run -- not upfront
        # for every test regardless of whether it's about to run, which would
        # destroy the still-valid cached result of a test left unchanged.
        clean_test_results( testable.paths[:results], testable.name ) if testable.executable_rebuilt

        arg_hash = {
          context:       state.context,
          test_name:     testable.name,
          test_filepath: testable.filepath,
          executable:    testable.executable,
          result:        testable.results_pass,
          options:       state.options,
          skipped:       !testable.executable_rebuilt
        }

        run_fixture_now( **arg_hash )

      ensure
        @plugin_manager.post_test( testable.filepath )
      end
    end
  end

  # -----------------------------------------------------------------------
  # Helper methods
  # -----------------------------------------------------------------------

  def generate_executable_now(context:, build_path:, executable:, objects:, flags:, lib_args:, lib_paths:, options:)
    begin
      @generator.generate_executable_file(
        options[:test_linker],
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
        notice +=   "NOTE: A test file directs the build of a test executable with #include statemetns:\n" +
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
                    "     build diective macro in this test to inject a source file into the build.\n\n" +
                    "See the docs on conventions, paths, preprocessing, compilation symbols, and build directive macros.\n\n"

        @loginator.log( notice, Verbosity::COMPLAIN, LogLabels::NOTICE )
      end

      raise ex
    end
  end

  def clean_test_results(path, test)
    @file_wrapper.rm_f( Dir.glob( File.join( path, test + '.*' ) ) )
  end

  def run_fixture_now(context:, test_name:, test_filepath:, executable:, result:, options:, skipped: false)
    @generator.generate_test_results(
      tool:          options[:test_fixture],
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

  # Compile a single C or assembly source file into an object file.
  def compile_test_component(context:, test:, source:, object:, state:)
    testable     = state.testables[test.to_sym]
    defines      = testable.compile_defines
    search_paths = tailor_search_paths( search_paths: testable.search_paths, filepath: source )
    dependencies = @file_path_utils.form_test_dependencies_filepath( object, name: test, context: context )

    if @file_wrapper.extname( source ) != @configurator.extension_assembly
      flags = testable.compile_flags
      stale = register_and_check_object_staleness( object: object, source: source, dependencies: dependencies, flags: flags, defines: defines, search_paths: search_paths )

      return unless stale

      arg_hash = {
        tool:         @configurator.tools_test_compiler,
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
      stale = register_and_check_object_staleness( object: object, source: source, dependencies: dependencies, flags: flags, defines: defines, search_paths: search_paths )

      return unless stale

      arg_hash = {
        tool:         @configurator.tools_test_assembler,
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
      return
    end

    # A real (re)compile just happened -- register_gcc_deps_file again to pick
    # up the freshly-written `.d` file's current header set (only produced for
    # C compiles; a no-op call for assembly, whose tool has no -MMD/-MF) before
    # recording this target's new baseline.
    @dependinator.register_gcc_deps_file( dependencies ) if @file_wrapper.exist?( dependencies )
    @dependinator.mark_fresh( object )
  end

  # Registers `object`'s antecedents (its source file, plus whatever headers
  # gcc's `-MMD -MF` discovered on the *previous* successful compile, if any)
  # and reports whether it needs (re)building. The previous run's `.d` file is
  # the only header list available before this run's compile has happened --
  # if headers changed, that's exactly what makes this stale.
  def register_and_check_object_staleness(object:, source:, dependencies:, flags:, defines:, search_paths:)
    @dependinator.register( object, files: [source], meta: { flags: flags, defines: defines, search_paths: search_paths } )
    @dependinator.register_gcc_deps_file( dependencies ) if @file_wrapper.exist?( dependencies )
    @dependinator.stale?( object )
  end

  def tailor_search_paths(filepath:, search_paths:)
    _search_paths = []

    if filepath == File.join( PROJECT_BUILD_VENDOR_UNITY_PATH, UNITY_C_FILE )
      _search_paths += @configurator.collection_paths_support
      _search_paths << PROJECT_BUILD_VENDOR_UNITY_PATH

    elsif @configurator.project_use_mocks and
          (filepath == File.join( PROJECT_BUILD_VENDOR_CMOCK_PATH, CMOCK_C_FILE ))
      _search_paths += @configurator.collection_paths_support
      _search_paths << PROJECT_BUILD_VENDOR_UNITY_PATH
      _search_paths << PROJECT_BUILD_VENDOR_CMOCK_PATH
      _search_paths << PROJECT_BUILD_VENDOR_CEXCEPTION_PATH if @configurator.project_use_exceptions

    elsif @configurator.project_use_exceptions and
          (filepath == File.join( PROJECT_BUILD_VENDOR_CEXCEPTION_PATH, CEXCEPTION_C_FILE ))
      _search_paths += @configurator.collection_paths_support
      _search_paths << PROJECT_BUILD_VENDOR_CEXCEPTION_PATH

    elsif @configurator.collection_all_support.include?( filepath )
      _search_paths  = search_paths
      _search_paths += @configurator.collection_paths_support
      _search_paths << PROJECT_BUILD_VENDOR_UNITY_PATH
      _search_paths << PROJECT_BUILD_VENDOR_CMOCK_PATH      if @configurator.project_use_mocks
      _search_paths << PROJECT_BUILD_VENDOR_CEXCEPTION_PATH if @configurator.project_use_exceptions
    end

    return search_paths if _search_paths.empty?

    return _search_paths.uniq
  end

  def validate_build_directive_source_files(test:, filepath:)
    sources = @test_context_extractor.lookup_build_directive_sources_list( filepath )

    ext_message = @configurator.extension_source
    if @configurator.test_build_use_assembly
      ext_message += " or #{@configurator.extension_assembly}"
    end

    sources.each do |source|
      valid_extension = true

      if not @configurator.test_build_use_assembly
        valid_extension = false if @file_wrapper.extname( source ) != @configurator.extension_source
      else
        ext = @file_wrapper.extname( source )
        valid_extension = false if (ext != @configurator.extension_assembly) and (ext != @configurator.extension_source)
      end

      if not valid_extension
        error = "File '#{source}' specified with TEST_SOURCE_FILE() in #{test} is not a #{ext_message} source file"
        raise CeedlingException.new( error )
      end

      if @file_finder.find_build_input_file( filepath: source, complain: :ignore, context: TEST_SYM ).nil?
        error = "File '#{source}' specified with TEST_SOURCE_FILE() in #{test} cannot be found in the source file collection"
        raise CeedlingException.new( error )
      end
    end
  end

  def remove_partials_source_objects(objects, configs)
    modules = configs.keys
    objects.delete_if do |filepath|
      modules.include?( File.basename( filepath ).ext() )
    end
  end

end
