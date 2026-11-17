# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Rigging for a test file's #include extraction, stages 2 through 4, with GCC running
# for real.
#
# The stage objects are real: TestContextExtractor's text scan (stage 2), TestSearchPaths
# (stage 3), and TestIncludesExtractinator's three passes with their StandinHeaderinator, MockLocator,
# FileFinder, and the Preprocessinator graph from spec_integration_helper.rb (stage 4).
# IncludePathinator is real too. Thin stand-ins replace only what would drag in a whole
# build: a configurator holding one small project's settings, a dependency tracker that
# always reports stale, a sequential batchinator, and a file path utility rooted in the
# scratch tree.
#
# A harness works in the current directory, a project root holding `src/` and `test/`,
# as a real build does.

require 'spec_integration_helper'
require 'ceedling/filename_extension'
require 'ceedling/filesystem/file_finder'
require 'ceedling/filesystem/file_finder_helper'
require 'ceedling/includes/include_pathinator'
require 'ceedling/test_context_extractor'
require 'ceedling/test_invoker/test_invoker_types'
require 'ceedling/test_invoker/test_search_paths'
require 'ceedling/test_invoker/mock_locator'
require 'ceedling/test_invoker/test_derived_search_paths'
require 'ceedling/test_invoker/standin_headerinator'
require 'ceedling/test_invoker/test_includes_extractinator'
require 'ceedling/test_invoker/test_bare_includes_extractinator'
require 'ceedling/test_invoker/test_includes_preprocessinator'
require 'ceedling/test_invoker/test_includes_reconcilinator'

module IntegrationSpecHelpers

  # One small project: sources and headers under src/, tests under test/, mocks named
  # with a `mock_` prefix. `include_paths` and `all_headers`, when given, replace every
  # directory below src/ and every header below it.
  class TestIncludesConfigurator < StubConfigurator
    attr_reader :test_build_preprocess_directives_only_available

    def initialize(directives_only:, bare_tool: DEFAULT_TEST_BARE_INCLUDES_PREPROCESSOR_TOOL, include_paths: nil, all_headers: nil)
      super( bare_tool: bare_tool )
      @test_build_preprocess_directives_only_available = directives_only
      @include_paths = include_paths
      @all_headers   = all_headers
    end

    def cmock_mock_path
      'build/mocks'
    end

    def get_cmock_config
      {}
    end

    def cmock_mock_name_include_folder
      true
    end
    def project_use_mocks
      true
    end
    def project_use_partials
      false
    end
    def project_use_test_preprocessor_tests
      true
    end
    def test_build_preprocess_force_fallback
      !@test_build_preprocess_directives_only_available
    end
    def project_build_root
      'build'
    end

    def project_build_vendor_ceedling_path
      'build/vendor'
    end
    def extension_header
      FilenameExtension.new( '.h' )
    end
    def extension_source
      FilenameExtension.new( '.c' )
    end
    def paths_test
      ['test']
    end
    def paths_support
      []
    end
    def paths_include
      ['src']
    end
    # The canonical roots configuration computes from the three above
    def collection_mirror_roots_headers
      ['test', 'src']
    end
    def collection_mirror_roots_include
      ['src']
    end
    def collection_paths_test
      ['test']
    end
    def collection_paths_support
      []
    end
    def collection_paths_include
      @include_paths || Dir.glob( 'src/**/' ).map { |dir| dir.chomp( '/' ) }.sort
    end
    def collection_paths_libraries
      []
    end
    def collection_paths_vendor
      []
    end
    def collection_paths_test_toolchain_include
      []
    end
    def collection_all_headers
      @all_headers || Dir.glob( 'src/**/*.h' ).sort
    end
  end

  # Scratch locations, plus where mocks and Partials sit, composed as FilePathUtils
  # composes them
  class TestIncludesFilePathUtils < ScratchFilePathUtils
    def form_mock_header_filepath(subdir, filename)
      File.join( 'build/mocks', subdir, filename.ext( '.h' ) )
    end

    def form_partial_header_filepath(subdir, filename)
      File.join( 'build/partials', subdir, filename )
    end

    def form_mock_output_path(root, subdir)
      subdir.nil? || subdir.empty? ? root : File.join( root, subdir )
    end
  end

  class StaleDependinator
    def register(_target, **_options); end
    def stale?(_target)
      true
    end
    def mark_fresh(_target); end
  end

  class SequentialBatchinator
    def exec(things:, **_options)
      things.each { |key, value| yield key, value }
    end
  end

  # Runs stages 2 through 4 for one test file and reports what the build would use
  class TestIncludesHarness
    attr_reader :context_extractor

    def initialize(directives_only:, bare_tool: DEFAULT_TEST_BARE_INCLUDES_PREPROCESSOR_TOOL, include_paths: nil, all_headers: nil)
      @cfg = TestIncludesConfigurator.new(
        directives_only: directives_only, bare_tool: bare_tool, include_paths: include_paths, all_headers: all_headers
      )
      @file_wrapper = FileWrapper.new( loginator: NULL, verbosinator: NULL )
      @fpu          = TestIncludesFilePathUtils.new( 'build/scratch' )

      @context_extractor = TestContextExtractor.new(
        configurator: @cfg, parsing_parcels: ParsingParcels.new, include_factory: IncludeFactory.new( configurator: @cfg ),
        partializer_config: NULL, file_path_utils: @fpu, file_wrapper: @file_wrapper, yaml_wrapper: NULL, loginator: NULL
      )
      @context_extractor.setup

      @headers = IncludePathinator.new(
        configurator: @cfg, test_context_extractor: @context_extractor, loginator: NULL, file_wrapper: @file_wrapper
      )
      @headers.setup

      @search_paths = TestSearchPaths.new( configurator: @cfg, include_pathinator: @headers, test_context_extractor: @context_extractor )
      @locator      = MockLocator.new(
        configurator: @cfg, include_pathinator: @headers, test_search_paths: @search_paths, file_finder: file_finder, file_path_utils: @fpu
      )
      @derived = TestDerivedSearchPaths.new(
        configurator: @cfg, include_pathinator: @headers, test_search_paths: @search_paths, test_context_extractor: @context_extractor,
        file_finder: file_finder, file_wrapper: @file_wrapper, loginator: NULL
      )
      @derived.setup
      @extractinator = build_extractinator
    end

    # Stages 2 through 4 for `filepath`, preprocessing with `flags`. Returns the Testable
    # the later stages would read.
    def run(filepath, defines: [], flags: [])
      testable = testable_for( filepath, defines, flags )
      @context_extractor.collect_simple_context_from_file( filepath, nil, TestContextExtractor::Context::INCLUDES )

      # Stage 2's derived and tolerant mock search paths, and stage 3's search paths
      testable.derived_search_paths, testable.search_path_refusals = @derived.collect( testable )
      testable.mock_search_paths = @locator.directories(
        @context_extractor.lookup_mock_header_includes_list( filepath ), mocks_root: testable.paths[:mocks],
        collection: @locator.header_search( testable ), complain: :silent
      )
      testable.search_paths = @search_paths.compose( testable )

      state = TestInvokerTypes::PipelineState.new( testables: { testable.name.to_sym => testable }, context: :test, options: [], lock: Mutex.new )
      @extractinator.stage_collect_preprocessor_context( state )

      return testable
    end

    # The #includes the rest of the build would use for `filepath`, as rendered strings
    def includes(filepath)
      @context_extractor.lookup_all_header_includes_list( filepath ).map( &:filename )
    end

    def mocks(filepath)
      @context_extractor.lookup_mock_header_includes_list( filepath ).map( &:filename )
    end

    # How the later stages find `testable`'s real headers
    def header_search(testable)
      return @locator.header_search( testable )
    end

    private

    def file_finder
      finder = FileFinder.new(
        configurator: @cfg, file_finder_helper: FileFinderHelper.new( loginator: NULL ),
        file_path_utils: @fpu, file_wrapper: @file_wrapper, yaml_wrapper: NULL
      )
      return finder
    end

    def build_extractinator
      handler = PreprocessinatorIncludesHandler.new(
        configurator: @cfg, include_factory: IncludeFactory.new( configurator: @cfg ),
        preprocessinator_line_marker_includes_extractor: PreprocessinatorLineMarkerIncludesExtractor.new(
          include_factory: IncludeFactory.new( configurator: @cfg ), file_wrapper: @file_wrapper
        ),
        tool_executor: ShellingToolExecutor.new, file_wrapper: @file_wrapper, file_path_utils: @fpu, yaml_wrapper: YamlWrapper.new( file_wrapper: @file_wrapper ),
        parsing_parcels: ParsingParcels.new, quote_include_isolator: QuoteIncludeIsolator.new( file_wrapper: @file_wrapper, loginator: NULL ),
        loginator: NULL, reportinator: NULL
      )
      handler.setup

      preprocessinator = Preprocessinator.new(
        preprocessinator_includes_handler: handler, preprocessinator_comment_stripper: NULL, preprocessinator_file_assembler: NULL,
        preprocessinator_reconstructor: NULL, file_path_utils: @fpu, file_wrapper: @file_wrapper, tool_executor: ShellingToolExecutor.new,
        plugin_manager: NULL, configurator: @cfg, loginator: NULL, reportinator: NULL
      )
      preprocessinator.setup

      standins = StandinHeaderinator.new(
        configurator: @cfg, loginator: NULL, reportinator: NULL, file_wrapper: @file_wrapper, file_path_utils: @fpu, mock_locator: @locator
      )

      common = { configurator: @cfg, loginator: NULL, reportinator: NULL, batchinator: SequentialBatchinator.new, preprocessinator: preprocessinator }
      return TestIncludesExtractinator.new(
        test_bare_includes_extractinator: TestBareIncludesExtractinator.new(
          **common, file_path_utils: @fpu, dependinator: StaleDependinator.new, test_search_paths: @search_paths, standin_headerinator: standins
        ),
        test_includes_preprocessinator: TestIncludesPreprocessinator.new(
          **common, file_path_utils: @fpu, file_wrapper: @file_wrapper, dependinator: StaleDependinator.new
        ),
        test_includes_reconcilinator: TestIncludesReconcilinator.new(
          **common, test_context_extractor: @context_extractor, test_search_paths: @search_paths, mock_locator: @locator
        )
      )
    end

    def testable_for(filepath, defines, flags)
      name = File.basename( filepath, '.c' )
      return TestInvokerTypes::Testable.new(
        name: name, filepath: filepath, paths: { mocks: File.join( 'build/mocks', name ) },
        preprocess: { includes: [], directives_only: { filepath: nil }, fallback_expansion: { filepath: nil } },
        preprocess_flags: flags, preprocess_defines: defines, search_paths: [], mock_search_paths: []
      )
    end
  end

end
