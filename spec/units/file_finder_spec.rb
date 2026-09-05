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
    allow(@loginator).to receive(:log)

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

    it 'never raises on a bare, ambiguous basename -- resolves to the first candidate in collection order' do
      expect(@file_finder.find_header_file('bar.h')).to eq('unit/bar.h')
    end

    it 'logs an ℹ️ NOTICE naming the passed-over candidate when a bare basename is ambiguous' do
      expect(@loginator).to receive(:log) do |msg, verbosity, label|
        expect(msg).to include('unit/bar.h')
        expect(msg).to include('integration/bar.h')
        expect(verbosity).to eq(Verbosity::COMPLAIN)
        expect(label).to eq(LogLabels::NOTICE)
      end

      @file_finder.find_header_file('bar.h')
    end

    it 'resolves an ambiguous basename when the query supplies enough path to disambiguate' do
      expect(@file_finder.find_header_file('unit/bar.h')).to eq('unit/bar.h')
      expect(@file_finder.find_header_file('integration/bar.h')).to eq('integration/bar.h')
    end

    it 'searches a caller-supplied collection instead of collection_all_headers when one is given' do
      expect(@file_finder.find_header_file('baz.h', :error, collection: ['other/baz.h'])).to eq('other/baz.h')
    end
  end

  describe '#find_header_input_for_mock' do
    before(:each) do
      allow(@configurator).to receive(:cmock_mock_prefix).and_return( 'Mock' )
      allow(@configurator).to receive(:collection_all_headers).and_return(
        ['unit/bar.h', 'integration/bar.h', 'baz.h']
      )
    end

    it 'resolves a bare mock name when its header is unique' do
      expect(@file_finder.find_header_input_for_mock('Mockbaz.h')).to eq('baz.h')
    end

    it 'never raises on a bare, ambiguous mock name -- resolves to the first candidate in collection order' do
      expect(@file_finder.find_header_input_for_mock('Mockbar.h')).to eq('unit/bar.h')
    end

    it 'logs an ℹ️ NOTICE naming the passed-over candidate when a bare mock name is ambiguous' do
      expect(@loginator).to receive(:log) do |msg, verbosity, label|
        expect(msg).to include('unit/bar.h')
        expect(msg).to include('integration/bar.h')
        expect(verbosity).to eq(Verbosity::COMPLAIN)
        expect(label).to eq(LogLabels::NOTICE)
      end

      @file_finder.find_header_input_for_mock('Mockbar.h')
    end

    it 'resolves an ambiguous mock name when the query supplies enough path to disambiguate' do
      expect(@file_finder.find_header_input_for_mock('unit/Mockbar.h')).to eq('unit/bar.h')
      expect(@file_finder.find_header_input_for_mock('integration/Mockbar.h')).to eq('integration/bar.h')
    end

    it 'still raises rather than silently matching just the basename when the given path is bogus (not-found, not ambiguity)' do
      expect {
        @file_finder.find_header_input_for_mock('nonexistent/dir/Mockbaz.h')
      }.to raise_error(CeedlingException)
    end

    it 'searches a caller-supplied collection instead of collection_all_headers when one is given' do
      expect(@file_finder.find_header_input_for_mock('Mockbaz.h', collection: ['other/baz.h'])).to eq('other/baz.h')
    end
  end

  describe '#resolve_mock' do
    before(:each) do
      allow(@configurator).to receive(:cmock_mock_prefix).and_return( 'Mock' )
      allow(@configurator).to receive(:collection_all_headers).and_return(
        ['src/drivers/foo.h', 'src/baz.h']
      )
      allow(@configurator).to receive(:paths_test).and_return( [] )
      allow(@configurator).to receive(:paths_support).and_return( [] )
      allow(@configurator).to receive(:paths_include).and_return( ['src'] )
    end

    it 'resolves a mock header and its own mirrored subdirectory below the configured root that contains it' do
      source, subdir = @file_finder.resolve_mock('Mockfoo.h')
      expect(source).to eq('src/drivers/foo.h')
      expect(subdir).to eq('drivers')
    end

    it 'returns an empty subdirectory for a mock header directly in a configured root' do
      source, subdir = @file_finder.resolve_mock('Mockbaz.h')
      expect(source).to eq('src/baz.h')
      expect(subdir).to eq('')
    end

    it 'resolves identically regardless of how much disambiguating path the query itself carries' do
      bare,   bare_subdir   = @file_finder.resolve_mock('Mockfoo.h')
      pathed, pathed_subdir = @file_finder.resolve_mock('drivers/Mockfoo.h')
      expect(bare).to eq(pathed)
      expect(bare_subdir).to eq(pathed_subdir)
    end

    it 'still raises on a bogus (not-found) mock reference, exactly as find_header_input_for_mock does' do
      expect { @file_finder.resolve_mock('nonexistent/dir/Mockfoo.h') }.to raise_error(CeedlingException)
    end

    it 'never raises on an ambiguous mock reference -- resolves to the first candidate in collection order' do
      allow(@configurator).to receive(:collection_all_headers).and_return(
        ['src/drivers/dup.h', 'src/other/dup.h']
      )
      source, subdir = @file_finder.resolve_mock('Mockdup.h')
      expect(source).to eq('src/drivers/dup.h')
      expect(subdir).to eq('drivers')
    end

    it 'searches a caller-supplied collection instead of collection_all_headers when one is given' do
      source, subdir = @file_finder.resolve_mock('Mockfoo.h', collection: ['src/other/foo.h'])
      expect(source).to eq('src/other/foo.h')
      expect(subdir).to eq('other')
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

    it 'never raises on a bare, ambiguous query -- resolves to the first candidate in collection order' do
      expect(@file_finder.find_source_file('bar.c')).to eq('drivers/foo/bar.c')
    end

    it 'logs an ℹ️ NOTICE naming the passed-over candidate when a bare query is ambiguous' do
      expect(@loginator).to receive(:log) do |msg, verbosity, label|
        expect(msg).to include('drivers/foo/bar.c')
        expect(msg).to include('drivers/baz/bar.c')
        expect(verbosity).to eq(Verbosity::COMPLAIN)
        expect(label).to eq(LogLabels::NOTICE)
      end

      @file_finder.find_source_file('bar.c')
    end
  end

  describe '#find_assembly_file' do
    it 'tries every configured extension in turn, still resolving a unique match' do
      allow(@configurator).to receive(:extension_assembly).and_return( FilenameExtension.new(['.s', '.S']) )
      allow(@configurator).to receive(:collection_all_assembly).and_return( ['src/foo.S'] )

      expect(@file_finder.find_assembly_file('foo')).to eq('src/foo.S')
    end

    it 'never raises on an ambiguous match -- resolves to the first candidate in collection order' do
      allow(@configurator).to receive(:extension_assembly).and_return( FilenameExtension.new('.s') )
      allow(@configurator).to receive(:collection_all_assembly).and_return( ['drivers/foo/bar.s', 'drivers/baz/bar.s'] )

      expect(@file_finder.find_assembly_file('bar')).to eq('drivers/foo/bar.s')
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

    it 'raises a clear CeedlingException naming .. as unsupported in a CLI task name, rather than a generic not-found' do
      # A CLI task name has no file of its own to anchor a .. against -- unlike an
      # #include or TEST_SOURCE_FILE() entry, which are always scoped to the test file
      # that wrote them. Today's generic "Found no file" message happens to also
      # contain the query text, so asserting on the query alone would pass for the
      # wrong reason -- the message must specifically call out .. as the problem.
      expect { @file_finder.find_test_file_from_name('../unit/test_foo') }.to raise_error(CeedlingException) do |error|
        expect(error.message).to include('../unit/test_foo')
        expect(error.message).not_to match(/Found no file/)
        expect(error.message).to match(/\.\./)
        expect(error.message).to match(/context/i)
      end
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

    it 'never raises, rather than silently missing a build, when two release sources share a basename -- resolves to the first by project path order' do
      allow(@configurator).to receive(:collection_release_build_input).and_return(
        ['drivers/foo/bar.c', 'drivers/baz/bar.c']
      )

      found = @file_finder.find_build_input_file( filepath: 'build/release/out/bar.o', complain: :error, context: RELEASE_SYM )
      expect(found).to eq('drivers/foo/bar.c')
    end

    it 'logs an ℹ️ NOTICE naming the passed-over release source when ambiguous' do
      allow(@configurator).to receive(:collection_release_build_input).and_return(
        ['drivers/foo/bar.c', 'drivers/baz/bar.c']
      )

      expect(@loginator).to receive(:log) do |msg, verbosity, label|
        expect(msg).to include('drivers/foo/bar.c')
        expect(msg).to include('drivers/baz/bar.c')
        expect(verbosity).to eq(Verbosity::COMPLAIN)
        expect(label).to eq(LogLabels::NOTICE)
      end

      @file_finder.find_build_input_file( filepath: 'build/release/out/bar.o', complain: :error, context: RELEASE_SYM )
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

    it 'never raises on a bare, ambiguous TEST_SOURCE_FILE()-style query -- resolves to the first candidate by project path order' do
      allow(@configurator).to receive(:collection_existing_test_build_input).and_return(
        ['drivers/foo/bar.c', 'drivers/baz/bar.c']
      )

      found = @file_finder.find_build_input_file( filepath: 'bar.c', complain: :ignore, context: TEST_SYM )
      expect(found).to eq('drivers/foo/bar.c')
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
