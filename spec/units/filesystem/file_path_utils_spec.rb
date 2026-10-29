# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/filesystem/file_path_utils'
require 'ceedling/filesystem/file_wrapper'
require 'ceedling/filename_extension'

describe FilePathUtils do

  describe '.collapse_to_common_parents' do

    it 'returns nil unchanged' do
      expect(FilePathUtils.collapse_to_common_parents(nil)).to be_nil
    end

    it 'returns a single-element list unchanged' do
      expect(FilePathUtils.collapse_to_common_parents(['src'])).to eq(['src'])
    end

    it 'returns disjoint paths unchanged' do
      paths = ['src', 'lib/core', 'lib/utils']
      expect(FilePathUtils.collapse_to_common_parents(paths)).to match_array(paths)
    end

    it 'removes a child path when its parent is also present' do
      result = FilePathUtils.collapse_to_common_parents(['src', 'src/platform', 'lib'])
      expect(result).to match_array(['src', 'lib'])
    end

    it 'collapses multiple children to a single ancestor' do
      result = FilePathUtils.collapse_to_common_parents(['a/b', 'a/c', 'a'])
      expect(result).to match_array(['a'])
    end

    # The path handling audit around GH #1370: `..` holds `../sib` but not `../../far/x`
    it 'keeps a path above the project that no other path holds' do
      result = FilePathUtils.collapse_to_common_parents(['..', '../../far/x', '../sib'])
      expect(result).to match_array(['..', '../../far/x'])
    end

    it 'handles deeply nested redundant paths' do
      result = FilePathUtils.collapse_to_common_parents(['src', 'src/a/b/c', 'lib'])
      expect(result).to match_array(['src', 'lib'])
    end

    it 'normalizes backslash separators for comparison (Windows paths)' do
      result = FilePathUtils.collapse_to_common_parents(['src', 'src\\platform'])
      expect(result).to eq(['src'])
    end

    it 'preserves original path form in output' do
      result = FilePathUtils.collapse_to_common_parents(['src', 'src\\platform', 'lib'])
      expect(result).to match_array(['src', 'lib'])
      expect(result).not_to include('src\\platform')
    end

  end


  describe '.standardize_in_place' do

    it 'strips leading and trailing whitespace' do
      expect( FilePathUtils.standardize_in_place( '  foo/bar  ' ) ).to eq( 'foo/bar' )
    end

    it 'converts backslashes to forward slashes' do
      expect( FilePathUtils.standardize_in_place( 'foo\\bar\\baz' ) ).to eq( 'foo/bar/baz' )
    end

    it 'removes a trailing forward slash' do
      expect( FilePathUtils.standardize_in_place( 'foo/bar/' ) ).to eq( 'foo/bar' )
    end

    it 'applies all three normalizations together' do
      expect( FilePathUtils.standardize_in_place( '  foo\\bar\\' ) ).to eq( 'foo/bar' )
    end

    it 'returns an already-clean path unchanged' do
      expect( FilePathUtils.standardize_in_place( 'foo/bar/baz' ) ).to eq( 'foo/bar/baz' )
    end

    # GH #1370 audit (G21)
    it 'reads `~` as the home directory' do
      expect( FilePathUtils.standardize_in_place( +'~/inc' ) ).to eq( File.join( Dir.home, 'inc' ) )
    end

    it 'returns nil unchanged for a nil argument' do
      expect( FilePathUtils.standardize_in_place( nil ) ).to be_nil
    end

    it 'raises CeedlingException on a frozen string' do
      frozen = 'foo\\bar\\'.freeze
      expect { FilePathUtils.standardize_in_place( frozen ) }.to raise_error( CeedlingException )
    end

  end


  describe '.no_decorators' do

    it "strips +: prefix and trailing slash from '+:foo/bar/baz/'" do
      expect( FilePathUtils.no_decorators( '+:foo/bar/baz/' ) ).to eq( 'foo/bar/baz' )
    end

    it "strips -: prefix and trailing slash from '-:foo/bar/baz/'" do
      expect( FilePathUtils.no_decorators( '-:foo/bar/baz/' ) ).to eq( 'foo/bar/baz' )
    end

    it "extracts the directory portion of a path with a ? glob ('foo/bar/ba?')" do
      expect( FilePathUtils.no_decorators( 'foo/bar/ba?' ) ).to eq( 'foo/bar' )
    end

    it "removes a trailing slash from a plain directory path ('foo/bar/baz/')" do
      expect( FilePathUtils.no_decorators( 'foo/bar/baz/' ) ).to eq( 'foo/bar/baz' )
    end

    it "returns a plain file path unchanged ('foo/bar/baz/file.x')" do
      expect( FilePathUtils.no_decorators( 'foo/bar/baz/file.x' ) ).to eq( 'foo/bar/baz/file.x' )
    end

    it "extracts the directory portion of a path with a * glob ('foo/bar/baz/file*.x')" do
      expect( FilePathUtils.no_decorators( 'foo/bar/baz/file*.x' ) ).to eq( 'foo/bar/baz' )
    end

    it "returns empty string when the path starts with a glob character ('*foo')" do
      expect( FilePathUtils.no_decorators( '*foo' ) ).to eq( '' )
    end

    it "returns empty string for a glob-only path with no directory ('*.c')" do
      expect( FilePathUtils.no_decorators( '*.c' ) ).to eq( '' )
    end

    it "returns empty string when a glob follows a bare name with no path separator ('src*.c')" do
      expect( FilePathUtils.no_decorators( 'src*.c' ) ).to eq( '' )
    end

    it "returns '/' for a root-level glob ('/*.c')" do
      expect( FilePathUtils.no_decorators( '/*.c' ) ).to eq( '/' )
    end

    it "returns empty string for nil" do
      expect( FilePathUtils.no_decorators( nil ) ).to eq( '' )
    end

    # #104 -- `[`/`]` are legal filename characters (Windows especially) but were
    # swept into PATTERNS::GLOB alongside Ceedling's own genuinely-supported `*`/`?`/
    # `{`/`}` wildcard syntax. Unlike those, `[`/`]` are never a documented Ceedling
    # glob feature, so a literal bracket in a real directory name must not be treated
    # as "where the glob starts" -- doing so silently validated the wrong, truncated
    # ancestor directory instead of the real one.
    it "returns a directory path containing literal brackets unchanged, not truncated ('foo/[bar]/baz')" do
      expect( FilePathUtils.no_decorators( 'foo/[bar]/baz' ) ).to eq( 'foo/[bar]/baz' )
    end

    it "still extracts the directory portion ahead of a real glob when a literal bracket precedes it ('foo/[bar]/baz/*.c')" do
      expect( FilePathUtils.no_decorators( 'foo/[bar]/baz/*.c' ) ).to eq( 'foo/[bar]/baz' )
    end

  end


  describe '.escape_glob_brackets' do

    it "backslash-escapes a literal '[' and ']'" do
      expect( FilePathUtils.escape_glob_brackets( 'foo/[bar]/baz' ) ).to eq( 'foo/\\[bar\\]/baz' )
    end

    it "leaves a path with no brackets unchanged" do
      expect( FilePathUtils.escape_glob_brackets( 'foo/bar/baz' ) ).to eq( 'foo/bar/baz' )
    end

    it "leaves Ceedling's own genuine glob syntax untouched" do
      expect( FilePathUtils.escape_glob_brackets( 'foo/bar/**' ) ).to eq( 'foo/bar/**' )
    end

    it "returns nil for nil" do
      expect( FilePathUtils.escape_glob_brackets( nil ) ).to be_nil
    end

  end


  # #104 -- the canonical base-path-plus-suffix glob builder every call site should use
  # instead of hand-rolling `File.join(path, suffix)`, so a literal `[`/`]` in `base_path`
  # can't be forgotten by omission (several call sites did, before this existed).
  describe '.glob' do

    it "escapes brackets in the base path, leaving an appended suffix untouched" do
      expect( FilePathUtils.glob( 'foo/[bar]', '*.c' ) ).to eq( 'foo/\\[bar\\]/*.c' )
    end

    it "joins multiple suffix parts, same as File.join" do
      expect( FilePathUtils.glob( 'foo/[bar]', 'config', '*.rb' ) ).to eq( 'foo/\\[bar\\]/config/*.rb' )
    end

    it "behaves as a plain File.join when the base path has no brackets" do
      expect( FilePathUtils.glob( 'foo/bar', '*.c' ) ).to eq( File.join( 'foo/bar', '*.c' ) )
    end

    it "returns just the escaped base path when no suffix is given" do
      expect( FilePathUtils.glob( 'foo/[bar]' ) ).to eq( 'foo/\\[bar\\]' )
    end

  end


  describe '.subdirectory_glob' do

    it "escapes brackets in the path before reforming the trailing '/**' convention" do
      expect( FilePathUtils.subdirectory_glob( 'foo/[bar]/**' ) ).to eq( 'foo/\\[bar\\]/**/**' )
    end

    it "escapes brackets in a path with no trailing glob" do
      expect( FilePathUtils.subdirectory_glob( 'foo/[bar]' ) ).to eq( 'foo/\\[bar\\]' )
    end

  end


  describe '.no_aggregation_decorators' do

    it "strips the '+:' prefix" do
      expect( FilePathUtils.no_aggregation_decorators( '+:foo/bar' ) ).to eq( 'foo/bar' )
    end

    it "strips the '-:' prefix" do
      expect( FilePathUtils.no_aggregation_decorators( '-:foo/bar' ) ).to eq( 'foo/bar' )
    end

    it "returns a bare path unchanged" do
      expect( FilePathUtils.no_aggregation_decorators( 'foo/bar' ) ).to eq( 'foo/bar' )
    end

    it "strips the '+:' prefix when preceded by whitespace ('  +: foo/bar')" do
      expect( FilePathUtils.no_aggregation_decorators( '  +: foo/bar' ) ).to eq( 'foo/bar' )
    end

    it "strips surrounding whitespace from a bare path ('  foo/bar  ')" do
      expect( FilePathUtils.no_aggregation_decorators( '  foo/bar  ' ) ).to eq( 'foo/bar' )
    end

    it "returns empty string for nil" do
      expect( FilePathUtils.no_aggregation_decorators( nil ) ).to eq( '' )
    end

  end


  describe '.add_path?' do

    it "returns true for a bare path (no prefix)" do
      expect( FilePathUtils.add_path?( 'foo/bar' ) ).to be true
    end

    it "returns true for a path with '+:' prefix" do
      expect( FilePathUtils.add_path?( '+:foo/bar' ) ).to be true
    end

    it "returns false for a path with '-:' prefix" do
      expect( FilePathUtils.add_path?( '-:foo/bar' ) ).to be false
    end

    it "returns false for a '-:' path preceded by whitespace ('  -:foo/bar')" do
      expect( FilePathUtils.add_path?( '  -:foo/bar' ) ).to be false
    end

    it "returns true for nil" do
      expect( FilePathUtils.add_path?( nil ) ).to be true
    end

  end


  describe '.reform_subdirectory_glob' do

    it "appends '/**' to a path ending in '/**'" do
      expect( FilePathUtils.reform_subdirectory_glob( 'foo/bar/**' ) ).to eq( 'foo/bar/**/**' )
    end

    it "leaves a path already ending in '/**/**' unchanged" do
      expect( FilePathUtils.reform_subdirectory_glob( 'foo/bar/**/**' ) ).to eq( 'foo/bar/**/**' )
    end

    it "leaves a plain path without '/**' unchanged" do
      expect( FilePathUtils.reform_subdirectory_glob( 'foo/bar' ) ).to eq( 'foo/bar' )
    end

    it "appends '/**' to a root recursive glob ('/**')" do
      expect( FilePathUtils.reform_subdirectory_glob( '/**' ) ).to eq( '/**/**' )
    end

    it "leaves a single-level glob unchanged ('foo/*' is not a /** pattern)" do
      expect( FilePathUtils.reform_subdirectory_glob( 'foo/*' ) ).to eq( 'foo/*' )
    end

    it "returns empty string for nil" do
      expect( FilePathUtils.reform_subdirectory_glob( nil ) ).to eq( '' )
    end

  end


  # ---------------------------------------------------------------------------
  # Instance-method tests
  # ---------------------------------------------------------------------------

  describe '#form_test_filepath_from_runner' do
    before(:each) do
      @configurator = double('configurator')
      @file_wrapper = double('file_wrapper')
      allow(@file_wrapper).to receive(:check_path_length)
      @fpu = described_class.new({
        :configurator => @configurator,
        :file_wrapper => @file_wrapper
      })

      # TEST_RUNNER_FILE_SUFFIX is a global constant created at runtime by
      # ConfiguratorBuilder from the project config.  Set it for these tests.
      @suffix_was_defined = Object.const_defined?(:TEST_RUNNER_FILE_SUFFIX)
      @original_suffix    = @suffix_was_defined ? TEST_RUNNER_FILE_SUFFIX : nil
      Object.send(:remove_const, :TEST_RUNNER_FILE_SUFFIX) if @suffix_was_defined
      Object.const_set(:TEST_RUNNER_FILE_SUFFIX, '_runner')
    end

    after(:each) do
      Object.send(:remove_const, :TEST_RUNNER_FILE_SUFFIX) if Object.const_defined?(:TEST_RUNNER_FILE_SUFFIX)
      Object.const_set(:TEST_RUNNER_FILE_SUFFIX, @original_suffix) if @suffix_was_defined
    end

    it 'strips the runner suffix from a top-level runner filepath' do
      expect( @fpu.form_test_filepath_from_runner('test_foo_runner.c') ).to eq('test_foo.c')
    end

    it 'strips the runner suffix from a nested runner filepath' do
      expect( @fpu.form_test_filepath_from_runner('build/test/runners/test_bar_runner.c') )
        .to eq('build/test/runners/test_bar.c')
    end

    it 'does not alter a filepath that does not contain the runner suffix' do
      expect( @fpu.form_test_filepath_from_runner('test_foo.c') ).to eq('test_foo.c')
    end

    it 'treats a dot in the suffix as a literal character, not a regex wildcard' do
      # Unescaped suffix '_test.runner' creates regex /_test.runner/ where '.' matches any char.
      # That regex incorrectly strips '_test_runner' (underscore instead of dot).
      # With Regexp.escape the dot is literal, so '_test_runner' is NOT matched.
      Object.send(:remove_const, :TEST_RUNNER_FILE_SUFFIX)
      Object.const_set(:TEST_RUNNER_FILE_SUFFIX, '_test.runner')

      expect( @fpu.form_test_filepath_from_runner('build/test_foo_test_runner.c') )
        .to eq('build/test_foo_test_runner.c')   # no match → unchanged
    end
  end

  describe '#form_runner_filepath_from_test' do
    before(:each) do
      @configurator = double('configurator')
      @file_wrapper = double('file_wrapper')
      allow(@file_wrapper).to receive(:check_path_length)
      @fpu = described_class.new({
        :configurator => @configurator,
        :file_wrapper => @file_wrapper
      })

      allow(@configurator).to receive(:project_test_runners_path).and_return('build/test/runners')
      allow(@configurator).to receive(:test_runner_file_suffix).and_return('_runner')
    end

    it 'forms a flat runner filepath when no test identity is given' do
      expect( @fpu.form_runner_filepath_from_test('test/test_foo.c') )
        .to eq('build/test/runners/test_foo_runner.c')
    end

    it 'forms a runner filepath in the runners directory itself for a test at the project root' do
      expect( @fpu.form_runner_filepath_from_test('test_foo.c', name: 'test_foo') )
        .to eq('build/test/runners/test_foo_runner.c')
    end

    it 'places the runner beneath the directories of the test\'s name, distinguishing same-named tests' do
      expect( @fpu.form_runner_filepath_from_test('test/unit/test_foo.c', name: 'test/unit/test_foo') )
        .to eq('build/test/runners/test/unit/test_foo_runner.c')

      expect( @fpu.form_runner_filepath_from_test('test/integration/test_foo.c', name: 'test/integration/test_foo') )
        .to eq('build/test/runners/test/integration/test_foo_runner.c')
    end

    it 'forms the runners directory itself for a test at the project root' do
      expect( @fpu.form_test_runners_path('test_foo') ).to eq('build/test/runners')
    end

    it 'forms the runner directory beneath the directories of the test\'s name' do
      expect( @fpu.form_test_runners_path('test/unit/test_foo') ).to eq('build/test/runners/test/unit')
    end
  end

  describe '#form_release_dependencies_filepath, #form_release_build_list_filepath' do
    before(:each) do
      @configurator = double('configurator')
      @file_wrapper = double('file_wrapper')
      allow(@file_wrapper).to receive(:check_path_length)
      @fpu = described_class.new({
        :configurator => @configurator,
        :file_wrapper => @file_wrapper
      })

      allow(@configurator).to receive(:project_release_build_output_path).and_return('build/release/out')
      allow(@configurator).to receive(:project_release_dependencies_path).and_return('build/release/dependencies')
      allow(@configurator).to receive(:extension_dependencies).and_return( FilenameExtension.new('.d') )
      allow(@configurator).to receive(:extension_list).and_return( FilenameExtension.new('.lst') )
    end

    it 'mirrors a dependencies filepath the same way as the object it accompanies' do
      expect( @fpu.form_release_dependencies_filepath('build/release/out/foo/bar.o') )
        .to eq('build/release/dependencies/foo/bar.d')
    end

    it 'forms a flat dependencies filepath for a flat object' do
      expect( @fpu.form_release_dependencies_filepath('build/release/out/bar.o') )
        .to eq('build/release/dependencies/bar.d')
    end

    it 'forms the list filepath directly alongside the object, wherever it was mirrored to' do
      expect( @fpu.form_release_build_list_filepath('build/release/out/foo/bar.o') )
        .to eq('build/release/out/foo/bar.lst')
    end
  end

  describe '#form_test_dependencies_filepath, #form_test_build_list_filepath' do
    before(:each) do
      @configurator = double('configurator')
      @file_wrapper = double('file_wrapper')
      allow(@file_wrapper).to receive(:check_path_length)
      @fpu = described_class.new({
        :configurator => @configurator,
        :file_wrapper => @file_wrapper
      })

      allow(@configurator).to receive(:project_build_root).and_return('build')
      allow(@configurator).to receive(:extension_dependencies).and_return( FilenameExtension.new('.d') )
      allow(@configurator).to receive(:extension_list).and_return( FilenameExtension.new('.lst') )
    end

    it 'mirrors a dependencies filepath the same way as the object it accompanies, distinguishing same-named modules under test' do
      expect( @fpu.form_test_dependencies_filepath('build/test/out/TestFoo/calculators/AdcCalc.o', name: 'TestFoo', context: :test) )
        .to eq('build/test/dependencies/TestFoo/calculators/AdcCalc.d')
    end

    it 'forms a flat dependencies filepath for a flat object' do
      expect( @fpu.form_test_dependencies_filepath('build/test/out/TestFoo/AdcCalc.o', name: 'TestFoo', context: :test) )
        .to eq('build/test/dependencies/TestFoo/AdcCalc.d')
    end

    it 'forms a flat dependencies filepath when no test identity is given' do
      expect( @fpu.form_test_dependencies_filepath('build/gcov/out/AdcCalc.o', context: :gcov) )
        .to eq('build/gcov/dependencies/AdcCalc.d')
    end

    # A context's own objects, outside any test, are placed by their sources' paths too
    it 'follows a context\'s own object below its output root when no test identity is given' do
      expect( @fpu.form_test_dependencies_filepath('build/gcov/out/src/a/util.o', context: :gcov) )
        .to eq('build/gcov/dependencies/src/a/util.d')
    end

    it 'forms the list filepath directly alongside the object, wherever it was mirrored to' do
      expect( @fpu.form_test_build_list_filepath('build/test/out/TestFoo/calculators/AdcCalc.o') )
        .to eq('build/test/out/TestFoo/calculators/AdcCalc.lst')
    end
  end

  describe '#form_test_object_filepath' do
    before(:each) do
      @configurator = double('configurator')
      @file_wrapper = double('file_wrapper')
      allow(@file_wrapper).to receive(:check_path_length)
      @fpu = described_class.new({
        :configurator => @configurator,
        :file_wrapper => @file_wrapper
      })

      allow(@configurator).to receive(:project_build_root).and_return('build')
      allow(@configurator).to receive(:extension_object).and_return( FilenameExtension.new('.o') )
      allow(@configurator).to receive(:project_use_partials).and_return( true )
      allow(@configurator).to receive(:project_use_mocks).and_return( true )
      allow(@configurator).to receive(:project_test_partials_path).and_return('build/test/partials')
      allow(@configurator).to receive(:cmock_mock_path).and_return('build/test/mocks')
    end

    it 'places a test\'s object where its build does, by the source\'s path from the project root' do
      expect( @fpu.form_test_object_filepath('src/a/util.c', name: 'test/test_util', context: :gcov) )
        .to eq('build/gcov/out/test/test_util/src/a/util.o')
    end

    # Untested sources compile outside any test, so same-named ones keep apart only by path
    it 'places a context\'s own objects apart, by their sources\' paths, when no test is named' do
      expect( @fpu.form_test_object_filepath('src/a/util.c', context: :gcov) ).to eq('build/gcov/out/src/a/util.o')
      expect( @fpu.form_test_object_filepath('src/b/util.c', context: :gcov) ).to eq('build/gcov/out/src/b/util.o')
    end

    it 'places a test\'s generated Partial below its own subdirectory, as its build does' do
      expect(
        @fpu.form_test_object_filepath('build/test/partials/test/test_util/drv/ceedling_partial_util_impl.c', name: 'test/test_util', context: :gcov)
      ).to eq('build/gcov/out/test/test_util/drv/ceedling_partial_util_impl.o')
    end
  end

  describe '#form_test_preprocess_build_directives_path, #form_test_build_directives_cache_filepath, #form_preprocessed_source_files_cache_filepath' do
    before(:each) do
      @configurator = double('configurator')
      @file_wrapper = double('file_wrapper')
      allow(@file_wrapper).to receive(:check_path_length)
      @fpu = described_class.new({
        :configurator => @configurator,
        :file_wrapper => @file_wrapper
      })

      allow(@configurator).to receive(:project_test_preprocess_build_directives_path).and_return('build/test/preprocess/build_directives')
    end

    it 'forms a per-test build directives cache directory path' do
      expect( @fpu.form_test_preprocess_build_directives_path('TestFoo') )
        .to eq('build/test/preprocess/build_directives/TestFoo')
    end

    it 'forms a build directives cache filepath using the fixed internal .yml extension' do
      expect( @fpu.form_test_build_directives_cache_filepath('test/TestFoo.c', 'TestFoo') )
        .to eq('build/test/preprocess/build_directives/TestFoo/TestFoo.c.yml')
    end

    it 'forms a distinct source files cache filepath alongside the build directives cache' do
      expect( @fpu.form_preprocessed_source_files_cache_filepath('test/TestFoo.c', 'TestFoo') )
        .to eq('build/test/preprocess/build_directives/TestFoo/TestFoo.c_source_files.yml')
    end
  end

  describe '#form_release_build_objects_filelist' do
    before(:each) do
      @configurator = double('configurator')
      @file_wrapper = FileWrapper.new({
        :loginator    => double('loginator').as_null_object,
        :verbosinator => double('verbosinator').as_null_object
      })
      @fpu = described_class.new({
        :configurator => @configurator,
        :file_wrapper => @file_wrapper
      })

      allow(@configurator).to receive(:project_release_build_output_path).and_return('build/release/out')
      allow(@configurator).to receive(:project_build_root).and_return('build')
      allow(@configurator).to receive(:extension_object).and_return( FilenameExtension.new('.o') )
    end

    it 'places each object by its source\'s path from the project root, distinguishing same-named sources' do
      objects = @fpu.form_release_build_objects_filelist( ['drivers/foo/bar.c', 'drivers/baz/bar.c', 'lib/bar.c'] )
      expect( objects ).to eq(['build/release/out/drivers/foo/bar.o', 'build/release/out/drivers/baz/bar.o', 'build/release/out/lib/bar.o'])
    end

    it 'places a source above the project root below the output root' do
      objects = @fpu.form_release_build_objects_filelist( ['../shared/src/crc.c'] )
      expect( objects ).to eq(['build/release/out/_up_/shared/src/crc.o'])
    end

    it 'leaves a source below the build root flat' do
      objects = @fpu.form_release_build_objects_filelist( ['build/vendor/c_exception/lib/CException.c'] )
      expect( objects ).to eq(['build/release/out/CException.o'])
    end

    it 'refuses two sources that would build to one object, naming both' do
      expect { @fpu.form_release_build_objects_filelist( ['build/vendor/c_exception/lib/CException.c', 'CException.c'] ) }
        .to raise_error( CeedlingException, /`build\/vendor\/c_exception\/lib\/CException.c` and `CException.c`.*`build\/release\/out\/CException.o`/ )
    end
  end

  describe '#form_release_dependencies_filelist' do
    before(:each) do
      @configurator = double('configurator')
      @file_wrapper = FileWrapper.new({
        :loginator    => double('loginator').as_null_object,
        :verbosinator => double('verbosinator').as_null_object
      })
      @fpu = described_class.new({
        :configurator => @configurator,
        :file_wrapper => @file_wrapper
      })

      allow(@configurator).to receive(:project_release_dependencies_path).and_return('build/release/dependencies')
      allow(@configurator).to receive(:project_build_root).and_return('build')
      allow(@configurator).to receive(:extension_dependencies).and_return( FilenameExtension.new('.d') )
    end

    it 'places each dependency file the same way as its corresponding object' do
      deps = @fpu.form_release_dependencies_filelist( ['drivers/foo/bar.c', 'drivers/baz/bar.c'] )
      expect( deps ).to eq(['build/release/dependencies/drivers/foo/bar.d', 'build/release/dependencies/drivers/baz/bar.d'])
    end
  end

  # A mock's generated files sit below its test's mock root, in the subdirectory mirroring
  # whatever it mocks. Two places need that directory -- the stage that compiles the mock
  # and the stage that generates it -- and they must agree, or a mock is compiled from a
  # path nothing ever wrote.
  describe '#form_mock_output_path' do
    before(:each) do
      @fpu = described_class.new({
        :configurator => double('configurator'),
        :file_wrapper => double('file_wrapper')
      })
    end

    it 'joins a mock root and the subdirectory its content mirrors' do
      expect( @fpu.form_mock_output_path('build/test/mocks/a_test', 'drivers/uart') )
        .to eq('build/test/mocks/a_test/drivers/uart')
    end

    it 'returns the root alone for a mock mirroring no subdirectory' do
      expect( @fpu.form_mock_output_path('build/test/mocks/a_test', '') )
        .to eq('build/test/mocks/a_test')
    end

    it 'treats a nil subdirectory as none' do
      expect( @fpu.form_mock_output_path('build/test/mocks/a_test', nil) )
        .to eq('build/test/mocks/a_test')
    end
  end

  describe 'preprocessed file paths' do
    before(:each) do
      @configurator = double('configurator')
      @file_wrapper = double('file_wrapper')
      @fpu = described_class.new({
        :configurator => @configurator,
        :file_wrapper => @file_wrapper
      })

      allow(@configurator).to receive(:project_test_preprocess_files_path).and_return('build/test/preprocess/files')
      allow(@configurator).to receive(:project_test_preprocess_includes_path).and_return('build/test/preprocess/includes')
      allow(@configurator).to receive(:project_build_root).and_return('build')
      allow(@configurator).to receive(:project_use_partials).and_return( true )
      allow(@configurator).to receive(:project_use_mocks).and_return( true )
      allow(@configurator).to receive(:project_test_partials_path).and_return('build/test/partials')
      allow(@configurator).to receive(:cmock_mock_path).and_return('build/test/mocks')
    end

    # Each artifact of a test sits below the test's own subdirectory, at its file's path
    # from the project root, so two same-named files in one test never share one
    it 'places a file by its path from the project root below the test subdirectory' do
      expect( @fpu.form_preprocessed_file_filepath('src/drivers/uart/config.c', 'test_both') )
        .to eq('build/test/preprocess/files/test_both/src/drivers/uart/config.c')
      expect( @fpu.form_preprocessed_file_full_expansion_filepath('src/drivers/uart/config.c', 'test_both') )
        .to eq('build/test/preprocess/files/test_both/full_expansion/src/drivers/uart/config.c')
      expect( @fpu.form_preprocessed_file_raw_directives_only_filepath('src/drivers/uart/config.c', 'test_both') )
        .to eq('build/test/preprocess/files/test_both/directives_only/raw/src/drivers/uart/config.c')
      expect( @fpu.form_preprocessed_file_compacted_directives_only_filepath('src/drivers/uart/config.c', 'test_both') )
        .to eq('build/test/preprocess/files/test_both/directives_only/src/drivers/uart/config.c')
      expect( @fpu.form_preprocessed_file_fallback_expansion_filepath('src/drivers/uart/config.c', 'test_both') )
        .to eq('build/test/preprocess/files/test_both/fallback_expansion/src/drivers/uart/config.c')
      expect( @fpu.form_preprocessed_includes_list_filepath('src/drivers/uart/config.c', 'test_both') )
        .to eq('build/test/preprocess/includes/test_both/src/drivers/uart/config.c.yml')
    end

    it 'keeps a header far above the project below the test subdirectory' do
      far = File.expand_path( '../../far/inc/sdk.h' )
      expect( @fpu.form_preprocessed_file_filepath( far, 'test_both' ) )
        .to eq( File.join( 'build/test/preprocess/files/test_both', BuildSubpath.of_directory( File.dirname( far ) ), 'sdk.h' ) )
      expect( BuildSubpath.of_directory( File.dirname( far ) ) ).to_not include( '..' )
    end

    # The defect itself: two sources sharing a basename in one test.
    it 'gives two same-named sources in one test distinct artifacts' do
      uart = @fpu.form_preprocessed_file_raw_directives_only_filepath('src/drivers/uart/config.c', 'test_both')
      spi  = @fpu.form_preprocessed_file_raw_directives_only_filepath('src/drivers/spi/config.c', 'test_both')

      expect( uart ).to_not eq(spi)
    end

    # Composing a path leaves nothing behind. Callers that merely restate one -- a rake
    # target declaration, a staleness check -- must not create directories as a side
    # effect; whoever writes the file creates its directory.
    it 'creates no directory, composing a path only' do
      expect(@file_wrapper).to_not receive(:mkdir)

      @fpu.form_preprocessed_file_raw_directives_only_filepath('src/drivers/uart/config.c', 'test_both')
      @fpu.form_preprocessed_file_full_expansion_filepath('src/drivers/uart/config.c', 'test_both')
      @fpu.form_preprocessed_includes_list_filepath('src/drivers/uart/config.c', 'test_both')
    end

    it 'places a header by its path from the project root' do
      expect( @fpu.form_preprocessed_file_filepath('include/drivers/uart/config.h', 'test_both') )
        .to eq('build/test/preprocess/files/test_both/include/drivers/uart/config.h')
    end

    # A generated Partial or mock sits below its own test's generated root rather than a
    # configured source root. Two same-named modules each produce one, so those roots have
    # to mirror too or both share a single preprocessed artifact.
    it 'mirrors a generated Partial header below its own test root' do
      expect(
        @fpu.form_preprocessed_file_raw_directives_only_filepath(
          'build/test/partials/test_both/drivers/uart/ceedling_partial_config_interface.h', 'test_both'
        )
      ).to eq('build/test/preprocess/files/test_both/directives_only/raw/drivers/uart/ceedling_partial_config_interface.h')
    end

    it 'gives two same-named generated Partial headers distinct artifacts' do
      uart = @fpu.form_preprocessed_file_raw_directives_only_filepath(
        'build/test/partials/test_both/drivers/uart/ceedling_partial_config_interface.h', 'test_both'
      )
      spi = @fpu.form_preprocessed_file_raw_directives_only_filepath(
        'build/test/partials/test_both/drivers/spi/ceedling_partial_config_interface.h', 'test_both'
      )

      expect( uart ).to_not eq(spi)
    end

    it 'mirrors a generated mock below its own test root' do
      expect(
        @fpu.form_preprocessed_file_filepath(
          'build/test/mocks/test_both/drivers/spi/mock_config.h', 'test_both'
        )
      ).to eq('build/test/preprocess/files/test_both/drivers/spi/mock_config.h')
    end

    it 'keeps a generated file directly in its test root flat' do
      expect( @fpu.form_preprocessed_file_filepath('build/test/mocks/test_both/Mockconfig.h', 'test_both') )
        .to eq('build/test/preprocess/files/test_both/Mockconfig.h')
    end
  end

  describe '#form_test_build_objects_filelist' do
    before(:each) do
      @configurator = double('configurator')
      @file_wrapper = FileWrapper.new({
        :loginator    => double('loginator').as_null_object,
        :verbosinator => double('verbosinator').as_null_object
      })
      @fpu = described_class.new({
        :configurator => @configurator,
        :file_wrapper => @file_wrapper
      })

      allow(@configurator).to receive(:extension_object).and_return( FilenameExtension.new('.o') )
      allow(@configurator).to receive(:project_build_root).and_return('build')
    end

    it 'places a test, module-under-test or support source by its path from the project root' do
      objects = @fpu.form_test_build_objects_filelist(
        'build/test/out/TestFoo', ['test/TestFoo.c', 'drivers/foo/bar.c', 'drivers/baz/bar.c', 'support/qux.c']
      )
      expect( objects ).to eq([
        'build/test/out/TestFoo/test/TestFoo.o',
        'build/test/out/TestFoo/drivers/foo/bar.o',
        'build/test/out/TestFoo/drivers/baz/bar.o',
        'build/test/out/TestFoo/support/qux.o'
      ])
    end

    # A source collected by one spelling and configured by another is still one source
    it 'builds one file named by two spellings once, as no collision' do
      objects = @fpu.form_test_build_objects_filelist(
        'build/test/out/TestFoo', ['test/support/helper.c', './test/support/helper.c', 'build/vendor/c_exception/lib/CException.c', './build/vendor/c_exception/lib/CException.c']
      )
      expect( objects ).to eq(['build/test/out/TestFoo/test/support/helper.o', 'build/test/out/TestFoo/CException.o'])
    end

    # A source far from the project gains a directory for each level its path climbs, which
    # can reach Windows' path length limit
    it 'checks the length of each object\'s whole path, once' do
      expect(@file_wrapper).to receive(:check_path_length).with( 'build/test/out/TestFoo/_up_/_up_/far/src/x.o', origin: 'FilePathUtils#build_filepath' ).once

      2.times { @fpu.form_test_build_objects_filelist( 'build/test/out/TestFoo', ['../../far/src/x.c'] ) }
    end

    it 'leaves a runner or vendored framework source below the build root flat' do
      objects = @fpu.form_test_build_objects_filelist(
        'build/test/out/TestFoo', ['build/test/runners/TestFoo_runner.c', 'build/vendor/unity/src/unity.c']
      )
      expect( objects ).to eq(['build/test/out/TestFoo/TestFoo_runner.o', 'build/test/out/TestFoo/unity.o'])
    end

    # Generated Partial sources sit below their own build root, not a configured source
    # root, so nothing in the standard roots mirrors them. Two modules sharing a basename
    # then collapse onto one object filename.
    it 'mirrors a generated Partial source beneath an extra root' do
      objects = @fpu.form_test_build_objects_filelist(
        'build/test/out/TestFoo',
        [
          'build/test/partials/TestFoo/drivers/uart/ceedling_partial_config_impl.c',
          'build/test/partials/TestFoo/drivers/spi/ceedling_partial_config_impl.c'
        ],
        extra_roots: ['build/test/partials/TestFoo']
      )

      expect( objects ).to eq([
        'build/test/out/TestFoo/drivers/uart/ceedling_partial_config_impl.o',
        'build/test/out/TestFoo/drivers/spi/ceedling_partial_config_impl.o'
      ])
    end

    it 'leaves a generated source flat when its root is not supplied' do
      objects = @fpu.form_test_build_objects_filelist(
        'build/test/out/TestFoo',
        ['build/test/partials/TestFoo/drivers/uart/ceedling_partial_config_impl.c']
      )

      expect( objects ).to eq(['build/test/out/TestFoo/ceedling_partial_config_impl.o'])
    end
  end

  describe '#form_pass_results_filelist' do
    before(:each) do
      @configurator = double('configurator')
      @file_wrapper = FileWrapper.new({
        :loginator    => double('loginator').as_null_object,
        :verbosinator => double('verbosinator').as_null_object
      })
      @fpu = described_class.new({
        :configurator => @configurator,
        :file_wrapper => @file_wrapper
      })

      allow(@configurator).to receive(:extension_testpass).and_return( FilenameExtension.new('.pass') )
      allow(@configurator).to receive(:project_build_root).and_return( 'build' )
      allow(@file_wrapper).to receive(:check_path_length)
    end

    it 'mirrors each expected results file beneath the same test name its own build directory uses' do
      results = @fpu.form_pass_results_filelist(
        'build/test/results', ['test/unit/test_foo.c', 'test/integration/test_foo.c']
      )
      expect( results ).to include('build/test/results/test/unit/test_foo.pass')
      expect( results ).to include('build/test/results/test/integration/test_foo.pass')
    end

    it 'places a test at its root beneath that root, as its name does' do
      results = @fpu.form_pass_results_filelist('build/test/results', ['test/test_bar.c'])
      expect( results ).to eq(['build/test/results/test/test_bar.pass'])
    end

    # GH #1364: same-named tests at a root and below it, and under two roots
    it 'gives same-named tests distinct results files' do
      tests = ['test/test_calc.c', 'test/unit/test_calc.c', 'extra/unit/test_calc.c']
      results = @fpu.form_pass_results_filelist( 'build/test/results', tests )
      expect( results.uniq.size ).to eq(3)
    end

    it 'agrees with the results path each test is given' do
      ['test/test_calc.c', 'test/unit/test_calc.c', '../shared/test/test_s.c'].each do |test|
        name = @fpu.form_test_name( test )
        expected = @fpu.form_pass_results_filepath( @fpu.form_test_results_path( name, context: 'test' ), test )
        expect( @fpu.form_pass_results_filelist( 'build/test/results', [test] ) ).to eq([expected])
      end
    end
  end

  describe '#form_test_name' do
    before(:each) do
      @fpu = described_class.new({ :configurator => double('configurator'), :file_wrapper => double('file_wrapper') })
    end

    it 'names a test by its path from the project root, without its extension' do
      expect( @fpu.form_test_name( 'test/test_calc.c' ) ).to eq('test/test_calc')
      expect( @fpu.form_test_name( 'test/unit/test_calc.c' ) ).to eq('test/unit/test_calc')
    end

    # GH #1364: the same layout under two roots and a :files test outside every root
    it 'keeps the root, so same-named tests under different roots get different names' do
      names = ['test/foo/test_x.c', 'extra/foo/test_x.c', 'other/test_x.c'].map { |test| @fpu.form_test_name( test ) }
      expect( names ).to eq(['test/foo/test_x', 'extra/foo/test_x', 'other/test_x'])
    end

    it 'gives one name however the path is written' do
      expect( @fpu.form_test_name( './test/unit/test_calc.c' ) ).to eq('test/unit/test_calc')
      expect( @fpu.form_test_name( 'test\\unit\\test_calc.c' ) ).to eq('test/unit/test_calc')
      expect( @fpu.form_test_name( File.join( Dir.pwd, 'test/unit/test_calc.c' ) ) ).to eq('test/unit/test_calc')
    end

    it 'keeps a test outside the project inside the build directory' do
      expect( @fpu.form_test_name( '../shared/test/unit/test_s.c' ) ).to eq('_up_/shared/test/unit/test_s')
      expect( @fpu.form_test_name( '../../other/test_o.c' ) ).to eq('_up_/_up_/other/test_o')
    end

    it 'names an absolute path outside the project by its path from the project' do
      outside = File.join( File.dirname( Dir.pwd ), 'shared', 'test', 'test_s.c' )
      expect( @fpu.form_test_name( outside ) ).to eq('_up_/shared/test/test_s')
    end

    # A drive other than the working directory's, which on Windows may itself be C: or D:
    it 'places a test on another Windows drive beneath its drive letter' do
      drive = Dir.pwd.match?( /\A[Qq]:/ ) ? 'R' : 'Q'

      expect( @fpu.form_test_name( "#{drive}:/work/test/test_x.c" ) ).to eq("_abs_/#{drive}/work/test/test_x")
      expect( @fpu.form_test_name( "#{drive}:\\work\\test\\test_x.c" ) ).to eq("_abs_/#{drive}/work/test/test_x")
    end

    it 'names a test on the working directory\'s own Windows drive by its relative path', if: Dir.pwd.match?( /\A[A-Za-z]:/ ) do
      inside = File.join( Dir.pwd, 'test', 'test_x.c' ).tr( '/', '\\' )
      expect( @fpu.form_test_name( inside ) ).to eq('test/test_x')
    end
  end

  describe '#form_preprocessed_includes_list_filepath' do
    before(:each) do
      @configurator = double('configurator')
      @file_wrapper = double('file_wrapper')
      allow(@file_wrapper).to receive(:check_path_length)
      @fpu = described_class.new({
        :configurator => @configurator,
        :file_wrapper => @file_wrapper
      })

      allow(@configurator).to receive(:project_test_preprocess_includes_path).and_return('build/test/preprocess/includes')
      allow(@configurator).to receive(:project_build_root).and_return('build')
      allow(@configurator).to receive(:project_use_partials).and_return( false )
      allow(@configurator).to receive(:project_use_mocks).and_return( false )
    end

    it 'uses the fixed internal .yml extension regardless of a project-configured :extension ↳ :yaml setting' do
      expect(@configurator).to_not receive(:extension_yaml)
      expect( @fpu.form_preprocessed_includes_list_filepath('test/TestFoo.c', 'TestFoo') )
        .to eq('build/test/preprocess/includes/TestFoo/test/TestFoo.c.yml')
    end
  end

  describe '#form_partial_types_header_filename' do
    before(:each) do
      @fpu = described_class.new({
        :configurator => double('configurator'),
        :file_wrapper => double('file_wrapper')
      })
    end

    it 'forms a filename from the module name, the partial prefix, and a _types suffix' do
      # Mirrors the sibling _interface/_impl header filename conventions -- a shared
      # location for a module's typedefs and aggregate definitions needs a name
      # distinct from those two generated headers so all three can coexist.
      expect( @fpu.form_partial_types_header_filename('LightSensor') )
        .to eq('ceedling_partial_LightSensor_types.h')
    end
  end

  # The four remaining generated Partial filenames. Each is the name a test file's
  # own Partial directive macro expands to, so the name a macro emits and the name
  # formed here must agree exactly or the compiler finds nothing.
  describe 'the remaining generated Partial filenames' do
    before(:each) do
      @configurator = double('configurator')
      @fpu = described_class.new({
        :configurator => @configurator,
        :file_wrapper => double('file_wrapper')
      })
    end

    it 'forms an interface header filename with the partial prefix and an _interface suffix' do
      expect( @fpu.form_partial_interface_header_filename('LightSensor') )
        .to eq('ceedling_partial_LightSensor_interface.h')
    end

    it 'forms an implementation header filename with the partial prefix and an _impl suffix' do
      expect( @fpu.form_partial_implementation_header_filename('LightSensor') )
        .to eq('ceedling_partial_LightSensor_impl.h')
    end

    it 'forms an implementation source filename sharing the header name but a source extension' do
      expect( @fpu.form_partial_implementation_source_filename('LightSensor') )
        .to eq('ceedling_partial_LightSensor_impl.c')
    end

    # Two prefixes stack here, mock outermost. CMock generates its mock from the
    # generated interface header, so the result carries both names.
    it 'forms a mock interface header filename carrying the mock prefix ahead of the partial prefix' do
      expect(@configurator).to receive(:cmock_mock_prefix).and_return('Mock')

      expect( @fpu.form_mock_partial_interface_header_filename('LightSensor') )
        .to eq('Mockceedling_partial_LightSensor_interface.h')
    end

    it 'honors a project-configured mock prefix' do
      expect(@configurator).to receive(:cmock_mock_prefix).and_return('fake_')

      expect( @fpu.form_mock_partial_interface_header_filename('LightSensor') )
        .to eq('fake_ceedling_partial_LightSensor_interface.h')
    end
  end

  # A module named by directory keeps that directory, and the prefixes attach to the
  # basename rather than to the first path segment. These results are exactly the
  # strings a directory-qualified directive macro expands to, which is what lets the
  # compiler resolve the generated #include.
  describe 'generated Partial filenames for a module named by directory' do
    before(:each) do
      @configurator = double('configurator')
      @fpu = described_class.new({
        :configurator => @configurator,
        :file_wrapper => double('file_wrapper')
      })
    end

    it 'prefixes the basename and keeps the directory for an implementation header' do
      expect( @fpu.form_partial_implementation_header_filename('drivers/uart/config') )
        .to eq('drivers/uart/ceedling_partial_config_impl.h')
    end

    it 'prefixes the basename and keeps the directory for an implementation source' do
      expect( @fpu.form_partial_implementation_source_filename('drivers/uart/config') )
        .to eq('drivers/uart/ceedling_partial_config_impl.c')
    end

    it 'prefixes the basename and keeps the directory for an interface header' do
      expect( @fpu.form_partial_interface_header_filename('drivers/uart/config') )
        .to eq('drivers/uart/ceedling_partial_config_interface.h')
    end

    it 'prefixes the basename and keeps the directory for a types header' do
      expect( @fpu.form_partial_types_header_filename('drivers/uart/config') )
        .to eq('drivers/uart/ceedling_partial_config_types.h')
    end

    it 'stacks both prefixes on the basename for a mock interface header' do
      allow(@configurator).to receive(:cmock_mock_prefix).and_return('Mock')

      expect( @fpu.form_mock_partial_interface_header_filename('drivers/uart/config') )
        .to eq('drivers/uart/Mockceedling_partial_config_interface.h')
    end

    it 'keeps a single directory segment' do
      expect( @fpu.form_partial_implementation_header_filename('uart/config') )
        .to eq('uart/ceedling_partial_config_impl.h')
    end
  end

  # The inverse of the builders above. A generated Partial filename is Ceedling's own
  # invention, so a message naming one tells a test author nothing. Recovering the
  # module lets a message name what the author actually wrote.
  describe '#module_from_partial_filename' do
    before(:each) do
      @configurator = double('configurator')
      allow(@configurator).to receive(:cmock_mock_prefix).and_return('Mock')
      @fpu = described_class.new({
        :configurator => @configurator,
        :file_wrapper => double('file_wrapper')
      })
    end

    it 'recovers a module named without a directory' do
      expect( @fpu.module_from_partial_filename('ceedling_partial_config_impl.c') )
        .to eq('config')
    end

    it 'recovers a module named by directory, keeping the directory' do
      expect( @fpu.module_from_partial_filename('drivers/uart/ceedling_partial_config_impl.h') )
        .to eq('drivers/uart/config')
    end

    # Three suffixes exist, one per generated file kind.
    it 'strips an implementation suffix' do
      expect( @fpu.module_from_partial_filename('ceedling_partial_config_impl.h') ).to eq('config')
    end

    it 'strips an interface suffix' do
      expect( @fpu.module_from_partial_filename('ceedling_partial_config_interface.h') ).to eq('config')
    end

    it 'strips a types suffix' do
      expect( @fpu.module_from_partial_filename('ceedling_partial_config_types.h') ).to eq('config')
    end

    # Two prefixes stack on a mocked interface header, mock outermost.
    it 'strips a mock prefix ahead of the partial prefix' do
      expect( @fpu.module_from_partial_filename('drivers/uart/Mockceedling_partial_config_interface.h') )
        .to eq('drivers/uart/config')
    end

    it 'leaves a module whose own name ends in a suffix word intact' do
      expect( @fpu.module_from_partial_filename('ceedling_partial_impl_impl.c') ).to eq('impl')
    end

    it 'returns nil for a filename that is not a generated Partial' do
      expect( @fpu.module_from_partial_filename('config.h') ).to be_nil
    end

    # Round trip, so the inverse stays tied to the builder it mirrors.
    it 'round trips every builder' do
      %w[config drivers/uart/config].each do |_module|
        [
          @fpu.form_partial_implementation_header_filename( _module ),
          @fpu.form_partial_implementation_source_filename( _module ),
          @fpu.form_partial_interface_header_filename( _module ),
          @fpu.form_partial_types_header_filename( _module ),
          @fpu.form_mock_partial_interface_header_filename( _module )
        ].each do |generated|
          expect( @fpu.module_from_partial_filename( generated ) )
            .to( eq(_module), "#{generated} did not reverse to #{_module}" )
        end
      end
    end
  end

  describe '#form_named_path' do
    before(:each) do
      @file_wrapper = double('file_wrapper')
      allow(@file_wrapper).to receive(:check_path_length)
      @fpu = described_class.new({
        :configurator => double('configurator'),
        :file_wrapper => @file_wrapper
      })
    end

    # form_named_path is private -- exercised via #send, same as its callers do internally.
    it 'checks the constructed path length, identifying itself as the origin' do
      @fpu.send(:form_named_path, 'build/test/preprocess/files', 'test_foo')
      expect(@file_wrapper).to have_received(:check_path_length)
        .with('build/test/preprocess/files/test_foo', origin: 'FilePathUtils#form_named_path')
    end

    it 'checks the constructed path length including an optional subdir' do
      @fpu.send(:form_named_path, 'build/test/preprocess/files', 'test_foo', subdir: 'full_expansion')
      expect(@file_wrapper).to have_received(:check_path_length)
        .with('build/test/preprocess/files/test_foo/full_expansion', origin: 'FilePathUtils#form_named_path')
    end
  end

  describe '#form_build_context_path' do
    before(:each) do
      @configurator = double('configurator')
      @file_wrapper = double('file_wrapper')
      allow(@file_wrapper).to receive(:check_path_length)
      allow(@configurator).to receive(:project_build_root).and_return('build')
      @fpu = described_class.new({
        :configurator => @configurator,
        :file_wrapper => @file_wrapper
      })
    end

    # form_build_context_path is private -- exercised via #send, same as its callers do internally.
    it 'checks the constructed path length, identifying itself as the origin' do
      @fpu.send(:form_build_context_path, 'out', name: 'TestFoo')
      expect(@file_wrapper).to have_received(:check_path_length)
        .with('build/out/TestFoo', origin: 'FilePathUtils#form_build_context_path')
    end
  end

end
