# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Runs stage 7 for one Partial source the way a build does: the real
# PartialFilesPreprocessinator over the real Preprocessinator graph, a real compiler, and a
# real dependency tracker whose store persists between runs. Each run is one build.
# Configuration, path layout, batching, logging and plugins are stand-ins.

require 'spec_integration_helper'
require 'test_includes_harness'
require 'ceedling/preprocess/c_comment_scanner'
require 'ceedling/preprocess/preprocessinator_comment_stripper'
require 'ceedling/preprocess/preprocessinator_reconstructor'
require 'ceedling/preprocess/preprocessinator_file_assembler'
require 'ceedling/test_invoker/test_invoker_types'
require 'ceedling/test_invoker/partial_files_preprocessinator'
require 'ceedling/partials/partials'

module IntegrationSpecHelpers

  # A preprocessor tool that fails before reading its input
  def self.failing_tool(tool)
    return tool.merge( arguments: ['--ceedling-unrecognized-option'] + tool[:arguments] ).freeze
  end

  class PartialFilesConfigurator < StubConfigurator
    attr_reader :test_build_preprocess_directives_only_available, :tools_test_file_directives_only_preprocessor,
                :tools_test_file_full_preprocessor

    def initialize(directives_only:, directives_only_tool:, full_tool:)
      super()
      @test_build_preprocess_directives_only_available = directives_only
      @tools_test_file_directives_only_preprocessor    = directives_only_tool
      @tools_test_file_full_preprocessor               = full_tool
    end

    def test_build_preprocess_force_fallback
      false
    end

    def get_partials_config
      {}
    end

    def project_build_root
      'build'
    end

    def project_build_vendor_ceedling_path
      'build/vendor'
    end
  end

  # Every preprocessed artifact below one test's directory, mirroring each file's path
  class PartialFilesFilePathUtils
    # The bare pass isolates a copy of the file below this directory
    def form_test_preprocess_files_path(test)
      return File.join( 'build/preprocess/files', test ).tap { |dir| FileUtils.mkdir_p( dir ) }
    end

    def preprocessed_file_subpath(filepath, _test = nil)
      return filepath
    end

    def form_preprocessed_file_filepath(filepath, test)
      return artifact( test, nil, filepath )
    end

    def form_preprocessed_file_raw_directives_only_filepath(filepath, test)
      return artifact( test, 'directives_only/raw', filepath )
    end

    def form_preprocessed_file_compacted_directives_only_filepath(filepath, test)
      return artifact( test, 'directives_only', filepath )
    end

    def form_preprocessed_file_full_expansion_filepath(filepath, test)
      return artifact( test, 'full_expansion', filepath )
    end

    def form_preprocessed_file_expanded_code_filepath(filepath, test)
      return artifact( test, 'expanded_code', filepath )
    end

    def form_preprocessed_includes_list_filepath(filepath, test)
      return File.join( 'build/preprocess/includes', test, filepath + '.yml' )
    end

    private

    def artifact(test, kind, filepath)
      return File.join( *['build/preprocess/files', test, kind, filepath].compact )
    end
  end

  class PartialFilesHarness
    attr_reader :configurator

    def initialize(directives_only: true, directives_only_tool: DEFAULT_TEST_FILE_DIRECTIVES_ONLY_PREPROCESSOR_TOOL,
                   full_tool: DEFAULT_TEST_FILE_FULL_PREPROCESSOR_TOOL)
      @configurator = PartialFilesConfigurator.new(
        directives_only: directives_only, directives_only_tool: directives_only_tool, full_tool: full_tool
      )
      @file_wrapper = FileWrapper.new( loginator: NULL, verbosinator: NULL )
      @fpu          = PartialFilesFilePathUtils.new
    end

    # One build's stage 7 over `filepath`, giving the file's record. `tracker` is opened on a
    # store that persists between runs. It is flushed as a build ends, so the next run sees
    # what this one recorded.
    def run_source(filepath, tracker:, test: 'test_widget')
      config   = Partials::ConfigFileInfo.new( filepath: filepath )
      testable = TestInvokerTypes::Testable.new(
        name: test, filepath: "test/#{test}.c", preprocess_flags: [], preprocess_defines: [], search_paths: ['src']
      )
      state = TestInvokerTypes::PipelineState.new(
        testables: { test.to_sym => testable }, partials_headers: [], context: :test, options: [], lock: Mutex.new,
        partials_sources: [TestInvokerTypes::PartialWork.new( config: config, testable: testable )]
      )

      stage( tracker ).preprocess_sources( state )
      tracker.flush

      return config
    end

    def artifact_paths(filepath, test: 'test_widget')
      return {
        raw_directives_only: @fpu.form_preprocessed_file_raw_directives_only_filepath( filepath, test ),
        raw_expansion:       @fpu.form_preprocessed_file_full_expansion_filepath( filepath, test ),
        expanded_code:       @fpu.form_preprocessed_file_expanded_code_filepath( filepath, test )
      }
    end

    private

    def stage(tracker)
      return PartialFilesPreprocessinator.new(
        configurator: @configurator, loginator: NULL, reportinator: NULL, batchinator: SequentialBatchinator.new,
        preprocessinator: preprocessinator, file_path_utils: @fpu, file_wrapper: @file_wrapper, dependinator: tracker
      )
    end

    def preprocessinator
      factory       = IncludeFactory.new( configurator: @configurator, test_build_layout: TestBuildLayout.new( configurator: @configurator, file_wrapper: @file_wrapper ) )
      tool_executor = ShellingToolExecutor.new
      reconstructor = PreprocessinatorReconstructor.new( parsing_parcels: ParsingParcels.new, file_wrapper: @file_wrapper )

      handler = PreprocessinatorIncludesHandler.new(
        configurator: @configurator, include_factory: factory,
        preprocessinator_line_marker_includes_extractor: PreprocessinatorLineMarkerIncludesExtractor.new(
          include_factory: factory, file_wrapper: @file_wrapper
        ),
        tool_executor: tool_executor, file_wrapper: @file_wrapper, file_path_utils: @fpu,
        yaml_wrapper: YamlWrapper.new( file_wrapper: @file_wrapper ), parsing_parcels: ParsingParcels.new,
        quote_include_isolator: QuoteIncludeIsolator.new( file_wrapper: @file_wrapper, loginator: NULL ),
        loginator: NULL, reportinator: NULL
      )
      handler.setup

      assembler = PreprocessinatorFileAssembler.new(
        preprocessinator_reconstructor: reconstructor, configurator: @configurator, tool_executor: tool_executor,
        file_path_utils: @fpu, file_wrapper: @file_wrapper, parsing_parcels: ParsingParcels.new, loginator: NULL,
        reportinator: NULL, build_step_doctor: NULL
      )

      return Preprocessinator.new(
        preprocessinator_includes_handler: handler,
        preprocessinator_comment_stripper: PreprocessinatorCommentStripper.new( c_comment_scanner: CCommentScanner.new, file_wrapper: @file_wrapper ),
        preprocessinator_file_assembler: assembler, preprocessinator_reconstructor: reconstructor, file_path_utils: @fpu,
        file_wrapper: @file_wrapper, tool_executor: tool_executor, plugin_manager: NULL, configurator: @configurator,
        loginator: NULL, reportinator: NULL
      ).tap( &:setup )
    end
  end

end
