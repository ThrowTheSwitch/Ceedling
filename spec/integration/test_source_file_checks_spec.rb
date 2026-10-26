# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Checking TEST_SOURCE_FILE() entries against a real project. Real test files are scanned by
# the real context extractor, and the real resolver looks each entry up through the real
# file finder in a temporary project configured by the real configuration pipeline.
#
# Every test once checked every test's entries under its own name, so a typo was blamed on
# whichever test happened to check it, and with test preprocessing off nothing was checked
# at all. A misspelled entry then failed only at link time, or, for a removal, never.

require 'spec_helper'
require 'configurator_integration_helper'
require 'ceedling/parsing_parcels'
require 'ceedling/includes/include_factory'
require 'ceedling/file_finder'
require 'ceedling/file_finder_helper'
require 'ceedling/file_path_utils'
require 'ceedling/test_context_extractor'
require 'ceedling/test_invoker/test_source_file_directive_resolver'
require 'ceedling/test_invoker/test_build_setup'
require 'ceedling/test_invoker/test_invoker_types'

describe 'TEST_SOURCE_FILE() checks (integration)' do
  include ConfiguratorIntegrationHelpers

  # Runs each test of a batch in turn, in place of the thread pool
  class TestSourceFileChecksBatchinator
    def exec(things:, **_options)
      things.each { |key, value| yield key, value }
    end
  end

  def test_file(entries)
    lines = entries.map { |entry| "TEST_SOURCE_FILE(\"#{entry}\")\n" }.join
    return "#include \"unity.h\"\n#{lines}void test_it(void) {}\n"
  end

  def project_files
    return {
      'src/calc.c'        => "int calc(void) { return 1; }\n",
      'src/calc.h'        => "int calc(void);\n",
      'src/a/dup.c'       => "int dup(void) { return 1; }\n",
      'lib/a/dup.c'       => "int dup(void) { return 2; }\n",
      'lib/extra.c'       => "int extra(void) { return 7; }\n",
      'test/test_m1.c'    => test_file( ['calc.c'] ),
      'test/test_m2.c'    => test_file( ['calc.c'] ),
      'test/unit/test_m3.c' => test_file( ['../../lib/extra.c'] )
    }
  end

  def project_yaml(preprocessor: :none)
    return <<~YAML
      :project:
        :build_root: build
        :use_test_preprocessor: :#{preprocessor}
      :paths:
        :test: [test/**]
        :source: [src/**, lib/**]
        :include: [src/**]
    YAML
  end

  def objects
    graph        = configure( project_yaml )
    configurator = graph[:configurator]
    loginator    = graph[:loginator]
    file_wrapper = graph[:file_wrapper]

    file_path_utils = FilePathUtils.new( configurator: configurator, file_wrapper: file_wrapper )
    file_finder     = FileFinder.new(
      configurator: configurator, file_finder_helper: FileFinderHelper.new( loginator: loginator ),
      file_path_utils: file_path_utils, file_wrapper: file_wrapper, yaml_wrapper: graph[:yaml_wrapper]
    )
    extractor = TestContextExtractor.new(
      configurator: configurator, parsing_parcels: ParsingParcels.new, include_factory: IncludeFactory.new( configurator: configurator ),
      partializer_config: double( 'partializer_config' ).as_null_object, file_path_utils: file_path_utils, file_wrapper: file_wrapper,
      yaml_wrapper: graph[:yaml_wrapper], loginator: loginator
    )
    resolver = TestSourceFileDirectiveResolver.new(
      test_context_extractor: extractor, file_finder: file_finder, configurator: configurator, loginator: loginator
    )

    return { configurator: configurator, file_path_utils: file_path_utils, file_finder: file_finder, extractor: extractor, resolver: resolver }
  end

  def scan(extractor, tests)
    tests.each { |test| extractor.collect_simple_context_from_file( test, nil, TestContextExtractor::Context::BUILD_DIRECTIVE_SOURCE_FILES ) }
  end

  it "passes a test's real entries, including one reached through .." do
    in_temp_project( project_files ) do
      o = objects
      tests = %w[test/test_m1.c test/test_m2.c test/unit/test_m3.c]
      scan( o[:extractor], tests )

      tests.each do |test|
        expect { o[:resolver].validate!( test: test.ext( '' ), test_filepath: test, context: :test ) }.to_not raise_error
      end
    end
  end

  it 'names the test that holds a missing entry' do
    in_temp_project( project_files.merge( 'test/test_m2.c' => test_file( ['calc_typo.c'] ) ) ) do
      o = objects
      scan( o[:extractor], %w[test/test_m1.c test/test_m2.c] )

      expect { o[:resolver].validate!( test: 'test/test_m1', test_filepath: 'test/test_m1.c', context: :test ) }.to_not raise_error
      expect { o[:resolver].validate!( test: 'test/test_m2', test_filepath: 'test/test_m2.c', context: :test ) }.to raise_error(
        CeedlingException, %r{'calc_typo\.c' specified with TEST_SOURCE_FILE\(\) in test/test_m2 cannot be found}
      )
    end
  end

  it 'stops for a misspelled removal entry, which otherwise leaves its file in the build' do
    in_temp_project( project_files.merge( 'test/test_m1.c' => test_file( ['-:clac.c'] ) ) ) do
      o = objects
      scan( o[:extractor], %w[test/test_m1.c] )

      expect { o[:resolver].validate!( test: 'test/test_m1', test_filepath: 'test/test_m1.c', context: :test ) }.to raise_error(
        CeedlingException, /'clac\.c'.*cannot be found/
      )
    end
  end

  it 'notes an entry matching several files once, however many tests name it' do
    files = project_files.merge( %w[test/test_m1.c test/test_m2.c test/unit/test_m3.c].to_h { |test| [test, test_file( ['a/dup.c'] )] } )

    in_temp_project( files ) do
      o = objects
      tests = %w[test/test_m1.c test/test_m2.c test/unit/test_m3.c]
      scan( o[:extractor], tests )

      tests.each do |test|
        o[:resolver].validate!( test: test.ext( '' ), test_filepath: test, context: :test )
        o[:resolver].resolve( test, :test )
      end

      expect( logged.grep( /Multiple files matched 'a\/dup\.c'/ ).size ).to eq( 1 )
    end
  end

  # Stage 2 scans the entries when test preprocessing is off, and now checks them there too
  it 'checks each test once, under its own name, in stage 2 without test preprocessing' do
    in_temp_project( project_files.merge( 'test/unit/test_m3.c' => test_file( ['nowhere.c'] ) ) ) do
      o = objects
      setup = TestBuildSetup.new( TestBuildSetup.constructor_keys.to_h { |key| [key, double( key.to_s ).as_null_object] }.merge(
        configurator: o[:configurator], batchinator: TestSourceFileChecksBatchinator.new, test_context_extractor: o[:extractor],
        file_path_utils: o[:file_path_utils], file_finder: o[:file_finder], test_source_file_directive_resolver: o[:resolver],
        file_wrapper: FileWrapper.new( loginator: double( 'loginator', log: nil ), verbosinator: double( 'verbosinator', should_output?: false ) ),
        dependinator: double( 'dependinator', register: nil, stale?: true, mark_fresh: nil ),
        reportinator: double( 'reportinator', generate_progress: '', generate_skip_summary: nil )
      ) )
      tests = %w[test/test_m1.c test/test_m2.c test/unit/test_m3.c]
      state = TestInvokerTypes::PipelineState.new( tests: tests, testables: {}, context: :test, options: [], lock: Mutex.new )
      setup.stage_prepare_build_paths( state )

      expect { setup.stage_collect_test_context( state ) }.to raise_error(
        CeedlingException, %r{'nowhere\.c' specified with TEST_SOURCE_FILE\(\) in test/unit/test_m3 cannot be found}
      )
    end
  end
end
