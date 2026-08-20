# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/test_invoker/test_invoker_types'
require 'ceedling/test_invoker/test_pipeline_helpers'
require 'ceedling/includes/includes'

class TestBuildPlanner

  include TestInvokerTypes
  include TestPipelineHelpers

  constructor(
    :configurator,
    :loginator,
    :reportinator,
    :batchinator,
    :test_context_extractor,
    :include_pathinator,
    :partializer,
    :file_finder,
    :file_path_utils,
    :file_wrapper,
    :plugin_manager,
    :test_source_file_directive_resolver
  )

  def setup()
    @context_extractor = @test_context_extractor
  end

  # Stage 5: Determine runners, mocks, and partials for all tests.
  def stage_determine_files(state)
    @batchinator.exec(workload: :compile, things: state.testables) do |_, testable|
      test     = testable.name
      filepath = testable.filepath

      runner_filepath = @file_path_utils.form_runner_filepath_from_test( filepath, name: test )

      mocks   = {}
      _mocks  = @context_extractor.lookup_mock_header_includes_list( filepath )

      _mocks.each do |include|
        name   = File.basename( include.filename ).ext()
        source = nil
        input  = nil
        subdir = ''

        if mock_partial?( include )
          source = generate_header_input_for_mock_partial( include, test )
          input  = source
        else
          source, subdir     = @file_finder.resolve_mock( include.filepath, collection: ordered_mock_header_collection( testable ) )
          preprocessed_input = @file_path_utils.form_preprocessed_file_filepath( source, test )
          input             = (@configurator.project_use_test_preprocessor_mocks ? preprocessed_input : source)
        end

        # Mirrors the resolved header's own subdirectory below whichever configured root
        # contains it -- the same directory this test's own search paths already carry
        # (collect_mock_search_paths, stage 2, ahead of stage 3), so the mock stays findable
        # by the compiler regardless of how much path the #include itself happened to spell
        # out. A Partial mock has no real header to resolve against, so it stays flat -- the
        # empty default `subdir` already reflects that.
        mocks[name.to_sym] = MockDetails.new(
          name:     name,
          filepath: source,
          path:     subdir,
          source:   source,
          input:    input
        )
      end

      validate_header_includes( test_filepath: filepath, testable: testable )

      partials_configs = {}
      if @configurator.project_use_partials
        partials_configs = assemble_partials_config( filepath: filepath )
      end

      # `pre_test` runs outside the lock -- it's a plugin hook, not a write into
      # shared state, and holding the shared mutex around arbitrary plugin code
      # would serialize every test's hook invocation behind one global lock.
      state.lock.synchronize do
        testable.runner = RunnerInfo.new(
          output_filepath: runner_filepath,
          input_filepath:  filepath
        )
        testable.mocks    = mocks
        testable.partials.configs = partials_configs
      end

      @plugin_manager.pre_test( filepath )
    end
  end

  # Transform T1: Flatten partials into parallel-processing-friendly lists.
  def stage_flatten_partials_lists(state)
    state.testables.each do |_, testable|
      testable.partials.configs.each do |_, config|
        state.partials_headers << PartialWork.new(
          config:                   config.header,
          testable:                 testable,
          directives_only_filepath: nil
        ) if config.header.filepath

        state.partials_sources << PartialWork.new(
          config:                   config.source,
          testable:                 testable,
          directives_only_filepath: nil
        ) if config.source.filepath
      end
    end
  end

  # Transform T2: Flatten mocks into a parallel-processing-friendly list.
  def stage_flatten_mocks_list(state)
    state.testables.each do |_, testable|
      testable.mocks.each do |name, elems|
        state.mocks_list << MockWork.new(
          name:                     name,
          details:                  elems,
          testable:                 testable,
          directives_only_filepath: nil
        )
      end
    end
  end

  # Stage 14: Determine the full set of objects to compile and link for each test.
  def stage_determine_artifacts(state)
    @batchinator.exec(workload: :compile, things: state.testables) do |_, testable|
      filepath  = testable.filepath
      mock_list = @context_extractor.lookup_mock_header_includes_list( filepath )

      test_sources = extract_sources( state.context, filepath, testable.partials )
      test_core    = test_sources +
                     mock_list.map { |mock| mock.filename.ext( EXTENSION_CORE_SOURCE ) }

      remove_mock_original_headers(
        test_core,
        mock_list.map { |mock| mock.filename }
      )

      test_frameworks   = collect_test_framework_sources( !testable.mocks.empty? )
      test_support      = @configurator.collection_all_support

      compilations  = []
      compilations << filepath
      compilations += test_core
      compilations << testable.runner.output_filepath
      compilations += test_frameworks
      compilations += test_support
      compilations.uniq!

      test_objects     = @file_path_utils.form_test_build_objects_filelist( testable.paths[:build], compilations )
      test_executable  = @file_path_utils.form_test_executable_filepath( testable.paths[:build], filepath )
      test_pass        = @file_path_utils.form_pass_results_filepath( testable.paths[:results], filepath )

      test_no_link_objects =
        @file_path_utils.form_test_build_objects_filelist(
          testable.paths[:build],
          fetch_shallow_source_includes( filepath )
        )

      test_objects = (test_objects.uniq - test_no_link_objects)

      state.lock.synchronize do
        testable.sources         = test_sources
        testable.frameworks      = test_frameworks
        testable.core            = test_core
        testable.objects         = test_objects
        testable.executable      = test_executable
        testable.results_pass    = test_pass
      end
    end
  end

  # Transform T3: Flatten testable objects into a parallel-processing-friendly list.
  def stage_flatten_objects_list(state)
    state.objects_list = state.testables.flat_map do |_, testable|
      testable.objects.map do |obj|
        ObjectWork.new( test: testable.name, obj: obj )
      end
    end
  end

  # -----------------------------------------------------------------------
  # Helper methods
  # -----------------------------------------------------------------------

  def assemble_partials_config(filepath:)
    configs = @test_context_extractor.lookup_partials_config( filepath )
    return @partializer.populate_filepaths( configs )
  end

  def collect_test_framework_sources(mocks)
    sources = []
    sources << File.join( PROJECT_BUILD_VENDOR_UNITY_PATH, UNITY_C_FILE )
    sources << File.join( PROJECT_BUILD_VENDOR_CMOCK_PATH, CMOCK_C_FILE )       if @configurator.project_use_mocks and mocks
    sources << File.join( PROJECT_BUILD_VENDOR_CEXCEPTION_PATH, CEXCEPTION_C_FILE ) if @configurator.project_use_exceptions

    if @configurator.project_use_mocks
      @configurator.cmock_unity_helper_path.each do |helper|
        if @file_wrapper.exist?( helper.ext( EXTENSION_SOURCE.primary ) )
          sources << helper
        end
      end
    end

    return sources
  end

  def extract_sources(context, test_filepath, partials)
    sources = []

    additive_directive_sources, subtractive_directive_sources =
      @test_source_file_directive_resolver.resolve( test_filepath, context )
    sources.concat( additive_directive_sources )

    # TEST_SOURCE_FILE() is authoritative: a directive-resolved source's own basename
    # (extension-agnostic) takes precedence over whatever the implicit #include
    # convention would separately resolve for a same-named header, so the two
    # conventions never compile two different files for one logical module. Keyed
    # by stem rather than a bare list so the override, when it applies, can name
    # which directive-resolved file actually won.
    directive_by_stem = additive_directive_sources.each_with_object({}) do |path, hash|
      hash[File.basename(path).ext('')] = path
    end

    _support_headers = COLLECTION_ALL_SUPPORT.map { |filepath| File.basename( filepath ).ext( EXTENSION_HEADER.primary ) }

    includes = @test_context_extractor.lookup_all_header_includes_list( test_filepath )
    includes.each do |include|
      _basename = include.filename
      next if _basename == UNITY_H_FILE
      next if _basename.start_with?( CMOCK_MOCK_PREFIX )
      next if _support_headers.include?( _basename )

      stem = File.basename(_basename).ext('')
      if directive_by_stem.key?( stem )
        msg = "TEST_SOURCE_FILE() '#{directive_by_stem[stem]}' overrides the source " \
              "otherwise implicitly matched to '#{include.filepath}' in #{test_filepath}."
        @loginator.log( msg, Verbosity::COMPLAIN, LogLabels::NOTICE )
        next
      end

      sources << @file_finder.find_build_input_file( filepath: include.filepath, complain: :ignore, context: context )
    end

    # Add to the source list any testable Partials (no mock Partials)
    partials.tests.each do |_module|
      sources << @file_finder.find_build_input_file( filepath: _module, complain: :ignore, context: context )
    end

    sources = sources.compact.uniq

    return @test_source_file_directive_resolver.remove_subtracted(
      sources, subtractive: subtractive_directive_sources, test_filepath: test_filepath
    )
  end

  def fetch_shallow_source_includes(test_filepath)
    return @test_context_extractor.lookup_source_includes_list( test_filepath )
  end

  # Reconstructs the ordering collect_mock_search_paths (TestBuildSetup, stage 2) originally
  # saw when it first resolved this same mock's real header -- before this testable's own
  # generated mock directories existed to splice into search_paths. Every call site resolving
  # a mock's real header must agree on the same winner, or Ceedling would place a stand-in
  # header, a mock search path, and the real generated mock in three different directories for
  # one mock.
  def ordered_mock_header_collection(testable)
    @include_pathinator.ordered_header_files( testable.search_paths - testable.mock_search_paths )
  end

  # Every #include naming a real project header -- other than a mock (validated separately,
  # as part of resolving it via FileFinder#resolve_mock), a system header, Unity's or
  # Ceedling's own header, or a Partial (Ceedling's own generated content, not a project file
  # to validate) -- must resolve to exactly one file, existence-wise, among this test's own
  # search_paths (the same directory priority the compiler itself consults): ambiguity among
  # same-named candidates resolves quietly to the first by that order, exactly as the real
  # compile would find it; only a genuinely unresolvable name still halts the build here. A
  # bogus or merely-unmatched path is otherwise never actually checked against real project
  # headers -- only its potential corresponding source file is, tolerantly, elsewhere. Unity's
  # and Ceedling's own headers live in the build's vendor directories, outside every configured
  # :test/:source/:support/:include root a test's search_paths is built from, so neither could
  # ever resolve there.
  def validate_header_includes(test_filepath:, testable:)
    includes = @context_extractor.lookup_nonmock_header_includes_list( test_filepath )

    collection = @include_pathinator.ordered_header_files( testable.search_paths )

    includes.each do |include|
      next if include.is_a?( SystemInclude )
      next if include.filename == UNITY_H_FILE
      next if include.filename == CEEDLING_HEADER_FILENAME
      next if include.filename.start_with?( PARTIAL_FILENAME_PREFIX )

      @file_finder.find_header_file( include.filepath, :error, collection: collection )
    end
  end

  def generate_header_input_for_mock_partial(mock, test)
    return @file_path_utils.form_partial_header_filepath(
      test,
      mock.filename.delete_prefix( @configurator.cmock_mock_prefix )
    )
  end

  def remove_mock_original_headers(filelist, mocklist)
    filelist.delete_if do |filepath|
      mocklist.include?( @configurator.cmock_mock_prefix + File.basename( filepath ).ext( EXTENSION_CORE_HEADER ) )
    end
  end

end
