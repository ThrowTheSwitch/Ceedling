# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/file_finder'
require 'ceedling/file_finder_helper'
require 'ceedling/filename_extension'
require 'ceedling/exceptions'
require 'ceedling/constants'

describe FileFinder do
  before(:each) do
    @configurator      = double( "Configurator" )
    @file_path_utils   = double( "FilePathUtils" )
    @file_wrapper      = double( "FileWrapper" )
    @yaml_wrapper       = double( "YamlWrapper" )
    @loginator          = double( "Loginator" )

    # A real FileFinderHelper (already unit-tested on its own) so these specs exercise the
    # whole query -> FileFinder -> FileFinderHelper -> PathMatcher chain, not a mocked stub of it.
    @file_finder_helper = FileFinderHelper.new( { loginator: @loginator } )

    @file_finder = described_class.new({
      configurator:      @configurator,
      file_finder_helper: @file_finder_helper,
      file_path_utils:   @file_path_utils,
      file_wrapper:      @file_wrapper,
      yaml_wrapper:       @yaml_wrapper
    })
  end

  describe '#find_header_file' do
    before(:each) do
      allow(@configurator).to receive(:extension_header).and_return( FilenameExtension.new('.h') )
      allow(@configurator).to receive(:collection_all_headers).and_return(
        ['unit/bar.h', 'integration/bar.h', 'baz.h']
      )
    end

    it 'resolves a bare basename when it is unique' do
      expect(@file_finder.find_header_file('baz.h')).to eq('baz.h')
      expect(@file_finder.find_header_file('baz')).to eq('baz.h')
    end

    it 'raises a CeedlingException naming every candidate when a bare basename is ambiguous' do
      expect { @file_finder.find_header_file('bar.h') }.to raise_error(CeedlingException) do |error|
        expect(error.message).to include('unit/bar.h')
        expect(error.message).to include('integration/bar.h')
      end
    end

    it 'resolves an ambiguous basename when the query supplies enough path to disambiguate' do
      expect(@file_finder.find_header_file('unit/bar.h')).to eq('unit/bar.h')
      expect(@file_finder.find_header_file('integration/bar.h')).to eq('integration/bar.h')
    end
  end

  describe '#find_source_file' do
    before(:each) do
      allow(@configurator).to receive(:extension_source).and_return( FilenameExtension.new('.c') )
      allow(@configurator).to receive(:collection_all_source).and_return(
        ['drivers/foo/bar.c', 'drivers/baz/bar.c']
      )
    end

    it 'resolves a path-qualified query among same-named files' do
      expect(@file_finder.find_source_file('drivers/foo/bar.c')).to eq('drivers/foo/bar.c')
      expect(@file_finder.find_source_file('foo/bar.c')).to eq('drivers/foo/bar.c')
    end

    it 'raises a CeedlingException for a bare, ambiguous query' do
      expect { @file_finder.find_source_file('bar.c') }.to raise_error(CeedlingException)
    end
  end

  describe '#find_assembly_file' do
    it 'tries every configured extension in turn, still resolving a unique match' do
      allow(@configurator).to receive(:extension_assembly).and_return( FilenameExtension.new(['.s', '.S']) )
      allow(@configurator).to receive(:collection_all_assembly).and_return( ['src/foo.S'] )

      expect(@file_finder.find_assembly_file('foo')).to eq('src/foo.S')
    end
  end

  describe '#find_test_file_from_name' do
    before(:each) do
      allow(@configurator).to receive(:extension_source).and_return( FilenameExtension.new('.c') )
      allow(@configurator).to receive(:collection_all_tests).and_return(
        ['unit/test_foo.c', 'integration/test_foo.c']
      )
    end

    it 'raises a CeedlingException when a bare test name is ambiguous' do
      expect { @file_finder.find_test_file_from_name('test_foo') }.to raise_error(CeedlingException)
    end

    it 'resolves when the name carries enough path to disambiguate' do
      expect(@file_finder.find_test_file_from_name('unit/test_foo')).to eq('unit/test_foo.c')
    end
  end

  describe '#find_file_from_list' do
    it 'delegates to the underlying collection, raising on ambiguity the same as any other lookup' do
      list = ['a/dup.c', 'b/dup.c']
      expect { @file_finder.find_file_from_list('dup.c', list, :ignore) }.to raise_error(CeedlingException)
      expect(@file_finder.find_file_from_list('a/dup.c', list, :ignore)).to eq('a/dup.c')
    end
  end

  describe '#find_build_input_file' do
    before(:each) do
      allow(@configurator).to receive(:project_test_file_prefix).and_return('test_')
      allow(@configurator).to receive(:test_runner_file_suffix).and_return('_runner')
      allow(@configurator).to receive(:cmock_mock_prefix).and_return('Mock')
      allow(@configurator).to receive(:collection_vendor_framework_sources).and_return([])
      allow(@configurator).to receive(:release_build_use_assembly).and_return(false)
      allow(@configurator).to receive(:test_build_use_assembly).and_return(false)
      allow(@configurator).to receive(:extension_source).and_return( FilenameExtension.new('.c') )
      allow(@configurator).to receive(:extension_assembly).and_return( FilenameExtension.new('.s') )
      allow(@configurator).to receive(:project_test_build_output_path).and_return('build/test/out')
      allow(@configurator).to receive(:project_release_build_output_path).and_return('build/release/out')
      allow(@configurator).to receive(:project_build_root).and_return('build')
    end

    it 'raises a CeedlingException, rather than silently guessing, when two release sources share a basename' do
      allow(@configurator).to receive(:collection_release_build_input).and_return(
        ['drivers/foo/bar.c', 'drivers/baz/bar.c']
      )

      expect {
        @file_finder.find_build_input_file( filepath: 'build/release/out/bar.o', complain: :error, context: RELEASE_SYM )
      }.to raise_error(CeedlingException) do |error|
        expect(error.message).to include('drivers/foo/bar.c')
        expect(error.message).to include('drivers/baz/bar.c')
      end
    end

    it 'still resolves a genuinely unique release source by basename' do
      allow(@configurator).to receive(:collection_release_build_input).and_return( ['drivers/foo/bar.c'] )

      found = @file_finder.find_build_input_file( filepath: 'build/release/out/bar.o', complain: :error, context: RELEASE_SYM )
      expect(found).to eq('drivers/foo/bar.c')
    end

    it 'resolves a test\'s own source file via its build directory identity, even when another same-named test exists elsewhere' do
      allow(@configurator).to receive(:collection_all_tests).and_return(
        ['test/unit/test_foo.c', 'test/integration/test_foo.c']
      )

      found = @file_finder.find_build_input_file(
        filepath: 'build/test/out/unit/test_foo/test_foo.o', complain: :error, context: TEST_SYM
      )
      expect(found).to eq('test/unit/test_foo.c')

      found = @file_finder.find_build_input_file(
        filepath: 'build/test/out/integration/test_foo/test_foo.o', complain: :error, context: TEST_SYM
      )
      expect(found).to eq('test/integration/test_foo.c')
    end

    it 'resolves a test\'s own runner by its own runner subdirectory, without treating another same-named test\'s runner as ambiguous' do
      allow(@configurator).to receive(:project_test_runners_path).and_return('build/test/runners')

      all_runners = {
        'build/test/runners/unit'        => ['build/test/runners/unit/test_foo_runner.c'],
        'build/test/runners/integration' => ['build/test/runners/integration/test_foo_runner.c']
      }
      allow(@file_wrapper).to receive(:directory_listing) do |glob|
        dir = all_runners.keys.find { |d| glob.start_with?(d) }
        dir.nil? ? [] : all_runners[dir]
      end

      found = @file_finder.find_build_input_file(
        filepath: 'build/test/out/unit/test_foo/test_foo_runner.o', complain: :error, context: TEST_SYM
      )
      expect(found).to eq('build/test/runners/unit/test_foo_runner.c')

      found = @file_finder.find_build_input_file(
        filepath: 'build/test/out/integration/test_foo/test_foo_runner.o', complain: :error, context: TEST_SYM
      )
      expect(found).to eq('build/test/runners/integration/test_foo_runner.c')
    end

    it 'resolves a mock generated once per test, by the current test\'s own build directory, without treating that expected repetition as ambiguous' do
      allow(@configurator).to receive(:cmock_mock_path).and_return('build/test/mocks')

      all_mocks = {
        'build/test/mocks/TestAdcModel'  => ['build/test/mocks/TestAdcModel/MockTemperatureFilter.c'],
        'build/test/mocks/TestModel'     => ['build/test/mocks/TestModel/MockTemperatureFilter.c']
      }
      # The real FileWrapper only lists files under the specific glob it's given; a test's own
      # mock subtree is queried in isolation, which is exactly what keeps two tests' identically-
      # named mocks from ever appearing in the same collection at once.
      allow(@file_wrapper).to receive(:directory_listing) do |glob|
        test_dir = all_mocks.keys.find { |dir| glob.start_with?(dir) }
        test_dir.nil? ? [] : all_mocks[test_dir]
      end

      found = @file_finder.find_build_input_file(
        filepath: 'build/test/out/TestAdcModel/MockTemperatureFilter.o', complain: :error, context: TEST_SYM
      )
      expect(found).to eq('build/test/mocks/TestAdcModel/MockTemperatureFilter.c')

      found = @file_finder.find_build_input_file(
        filepath: 'build/test/out/TestModel/MockTemperatureFilter.o', complain: :error, context: TEST_SYM
      )
      expect(found).to eq('build/test/mocks/TestModel/MockTemperatureFilter.c')
    end

    it 'still raises when the very same test mocks two different same-named headers from different directories' do
      allow(@configurator).to receive(:cmock_mock_path).and_return('build/test/mocks')
      allow(@file_wrapper).to receive(:directory_listing).and_return(
        ['build/test/mocks/TestAdcModel/foo/MockBar.c', 'build/test/mocks/TestAdcModel/baz/MockBar.c']
      )

      expect {
        @file_finder.find_build_input_file(
          filepath: 'build/test/out/TestAdcModel/MockBar.o', complain: :error, context: TEST_SYM
        )
      }.to raise_error(CeedlingException)
    end

    it 'resolves a mock scoped to its own test via an explicitly-given test identity, even when the object path itself is flat (e.g. a GCOV or Bullseye build with no per-test mirroring of its own)' do
      allow(@configurator).to receive(:cmock_mock_path).and_return('build/test/mocks')

      all_mocks = {
        'build/test/mocks/TestAdcModel' => ['build/test/mocks/TestAdcModel/MockTemperatureFilter.c'],
        'build/test/mocks/TestModel'    => ['build/test/mocks/TestModel/MockTemperatureFilter.c']
      }
      allow(@file_wrapper).to receive(:directory_listing) do |glob|
        test_dir = all_mocks.keys.find { |dir| glob.start_with?(dir) }
        test_dir.nil? ? [] : all_mocks[test_dir]
      end

      # A flat, project-wide object path (no per-test subdirectory of its own, as GCOV/Bullseye
      # form their own objects) carries no test identity for test_context_of to recover -- only
      # the explicitly-given `test:` lets this resolve to the right one of two same-named mocks.
      found = @file_finder.find_build_input_file(
        filepath: 'build/gcov/out/MockTemperatureFilter.o', complain: :error, context: :gcov, test: 'TestAdcModel'
      )
      expect(found).to eq('build/test/mocks/TestAdcModel/MockTemperatureFilter.c')

      found = @file_finder.find_build_input_file(
        filepath: 'build/gcov/out/MockTemperatureFilter.o', complain: :error, context: :gcov, test: 'TestModel'
      )
      expect(found).to eq('build/test/mocks/TestModel/MockTemperatureFilter.c')
    end

    it 'resolves a release object via its own mirrored subdirectory, even when another same-named source exists elsewhere' do
      allow(@configurator).to receive(:collection_release_build_input).and_return(
        ['drivers/foo/bar.c', 'drivers/baz/bar.c']
      )

      found = @file_finder.find_build_input_file(
        filepath: 'build/release/out/foo/bar.o', complain: :error, context: RELEASE_SYM
      )
      expect(found).to eq('drivers/foo/bar.c')

      found = @file_finder.find_build_input_file(
        filepath: 'build/release/out/baz/bar.o', complain: :error, context: RELEASE_SYM
      )
      expect(found).to eq('drivers/baz/bar.c')
    end

    it 'resolves a module-under-test object via its own mirrored subdirectory, even when another same-named module exists elsewhere' do
      allow(@file_path_utils).to receive(:form_test_build_path).with('TestFoo', context: TEST_SYM).and_return('build/test/out/TestFoo')
      allow(@configurator).to receive(:collection_existing_test_build_input).and_return(
        ['drivers/foo/bar.c', 'drivers/baz/bar.c']
      )

      found = @file_finder.find_build_input_file(
        filepath: 'build/test/out/TestFoo/foo/bar.o', complain: :error, context: TEST_SYM, test: 'TestFoo'
      )
      expect(found).to eq('drivers/foo/bar.c')

      found = @file_finder.find_build_input_file(
        filepath: 'build/test/out/TestFoo/baz/bar.o', complain: :error, context: TEST_SYM, test: 'TestFoo'
      )
      expect(found).to eq('drivers/baz/bar.c')
    end

    it 'still resolves a flat module-under-test object by basename when no test identity is given' do
      allow(@configurator).to receive(:collection_existing_test_build_input).and_return( ['drivers/bar.c'] )

      found = @file_finder.find_build_input_file(
        filepath: 'build/test/out/TestFoo/bar.o', complain: :error, context: TEST_SYM
      )
      expect(found).to eq('drivers/bar.c')
    end

    it 'preserves a source-tree-relative query\'s own path, rather than collapsing it to a bare basename' do
      allow(@configurator).to receive(:collection_existing_test_build_input).and_return(
        ['drivers/foo/bar.c', 'drivers/baz/bar.c']
      )

      found = @file_finder.find_build_input_file(
        filepath: 'drivers/foo/bar.c', complain: :error, context: TEST_SYM
      )
      expect(found).to eq('drivers/foo/bar.c')
    end

    it 'still resolves a plugin\'s own build-context object by basename, an unrecognized build root having no mirroring rule of its own' do
      allow(@configurator).to receive(:collection_existing_test_build_input).and_return( ['drivers/bar.c'] )

      found = @file_finder.find_build_input_file(
        filepath: 'build/valgrind/out/TestFoo/bar.o', complain: :error, context: :valgrind
      )
      expect(found).to eq('drivers/bar.c')
    end

    it 'does not mistake an unrelated resolved path\'s own directory name for a test identity, when that directory happens to share the file\'s own basename' do
      allow(@configurator).to receive(:collection_existing_test_build_input).and_return( ['build/vendor/ceedling/ceedling.c'] )

      found = @file_finder.find_build_input_file(
        filepath: 'build/vendor/ceedling/ceedling.h', complain: :ignore, context: TEST_SYM
      )
      expect(found).to eq('build/vendor/ceedling/ceedling.c')
    end
  end
end
