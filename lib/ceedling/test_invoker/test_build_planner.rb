# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'

class TestBuildPlanner

  constructor(
    :configurator,
    :loginator,
    :reportinator,
    :batchinator,
    :test_context_extractor,
    :partializer,
    :file_finder,
    :file_path_utils,
    :file_wrapper,
    :plugin_manager
  )

  def setup()
    @context_extractor = @test_context_extractor
  end

  # Stage 5: Determine runners, mocks, and partials for all tests.
  def stage_determine_files(state)
    @batchinator.exec(workload: :compile, things: state.testables) do |_, testable|
      test     = testable.name
      filepath = testable.filepath

      runner_filepath = @file_path_utils.form_runner_filepath_from_test( filepath )

      mocks   = {}
      _mocks  = @context_extractor.lookup_mock_header_includes_list( filepath )

      _mocks.each do |include|
        name   = File.basename( include.filename ).ext()
        source = nil
        input  = nil

        if is_mock_partial?( include )
          source = gnerate_header_input_for_mock_partial( include, test )
          input  = source
        else
          source            = find_header_input_for_mock( include )
          preprocessed_input = @file_path_utils.form_preprocessed_file_filepath( source, test )
          input             = (@configurator.project_use_test_preprocessor_mocks ? preprocessed_input : source)
        end

        mocks[name.to_sym] = {
          name:     name,
          filepath: include.filepath,
          path:     include.path,
          source:   source,
          input:    input
        }
      end

      partials_configs = {}
      if @configurator.project_use_partials
        partials_configs = assemble_partials_config( filepath: filepath )
      end

      state.lock.synchronize do
        testable.runner = {
          output_filepath: runner_filepath,
          input_filepath:  filepath
        }
        testable.mocks    = mocks
        testable.partials = { configs: partials_configs }

        @plugin_manager.pre_test( filepath )
      end
    end
  end

  # Transform T1: Flatten partials into parallel-processing-friendly lists.
  def stage_flatten_partials_lists(state)
    state.testables.each do |_, testable|
      testable.partials[:configs].each do |_, config|
        state.partials_headers << {
          config:                   config.header,
          testable:                 testable,
          directives_only_filepath: nil
        } if config.header.filepath

        state.partials_sources << {
          config:                   config.source,
          testable:                 testable,
          directives_only_filepath: nil
        } if config.source.filepath
      end
    end
  end

  # Transform T2: Flatten mocks into a parallel-processing-friendly list.
  def stage_flatten_mocks_list(state)
    state.testables.each do |_, testable|
      testable.mocks.each do |name, elems|
        state.mocks_list << {
          name:                     name,
          details:                  elems,
          testable:                 testable,
          directives_only_filepath: nil
        }
      end
    end
  end

  # Stage 14: Determine the full set of objects to compile and link for each test.
  def stage_determine_artifacts(state)
    @batchinator.exec(workload: :compile, things: state.testables) do |_, testable|
      filepath  = testable.filepath
      mock_list = @context_extractor.lookup_mock_header_includes_list( filepath )

      test_sources = extract_sources( state.context, filepath, testable.partials[:configs] )
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
      compilations << testable.runner[:output_filepath]
      compilations += test_frameworks
      compilations += test_support
      compilations.uniq!

      test_objects     = @file_path_utils.form_test_build_objects_filelist( testable.paths[:build], compilations )
      test_executable  = @file_path_utils.form_test_executable_filepath( testable.paths[:build], filepath )
      test_pass        = @file_path_utils.form_pass_results_filepath( testable.paths[:results], filepath )
      test_fail        = @file_path_utils.form_fail_results_filepath( testable.paths[:results], filepath )

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
        testable.no_link_objects = test_no_link_objects
        testable.results_pass    = test_pass
        testable.results_fail    = test_fail
        testable.tool            = TOOLS_TEST_COMPILER
      end
    end
  end

  # Transform T3: Flatten testable objects into a parallel-processing-friendly list.
  def stage_flatten_objects_list(state)
    state.objects_list = state.testables.map do |_, testable|
      testable.objects.map do |obj|
        {
          tool: testable.tool,
          test: testable.name,
          obj:  obj
        }
      end
    end.flatten
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
        if @file_wrapper.exist?( helper.ext( EXTENSION_SOURCE ) )
          sources << helper
        end
      end
    end

    return sources
  end

  def extract_sources(context, test_filepath, partials_configs)
    sources = []

    _sources = @test_context_extractor.lookup_build_directive_sources_list( test_filepath )
    _sources.each do |source|
      sources << @file_finder.find_build_input_file( filepath: source, complain: :ignore, context: context )
    end

    _support_headers = COLLECTION_ALL_SUPPORT.map { |filepath| File.basename( filepath ).ext( EXTENSION_HEADER ) }

    includes = @test_context_extractor.lookup_all_header_includes_list( test_filepath )
    includes.each do |include|
      _basename = include.filename
      next if _basename == UNITY_H_FILE
      next if _basename.start_with?( CMOCK_MOCK_PREFIX )
      next if _support_headers.include?( _basename )

      sources << @file_finder.find_build_input_file( filepath: include.filename, complain: :ignore, context: context )
    end

    partials_configs.each do |_module, _|
      sources << @file_finder.find_build_input_file( filepath: _module, complain: :ignore, context: context )
    end

    return sources.compact.uniq
  end

  def fetch_shallow_source_includes(test_filepath)
    return @test_context_extractor.lookup_source_includes_list( test_filepath )
  end

  def fetch_include_search_paths_for_test_file(test_filepath)
    return @test_context_extractor.lookup_include_paths_list( test_filepath )
  end

  def find_header_input_for_mock(mock)
    return @file_finder.find_header_input_for_mock( mock.filename )
  end

  def is_mock_partial?(mock)
    return mock.filename.start_with?( @configurator.cmock_mock_prefix + PARTIAL_FILENAME_PREFIX )
  end

  def gnerate_header_input_for_mock_partial(mock, test)
    return @file_path_utils.form_partial_header_filepath(
      test,
      mock.filename.delete_prefix( @configurator.cmock_mock_prefix )
    )
  end

  def form_partials_filenames(partials)
    return partials.map { |partial| @file_path_utils.form_partial_implementation_source_filename( partial ) }
  end

  def remove_mock_original_headers(filelist, mocklist)
    filelist.delete_if do |filepath|
      mocklist.include?( @configurator.cmock_mock_prefix + File.basename( filepath ).ext( EXTENSION_CORE_HEADER ) )
    end
  end

  def remove_partials_source_objects(objects, configs)
    modules = configs.keys
    objects.delete_if do |filepath|
      modules.include?( File.basename( filepath ).ext() )
    end
  end

end
