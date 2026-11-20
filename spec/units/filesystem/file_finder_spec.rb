# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/filesystem/build_roots'
require 'tmpdir'
require 'ceedling/filesystem/file_finder'
require 'ceedling/filesystem/file_finder_helper'
require 'ceedling/filesystem/test_build_layout'
require 'ceedling/includes/header_search'
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
    # No configured root is long enough to shorten unless an example says so
    allow(@file_path_utils).to receive(:build_roots).and_return( BuildRoots.table( [] ) )

    # A real FileFinderHelper (already unit-tested on its own) so these specs exercise the
    # whole query -> FileFinder -> FileFinderHelper -> PathMatcher chain, not a mocked stub of it.
    @file_finder_helper = FileFinderHelper.new( { loginator: @loginator } )

    # A real TestBuildLayout, so a lookup finds each test's generated files where its build
    # puts them
    allow(@file_wrapper).to receive(:check_path_length)
    allow(@configurator).to receive(:project_build_root).and_return('build')
    allow(@configurator).to receive(:project_use_mocks).and_return( true )
    allow(@configurator).to receive(:project_use_partials).and_return( true )
    allow(@configurator).to receive(:cmock_mock_path).and_return('build/test/mocks')
    allow(@configurator).to receive(:project_test_partials_path).and_return('build/test/partials')
    allow(@configurator).to receive(:project_test_preprocess_includes_path).and_return('build/test/preprocess/includes')
    allow(@configurator).to receive(:project_test_preprocess_files_path).and_return('build/test/preprocess/files')
    allow(@configurator).to receive(:project_test_preprocess_build_directives_path).and_return('build/test/preprocess/build_directives')
    @test_build_layout = TestBuildLayout.new( { configurator: @configurator, file_wrapper: @file_wrapper } )

    @file_finder = described_class.new({
      configurator:      @configurator,
      file_finder_helper: @file_finder_helper,
      file_path_utils:   @file_path_utils,
      file_wrapper:      @file_wrapper,
      yaml_wrapper:       @yaml_wrapper,
      test_build_layout: @test_build_layout
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

    it 'finds a header through a HeaderSearch, joining a search path with the path the #include names' do
      search = HeaderSearch.new( ['src'], ->(dir) { dir == 'src/drivers' ? ['src/drivers/foo.h'] : [] } )

      expect(@file_finder.find_header_file('drivers/foo.h', :error, collection: search)).to eq('src/drivers/foo.h')
    end

    it 'tries each configured header extension through a HeaderSearch' do
      allow(@configurator).to receive(:extension_header).and_return( FilenameExtension.new(['.h', '.hpp']) )
      search = HeaderSearch.new( ['src'], ->(dir) { dir == 'src/drivers' ? ['src/drivers/foo.hpp'] : [] } )

      expect(@file_finder.find_header_file('drivers/foo', :error, collection: search)).to eq('src/drivers/foo.hpp')
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

    it "asks a HeaderSearch for the header a mock's #include names, its path kept" do
      search = HeaderSearch.new( ['src'], ->(dir) { dir == 'src/drivers' ? ['src/drivers/foo.h'] : [] } )

      expect(@file_finder.find_header_input_for_mock('drivers/Mockfoo.h', collection: search)).to eq('src/drivers/foo.h')
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
      allow(@configurator).to receive(:collection_mirror_roots_headers).and_return( ['src'] )
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

    # GH #1370: a `..` root "contained" a header far above it, so its mock left the build directory
    it 'places a mock of a header far above a `..` root flat, below the root that truly holds it' do
      allow(@configurator).to receive(:collection_all_headers).and_return( ['../../../opt/sdk/inc/sdk.h'] )
      allow(@configurator).to receive(:paths_include).and_return( ['../**', File.expand_path( '../../../opt/sdk/inc' )] )
      allow(@configurator).to receive(:collection_mirror_roots_headers).and_return( ['..', '../../../opt/sdk/inc'] )

      _source, subdir = @file_finder.resolve_mock('Mocksdk.h')
      expect(subdir).to eq('')
    end

    # GH #1370 audit (G4): a glob in the middle of a root names one root per directory
    it 'places a mock below the directory a glob-middle root names, not below the glob\'s base' do
      allow(@configurator).to receive(:collection_all_headers).and_return( ['components/foo/include/foo.h'] )
      allow(@configurator).to receive(:paths_include).and_return( ['components/*/include'] )
      allow(@configurator).to receive(:collection_mirror_roots_headers).and_return( ['components/foo/include'] )

      _source, subdir = @file_finder.resolve_mock('Mockfoo.h')
      expect(subdir).to eq('')
    end

    it 'still raises on a bogus (not-found) mock reference, exactly as find_header_input_for_mock does' do
      expect { @file_finder.resolve_mock('nonexistent/dir/Mockfoo.h') }.to raise_error(CeedlingException)
    end

    it 'finds nothing for a mock without a header, rather than raising, when told to ignore a missing header' do
      expect(@file_finder.resolve_mock('Mocknope.h', complain: :ignore)).to eq( [nil, nil] )
    end

    it 'finds nothing for a mock whose header differs only in letter case when told to be silent' do
      expect(@file_finder.resolve_mock('MockFOO.h', complain: :silent)).to eq( [nil, nil] )
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

    # GH #1370 audit (G9): a task name is relative to the working directory, as every
    # collected path is, so a leading `..` names a test outside the project
    it 'resolves a name climbing out of the project, against the working directory' do
      allow(@configurator).to receive(:collection_all_tests).and_return( ['../tests/test_x.c', 'unit/test_foo.c'] )

      expect(@file_finder.find_test_file_from_name('../tests/test_x')).to eq('../tests/test_x.c')
    end

    it 'resolves a name written with `./`' do
      expect(@file_finder.find_test_file_from_name('./unit/test_foo')).to eq('unit/test_foo.c')
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
      # No configured include root contains these queries, so each keeps its own path.
      allow(@configurator).to receive(:paths_include).and_return( ['include'] )
      allow(@configurator).to receive(:collection_mirror_roots_include).and_return( ['include'] )

      # A test is named by its path without its extension. Examples that look tests up by
      # name give their own test collection.
      allow(@configurator).to receive(:collection_all_tests).and_return( [] )
      allow(@file_path_utils).to receive(:form_test_name) { |test| test.to_s.ext( '' ) }
      allow(@file_path_utils).to receive(:form_test_runners_path) do |name, **|
        File.dirname( name ) == '.' ? 'build/test/runners' : File.join( 'build/test/runners', File.dirname( name ) )
      end
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
        filepath: 'build/test/out/test/unit/test_foo/_t_/test_foo.o', complain: :error, context: TEST_SYM
      )
      expect(found).to eq('test/unit/test_foo.c')

      found = @file_finder.find_build_input_file(
        filepath: 'build/test/out/test/integration/test_foo/_t_/test_foo.o', complain: :error, context: TEST_SYM
      )
      expect(found).to eq('test/integration/test_foo.c')
    end

    # GH #1364: a test's own source resolves exactly, though its name ends another's path
    {
      'flat and nested under one root'        => ['test/test_calc.c', 'test/unit/test_calc.c'],
      'the same subdirectory under two roots' => ['test/unit/test_calc.c', 'extra/unit/test_calc.c'],
      'the same layout under two roots'       => ['test/foo/test_x.c', 'extra/foo/test_x.c']
    }.each do |layout, tests|
      it "resolves each test's own source exactly with #{layout}" do
        allow(@configurator).to receive(:collection_all_tests).and_return( tests )

        tests.each do |test|
          name   = test.ext( '' )
          object = File.join( 'build/test/out', name, '_t_', File.basename( name ) + '.o' )

          expect(@file_finder.find_build_input_file( filepath: object, complain: :error, context: TEST_SYM, test: name )).to eq( test )
          expect(@file_finder.find_build_input_file( filepath: object, complain: :error, context: TEST_SYM )).to eq( test )
        end
      end
    end

    it 'resolves the source of a test outside the project, whose name matches no path' do
      allow(@file_path_utils).to receive(:form_test_name) { |test| test.to_s.ext( '' ).gsub( '..', '_up_' ) }
      allow(@configurator).to receive(:collection_all_tests).and_return( ['../shared/test/unit/test_s.c'] )

      found = @file_finder.find_build_input_file(
        filepath: 'build/test/out/_up_/shared/test/unit/test_s/_t_/test_s.o', complain: :error, context: TEST_SYM
      )
      expect(found).to eq('../shared/test/unit/test_s.c')
    end

    it 'resolves a test whose name ends another test\'s path' do
      allow(@configurator).to receive(:collection_all_tests).and_return( ['test/unit/test_calc.c', 'other/test/unit/test_calc.c'] )

      found = @file_finder.find_build_input_file(
        filepath: 'build/test/out/test/unit/test_calc/_t_/test_calc.o', complain: :error, context: TEST_SYM
      )
      expect(found).to eq('test/unit/test_calc.c')
    end

    it 'resolves a header named like its test to the test itself' do
      allow(@configurator).to receive(:collection_all_tests).and_return( ['test/test_calc.c', 'test/unit/test_calc.c'] )

      found = @file_finder.find_build_input_file( filepath: 'test_calc.h', complain: :error, context: TEST_SYM, test: 'test/unit/test_calc' )
      expect(found).to eq('test/unit/test_calc.c')
    end

    it 'names every test once, however many lookups follow' do
      expect(@configurator).to receive(:collection_all_tests).once.and_return( ['test/test_calc.c', 'test/unit/test_calc.c'] )

      2.times do
        @file_finder.find_build_input_file( filepath: 'build/test/out/test/test_calc/_t_/test_calc.o', complain: :error, context: TEST_SYM )
      end
    end

    it 'resolves a test\'s own runner by its own runner subdirectory, without treating another same-named test\'s runner as ambiguous' do
      allow(@configurator).to receive(:project_test_runners_path).and_return('build/test/runners')
      allow(@configurator).to receive(:collection_all_tests).and_return( ['unit/test_foo.c', 'integration/test_foo.c'] )

      all_runners = {
        'build/test/runners/unit'        => ['build/test/runners/unit/test_foo_runner.c'],
        'build/test/runners/integration' => ['build/test/runners/integration/test_foo_runner.c']
      }
      allow(@file_wrapper).to receive(:directory_listing) do |glob|
        dir = all_runners.keys.find { |d| glob.start_with?(d) }
        dir.nil? ? [] : all_runners[dir]
      end

      found = @file_finder.find_build_input_file(
        filepath: 'build/test/out/unit/test_foo/_t_/test_foo_runner.o', complain: :error, context: TEST_SYM
      )
      expect(found).to eq('build/test/runners/unit/test_foo_runner.c')

      found = @file_finder.find_build_input_file(
        filepath: 'build/test/out/integration/test_foo/_t_/test_foo_runner.o', complain: :error, context: TEST_SYM
      )
      expect(found).to eq('build/test/runners/integration/test_foo_runner.c')
    end

    it 'resolves a mock generated once per test, by the current test\'s own build directory, without treating that expected repetition as ambiguous' do
      allow(@configurator).to receive(:collection_all_tests).and_return( ['TestAdcModel.c', 'TestModel.c'] )

      all_mocks = {
        'build/test/mocks/TestAdcModel/_t_'  => ['build/test/mocks/TestAdcModel/_t_/MockTemperatureFilter.c'],
        'build/test/mocks/TestModel/_t_'     => ['build/test/mocks/TestModel/_t_/MockTemperatureFilter.c']
      }
      # The real FileWrapper only lists files under the specific glob it's given; a test's own
      # mock subtree is queried in isolation, which is exactly what keeps two tests' identically-
      # named mocks from ever appearing in the same collection at once.
      allow(@file_wrapper).to receive(:directory_listing) do |glob|
        test_dir = all_mocks.keys.find { |dir| glob.start_with?(dir) }
        test_dir.nil? ? [] : all_mocks[test_dir]
      end

      found = @file_finder.find_build_input_file(
        filepath: 'build/test/out/TestAdcModel/_t_/MockTemperatureFilter.o', complain: :error, context: TEST_SYM
      )
      expect(found).to eq('build/test/mocks/TestAdcModel/_t_/MockTemperatureFilter.c')

      found = @file_finder.find_build_input_file(
        filepath: 'build/test/out/TestModel/_t_/MockTemperatureFilter.o', complain: :error, context: TEST_SYM
      )
      expect(found).to eq('build/test/mocks/TestModel/_t_/MockTemperatureFilter.c')
    end

    # A listing below a root, as the real FileWrapper gives, from files that each test's
    # build put below its own root
    def list_below(files)
      allow(@file_wrapper).to receive(:directory_listing) do |glob|
        root = glob.delete_suffix( '/**/*.c' )
        files.select { |file| file.start_with?( root + '/' ) }
      end
    end

    # One test's name continues another's, beside that test's own subdirectory of the same name
    it 'keeps a test whose name continues another test\'s from sharing that test\'s mocks' do
      allow(@configurator).to receive(:collection_all_tests).and_return( ['test/test_foo.c', 'test/test_foo/test_bar.c'] )
      list_below( ['build/test/mocks/test/test_foo/_t_/Mockwidget.c', 'build/test/mocks/test/test_foo/test_bar/_t_/Mockwidget.c'] )

      found = @file_finder.find_build_input_file( filepath: 'build/test/out/test/test_foo/_t_/Mockwidget.o', complain: :error, context: TEST_SYM )
      expect(found).to eq('build/test/mocks/test/test_foo/_t_/Mockwidget.c')

      found = @file_finder.find_build_input_file( filepath: 'build/test/out/test/test_foo/test_bar/_t_/Mockwidget.o', complain: :error, context: TEST_SYM )
      expect(found).to eq('build/test/mocks/test/test_foo/test_bar/_t_/Mockwidget.c')
    end

    it 'keeps a test whose name continues another test\'s from sharing that test\'s Partials' do
      allow(@configurator).to receive(:collection_all_tests).and_return( ['test/test_foo.c', 'test/test_foo/test_bar.c'] )
      list_below( ['build/test/partials/test/test_foo/_t_/ceedling_partial_widget_impl.c', 'build/test/partials/test/test_foo/test_bar/_t_/ceedling_partial_widget_impl.c'] )

      found = @file_finder.find_build_input_file( filepath: 'build/test/out/test/test_foo/_t_/ceedling_partial_widget_impl.o', complain: :error, context: TEST_SYM )
      expect(found).to eq('build/test/partials/test/test_foo/_t_/ceedling_partial_widget_impl.c')
    end

    # A test's mock lies in a folder named like a test nested below it, which exists
    it 'finds a test\'s mock in a folder named like a nested test' do
      allow(@configurator).to receive(:collection_all_tests).and_return( ['test/test_c.c', 'test/test_c/test_x.c'] )
      list_below( ['build/test/mocks/test/test_c/_t_/test_x/mock_qux.c'] )
      allow(@configurator).to receive(:cmock_mock_prefix).and_return('mock_')

      found = @file_finder.find_build_input_file( filepath: 'build/test/out/test/test_c/_t_/test_x/mock_qux.o', complain: :error, context: TEST_SYM, test: 'test/test_c' )
      expect(found).to eq('build/test/mocks/test/test_c/_t_/test_x/mock_qux.c')

      found = @file_finder.find_build_input_file( filepath: 'test_x/mock_qux.h', complain: :error, context: TEST_SYM, test: 'test/test_c' )
      expect(found).to eq('build/test/mocks/test/test_c/_t_/test_x/mock_qux.c')
    end

    it 'finds a test\'s Partial in a folder named like a nested test' do
      allow(@configurator).to receive(:collection_all_tests).and_return( ['test/test_c.c', 'test/test_c/test_x.c'] )
      list_below( ['build/test/partials/test/test_c/_t_/test_x/ceedling_partial_qux_impl.c'] )

      found = @file_finder.find_build_input_file( filepath: 'test_x/ceedling_partial_qux_impl', complain: :ignore, context: TEST_SYM, test: 'test/test_c' )
      expect(found).to eq('build/test/partials/test/test_c/_t_/test_x/ceedling_partial_qux_impl.c')
    end

    # TEST_SOURCE_FILE() names a source by its path, with no test to scope a search by
    it 'searches no test\'s mocks or Partials when no test is known' do
      allow(@configurator).to receive(:collection_existing_test_build_input).and_return( ['src/Mockwidget.c', 'src/ceedling_partial_widget_impl.c'] )
      list_below( ['build/test/mocks/test/test_other/_t_/Mockwidget.c', 'build/test/partials/test/test_other/_t_/ceedling_partial_widget_impl.c'] )

      expect( @file_finder.find_build_input_file( filepath: 'Mockwidget.c', complain: :ignore, context: TEST_SYM ) ).to eq('src/Mockwidget.c')
      expect( @file_finder.find_build_input_file( filepath: 'ceedling_partial_widget_impl.c', complain: :ignore, context: TEST_SYM ) )
        .to eq('src/ceedling_partial_widget_impl.c')
      expect(@file_wrapper).to_not have_received(:directory_listing)
    end

    it 'searches no mocks or Partials of a disabled feature' do
      allow(@configurator).to receive(:project_use_mocks).and_return( false )
      allow(@configurator).to receive(:project_use_partials).and_return( false )
      allow(@configurator).to receive(:collection_existing_test_build_input).and_return( ['src/Mockwidget.c'] )
      list_below( ['build/test/mocks/test/test_c/_t_/Mockwidget.c'] )

      expect( @file_finder.find_build_input_file( filepath: 'Mockwidget.c', complain: :ignore, context: TEST_SYM, test: 'test/test_c' ) )
        .to eq('src/Mockwidget.c')
      expect(@file_wrapper).to_not have_received(:directory_listing)
    end

    # A hand-written fake may take a mock's name, and a test links it through TEST_SOURCE_FILE()
    it 'finds a hand-written source named with the mock prefix that its test\'s mocks don\'t hold' do
      allow(@configurator).to receive(:collection_all_tests).and_return( ['test/test_b.c'] )
      allow(@configurator).to receive(:collection_existing_test_build_input).and_return( ['test/support/Mockspi.c'] )
      list_below( ['build/test/mocks/test/test_a/_t_/Mockspi.c'] )

      found = @file_finder.find_build_input_file(
        filepath: 'build/test/out/test/test_b/_t_/test/support/Mockspi.o', complain: :error, context: TEST_SYM, test: 'test/test_b'
      )
      expect(found).to eq('test/support/Mockspi.c')
    end

    it 'finds a hand-written source named with the Partial prefix that its test\'s Partials don\'t hold' do
      allow(@configurator).to receive(:collection_all_tests).and_return( ['test/test_b.c'] )
      allow(@configurator).to receive(:collection_existing_test_build_input).and_return( ['test/support/ceedling_partial_spi.c'] )
      list_below( [] )

      found = @file_finder.find_build_input_file(
        filepath: 'build/test/out/test/test_b/_t_/test/support/ceedling_partial_spi.o', complain: :error, context: TEST_SYM, test: 'test/test_b'
      )
      expect(found).to eq('test/support/ceedling_partial_spi.c')
    end

    it 'finds a test\'s own mock ahead of a hand-written source of the same name' do
      allow(@configurator).to receive(:collection_all_tests).and_return( ['test/test_b.c'] )
      allow(@configurator).to receive(:collection_existing_test_build_input).and_return( ['Mockspi.c'] )
      list_below( ['build/test/mocks/test/test_b/_t_/Mockspi.c'] )

      found = @file_finder.find_build_input_file( filepath: 'build/test/out/test/test_b/_t_/Mockspi.o', complain: :error, context: TEST_SYM )
      expect(found).to eq('build/test/mocks/test/test_b/_t_/Mockspi.c')
    end

    it 'names the mock it sought when neither its test\'s mocks nor the build input hold it' do
      allow(@configurator).to receive(:collection_all_tests).and_return( ['test/test_b.c'] )
      allow(@configurator).to receive(:collection_existing_test_build_input).and_return( ['src/other.c'] )
      list_below( [] )

      expect {
        @file_finder.find_build_input_file( filepath: 'build/test/out/test/test_b/_t_/drv/Mockspi.o', complain: :error, context: TEST_SYM )
      }.to raise_error( CeedlingException, 'Found no file `drv/Mockspi.c` in search paths.' )
    end

    it 'warns once of a mock that neither its test\'s mocks nor the build input hold' do
      allow(@configurator).to receive(:collection_all_tests).and_return( ['test/test_b.c'] )
      allow(@configurator).to receive(:collection_existing_test_build_input).and_return( ['src/other.c'] )
      list_below( [] )

      found = @file_finder.find_build_input_file( filepath: 'build/test/out/test/test_b/_t_/drv/Mockspi.o', complain: :warn, context: TEST_SYM )

      expect(found).to be_nil
      expect(@loginator).to have_received(:log).once
      expect(@loginator).to have_received(:log).with( 'Found no file `drv/Mockspi.c` in search paths.', Verbosity::COMPLAIN )
    end

    it 'lists a test\'s mocks with any bracket in its path escaped, so the listing is not a glob class' do
      allow(@configurator).to receive(:collection_all_tests).and_return( ['test[1]/test_foo.c'] )

      expect(@file_wrapper).to receive(:directory_listing).with( 'build/test/mocks/test\[1\]/test_foo/_t_/**/*.c' )
        .and_return( ['build/test/mocks/test[1]/test_foo/_t_/Mockwidget.c'] )

      found = @file_finder.find_build_input_file( filepath: 'build/test/out/test[1]/test_foo/_t_/Mockwidget.o', complain: :error, context: TEST_SYM )
      expect(found).to eq('build/test/mocks/test[1]/test_foo/_t_/Mockwidget.c')
    end

    # A mock of a header at a search path's root sits in the test's mock root, and a same-named
    # mock below it ends with the same name
    it 'resolves a mock in the test\'s mock root beside a same-named mock below it' do
      allow(@configurator).to receive(:collection_all_tests).and_return( ['test/test_t.c'] )
      allow(@file_wrapper).to receive(:directory_listing).and_return(
        ['build/test/mocks/test/test_t/_t_/b/Mocktask.c', 'build/test/mocks/test/test_t/_t_/Mocktask.c']
      )


      # The planner asks by each mock's #include
      found = @file_finder.find_build_input_file( filepath: 'Mocktask.h', complain: :error, context: TEST_SYM, test: 'test/test_t' )
      expect(found).to eq('build/test/mocks/test/test_t/_t_/Mocktask.c')

      found = @file_finder.find_build_input_file( filepath: 'b/Mocktask.h', complain: :error, context: TEST_SYM, test: 'test/test_t' )
      expect(found).to eq('build/test/mocks/test/test_t/_t_/b/Mocktask.c')
    end

    # A mock an earlier build placed deeper ends with the same folder and name
    it 'resolves a mock in a subdirectory of the test\'s mock root beside a same-named mock below another' do
      allow(@configurator).to receive(:collection_all_tests).and_return( ['test/test_t.c'] )
      allow(@file_wrapper).to receive(:directory_listing).and_return(
        ['build/test/mocks/test/test_t/_t_/src/drivers/Mocktask.c', 'build/test/mocks/test/test_t/_t_/drivers/Mocktask.c']
      )

      found = @file_finder.find_build_input_file( filepath: 'drivers/Mocktask.h', complain: :error, context: TEST_SYM, test: 'test/test_t' )
      expect(found).to eq('build/test/mocks/test/test_t/_t_/drivers/Mocktask.c')
    end

    it 'still raises when the very same test mocks two different same-named headers from different directories' do
      allow(@file_wrapper).to receive(:directory_listing).and_return(
        ['build/test/mocks/TestAdcModel/_t_/foo/MockBar.c', 'build/test/mocks/TestAdcModel/_t_/baz/MockBar.c']
      )

      expect {
        @file_finder.find_build_input_file(
          filepath: 'build/test/out/TestAdcModel/_t_/MockBar.o', complain: :error, context: TEST_SYM
        )
      }.to raise_error(CeedlingException)
    end

    it 'resolves a mock scoped to its own test via an explicitly-given test identity, even when the object path itself is flat (e.g. a GCOV or Bullseye build with no per-test mirroring of its own)' do
      # This build mirrors nothing per test, so the object sits below neither the mock
      # root nor the test's own out root and the mock resolves by name alone.

      all_mocks = {
        'build/test/mocks/TestAdcModel/_t_' => ['build/test/mocks/TestAdcModel/_t_/MockTemperatureFilter.c'],
        'build/test/mocks/TestModel/_t_'    => ['build/test/mocks/TestModel/_t_/MockTemperatureFilter.c']
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
      expect(found).to eq('build/test/mocks/TestAdcModel/_t_/MockTemperatureFilter.c')

      found = @file_finder.find_build_input_file(
        filepath: 'build/gcov/out/MockTemperatureFilter.o', complain: :error, context: :gcov, test: 'TestModel'
      )
      expect(found).to eq('build/test/mocks/TestModel/_t_/MockTemperatureFilter.c')
    end

    it 'resolves a release object to the source at its own path, even when another same-named source exists elsewhere' do
      allow(@configurator).to receive(:collection_release_build_input).and_return(
        ['drivers/foo/bar.c', 'drivers/baz/bar.c']
      )

      found = @file_finder.find_build_input_file(
        filepath: 'build/release/out/drivers/foo/bar.o', complain: :error, context: RELEASE_SYM
      )
      expect(found).to eq('drivers/foo/bar.c')

      found = @file_finder.find_build_input_file(
        filepath: 'build/release/out/drivers/baz/bar.o', complain: :error, context: RELEASE_SYM
      )
      expect(found).to eq('drivers/baz/bar.c')
    end

    # A release build has no per-test directories, so it places a directory named `_t_` as is
    it 'resolves a release object of a source in a directory named like `_t_` to exactly that source' do
      allow(@configurator).to receive(:collection_release_build_input).and_return( ['src/_t_/foo.c', 'src/__t_/foo.c'] )

      found = @file_finder.find_build_input_file( filepath: 'build/release/out/src/_t_/foo.o', complain: :error, context: RELEASE_SYM )
      expect(found).to eq('src/_t_/foo.c')

      found = @file_finder.find_build_input_file( filepath: 'build/release/out/src/__t_/foo.o', complain: :error, context: RELEASE_SYM )
      expect(found).to eq('src/__t_/foo.c')
    end

    it 'resolves a module-under-test object to the source at its own path, even when another same-named module exists elsewhere' do
      allow(@configurator).to receive(:collection_existing_test_build_input).and_return(
        ['drivers/foo/bar.c', 'drivers/baz/bar.c']
      )

      found = @file_finder.find_build_input_file(
        filepath: 'build/test/out/TestFoo/_t_/drivers/foo/bar.o', complain: :error, context: TEST_SYM, test: 'TestFoo'
      )
      expect(found).to eq('drivers/foo/bar.c')

      found = @file_finder.find_build_input_file(
        filepath: 'build/test/out/TestFoo/_t_/drivers/baz/bar.o', complain: :error, context: TEST_SYM, test: 'TestFoo'
      )
      expect(found).to eq('drivers/baz/bar.c')
    end

    # A tail match of `src/util` takes whichever of these comes first
    it 'resolves an object to exactly its own source, never one whose path merely ends the same way' do
      allow(@configurator).to receive(:collection_release_build_input).and_return( ['lib/src/util.c', 'src/util.c'] )

      found = @file_finder.find_build_input_file( filepath: 'build/release/out/src/util.o', complain: :error, context: RELEASE_SYM )
      expect(found).to eq('src/util.c')
    end

    it 'resolves an object of a source above the project root' do
      allow(@configurator).to receive(:collection_release_build_input).and_return( ['src/crc.c', '../shared/src/crc.c'] )

      found = @file_finder.find_build_input_file( filepath: 'build/release/out/_up_/shared/src/crc.o', complain: :error, context: RELEASE_SYM )
      expect(found).to eq('../shared/src/crc.c')
    end

    # GH #1387: a source below a shortened root builds below the root's marker
    it 'resolves an object below a shortened root to exactly its own source' do
      root  = '../vendor/acme/sdk/v3/src'
      table = BuildRoots.table( [root] )
      allow(@file_path_utils).to receive(:build_roots).and_return( table )
      allow(@configurator).to receive(:collection_release_build_input).and_return( ['os/crc.c', "#{root}/os/crc.c"] )

      found = @file_finder.find_build_input_file( filepath: "build/release/out/#{table.marker_for( root )}/os/crc.o", complain: :error, context: RELEASE_SYM )
      expect(found).to eq( "#{root}/os/crc.c" )
    end

    # Left from a build whose configuration had another root
    it 'resolves an object below a marker no root holds by its name' do
      allow(@configurator).to receive(:collection_release_build_input).and_return( ['src/crc.c'] )

      found = @file_finder.find_build_input_file( filepath: 'build/release/out/_src_ABCDEF12/crc.o', complain: :error, context: RELEASE_SYM )
      expect(found).to eq('src/crc.c')
    end

    it 'resolves an object of a file in the running Ceedling installation, placed below `_ceedling_`' do
      helper = File.join( BuildSubpath::INSTALLATION_ROOT, 'plugins/fff/src/fff_unity_helper.c' )
      allow(@configurator).to receive(:collection_existing_test_build_input).and_return( ['src/fff_unity_helper.c', helper] )

      Dir.mktmpdir do |project|
        Dir.chdir( project ) do
          found = @file_finder.find_build_input_file(
            filepath: 'build/test/out/test/test_x/_t_/_ceedling_/plugins/fff/src/fff_unity_helper.o', complain: :error, context: TEST_SYM, test: 'test/test_x'
          )
          expect(found).to eq( helper )
        end
      end
    end

    it 'recovers a nested test\'s identity from its object\'s path, rather than its parent test\'s' do
      allow(@configurator).to receive(:collection_all_tests).and_return( ['test/test_foo.c', 'test/test_foo/test_bar.c'] )
      allow(@configurator).to receive(:collection_existing_test_build_input).and_return( ['src/util.c'] )

      expect(@file_finder.find_build_input_file( filepath: 'build/test/out/test/test_foo/test_bar/_t_/test/test_foo/test_bar.o', complain: :error, context: TEST_SYM ))
        .to eq('test/test_foo/test_bar.c')
      expect(@file_finder.find_build_input_file( filepath: 'build/test/out/test/test_foo/_t_/test/test_foo.o', complain: :error, context: TEST_SYM ))
        .to eq('test/test_foo.c')
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
