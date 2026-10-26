# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# How tests are named, across project layouts with same-named tests (GH #1364). A project's YAML runs through the real
# configuration pipeline in a temporary project, so test paths and collections come from
# real globs. A real FilePathUtils names each test, and a real TestBuildSetup prepares its
# directories, as stage 1 of a build does.

require 'spec_helper'
require 'configurator_integration_helper'
require 'ceedling/file_path_utils'
require 'ceedling/file_finder'
require 'ceedling/file_finder_helper'
require 'ceedling/test_invoker/test_build_setup'
require 'ceedling/test_invoker/test_invoker_types'

describe 'Test naming (integration)' do
  include ConfiguratorIntegrationHelpers

  # Runs each test of a batch in turn, in place of the thread pool
  class TestNamingBatchinator
    def exec(things:, **_options)
      things.each { |thing| yield thing }
    end
  end

  # name => [test paths, `:paths ↳ :test` entries, `:files ↳ :test` entries]
  TEST_NAMING_LAYOUTS = {
    'flat and nested under one root' => [%w[test/test_calc.c test/unit/test_calc.c], %w[test/**], []],
    'the same subdirectory under two roots' => [%w[test/unit/test_calc.c extra/unit/test_calc.c], %w[test/unit/** extra/**], []],
    'overlapping roots' => [%w[test/test_calc.c test/unit/test_calc.c], %w[test/** test/unit/**], []],
    'the same layout under two roots' => [%w[test/foo/test_x.c extra/foo/test_x.c], %w[test/** extra/**], []],
    'a :files test outside every root' => [%w[test/test_calc.c other/test_calc.c], %w[test/**], %w[other/test_calc.c]]
  }.freeze

  def project_yaml(test_paths, test_files)
    return <<~YAML
      :project:
        :build_root: build
      :paths:
        :test: #{test_paths.inspect}
        :source: [src/**]
        :include: [src/**]
      :files:
        :test: #{test_files.inspect}
    YAML
  end

  def project_files(tests)
    files = { 'src/calc.c' => "int calc(void) { return 1; }\n", 'src/calc.h' => "int calc(void);\n" }
    tests.each { |test| files[test] = "#include \"unity.h\"\nvoid test_it(void) {}\n" }
    return files
  end

  # Stage 1 of a build of `tests`, with real naming and real directories
  def prepare(configurator, tests)
    file_wrapper    = FileWrapper.new( loginator: double( 'loginator', log: nil ), verbosinator: double( 'verbosinator', should_output?: false ) )
    file_path_utils = FilePathUtils.new( configurator: configurator, file_wrapper: file_wrapper )

    collaborators = TestBuildSetup.constructor_keys.to_h { |key| [key, double( key.to_s )] }
    setup = TestBuildSetup.new( collaborators.merge(
      configurator: configurator, file_wrapper: file_wrapper, file_path_utils: file_path_utils, batchinator: TestNamingBatchinator.new
    ) )

    state = TestInvokerTypes::PipelineState.new( tests: tests, testables: {}, context: :test, options: [], lock: Mutex.new )
    setup.stage_prepare_build_paths( state )
    return [state, file_path_utils]
  end

  def finder(configurator, file_path_utils)
    loginator = double( 'loginator', log: nil )
    return FileFinder.new(
      configurator: configurator, file_finder_helper: FileFinderHelper.new( loginator: loginator ), file_path_utils: file_path_utils,
      file_wrapper: FileWrapper.new( loginator: loginator, verbosinator: double( 'verbosinator', should_output?: false ) ), yaml_wrapper: nil
    )
  end

  # Each test's own object resolves to that test, by name and from its object path alone
  def expect_own_objects_resolve(configurator, state, file_path_utils)
    finder = finder( configurator, file_path_utils )
    state.testables.each_value do |testable|
      object = File.join( testable.paths[:build], File.basename( testable.filepath ).ext( '.o' ) )
      expect(finder.find_build_input_file( filepath: object, context: :test, test: testable.name )).to eq( testable.filepath )
      expect(finder.find_build_input_file( filepath: object, context: :test )).to eq( testable.filepath )
    end
  end

  TEST_NAMING_LAYOUTS.each do |layout, (tests, test_paths, test_files)|
    context "with #{layout}" do
      it 'names each test by its path, inside the build directory, with results where summaries look' do
        in_temp_project( project_files( tests ) ) do
          configurator = configure( project_yaml( test_paths, test_files ) )[:configurator]
          expect(configurator.collection_all_tests).to match_array( tests )

          state, file_path_utils = prepare( configurator, configurator.collection_all_tests )

          expect(state.testables.keys.map( &:to_s )).to match_array( tests.map { |test| test.ext( '' ) } )

          build = File.expand_path( 'build' ) + '/'
          state.testables.each_value do |testable|
            testable.paths.each_value { |path| expect(File.expand_path( path )).to start_with( build ) }
          end

          expected = state.testables.values.map { |testable| file_path_utils.form_pass_results_filepath( testable.paths[:results], testable.filepath ) }
          expect(file_path_utils.form_pass_results_filelist( configurator.project_test_results_path, tests )).to match_array( expected )
          expect(expected.uniq.size).to eq( tests.size )

          expect_own_objects_resolve( configurator, state, file_path_utils )
        end
      end
    end
  end

  # One test's name continues another's, so its directories nest inside the other's
  context 'with a test directory named like a test beside it' do
    it "keeps each test's mocks its own" do
      tests = %w[test/test_foo.c test/test_foo/test_bar.c]
      in_temp_project( project_files( tests ) ) do
        configurator = configure( project_yaml( %w[test/**], [] ) )[:configurator]
        state, file_path_utils = prepare( configurator, configurator.collection_all_tests )
        expect_own_objects_resolve( configurator, state, file_path_utils )

        mock = "#{configurator.cmock_mock_prefix}widget"
        state.testables.each_value do |testable|
          FileUtils.mkdir_p( testable.paths[:mocks] )
          File.write( File.join( testable.paths[:mocks], "#{mock}.c" ), "\n" )
        end

        finder = finder( configurator, file_path_utils )
        state.testables.each_value do |testable|
          object = File.join( testable.paths[:build], "#{mock}.o" )
          expect(finder.find_build_input_file( filepath: object, context: :test, test: testable.name )).to eq( File.join( testable.paths[:mocks], "#{mock}.c" ) )
        end
      end
    end
  end

  context 'with tests outside the project' do
    def outside_files
      return project_files( [] ).transform_keys { |path| File.join( 'app', path ) }.merge(
        'shared/test/unit/test_s.c' => "void test_it(void) {}\n",
        'other/test_o.c'            => "void test_it(void) {}\n"
      )
    end

    it 'keeps their names and directories inside the build directory' do
      in_temp_project( outside_files ) do
        Dir.chdir( 'app' ) do
          configurator = configure( project_yaml( %w[../shared/test/**], %w[../other/test_o.c] ) )[:configurator]

          state, file_path_utils = prepare( configurator, configurator.collection_all_tests )

          expect(state.testables.keys.map( &:to_s )).to match_array( %w[_up_/shared/test/unit/test_s _up_/other/test_o] )
          expect_own_objects_resolve( configurator, state, file_path_utils )
          build = File.expand_path( 'build' ) + '/'
          state.testables.each_value do |testable|
            testable.paths.each_value { |path| expect(File.expand_path( path )).to start_with( build ) }
          end
        end
      end
    end

    it 'stops a build that has two tests sharing one name, naming both' do
      files = outside_files.merge( 'app/_up_/other/test_o.c' => "void test_it(void) {}\n" )

      in_temp_project( files ) do
        Dir.chdir( 'app' ) do
          configurator = configure( project_yaml( %w[../shared/test/** _up_/**], %w[../other/test_o.c] ) )[:configurator]

          expect { prepare( configurator, ['_up_/other/test_o.c'] ) }.to raise_error( CeedlingException ) { |error|
            expect(error.message).to include( '../other/test_o.c', '_up_/other/test_o.c', '`_up_/other/test_o`' )
          }
          expect { prepare( configurator, ['../shared/test/unit/test_s.c'] ) }.to_not raise_error
        end
      end
    end
  end
end
