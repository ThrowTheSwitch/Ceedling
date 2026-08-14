# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/file_path_utils'
require 'ceedling/file_wrapper'
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

    it 'forms a flat runner filepath for a flat test\'s own identity' do
      expect( @fpu.form_runner_filepath_from_test('test/test_foo.c', name: 'test_foo') )
        .to eq('build/test/runners/test_foo_runner.c')
    end

    it 'mirrors the runner beneath the test\'s own mirrored subdirectory, distinguishing same-named tests' do
      expect( @fpu.form_runner_filepath_from_test('test/unit/test_foo.c', name: 'unit/test_foo') )
        .to eq('build/test/runners/unit/test_foo_runner.c')

      expect( @fpu.form_runner_filepath_from_test('test/integration/test_foo.c', name: 'integration/test_foo') )
        .to eq('build/test/runners/integration/test_foo_runner.c')
    end

    it 'forms a flat runner directory for a flat test' do
      expect( @fpu.form_test_runners_path('test_foo') ).to eq('build/test/runners')
    end

    it 'forms the runner directory itself beneath a nested test\'s own mirrored subdirectory' do
      expect( @fpu.form_test_runners_path('unit/test_foo') ).to eq('build/test/runners/unit')
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

    it 'forms the list filepath directly alongside the object, wherever it was mirrored to' do
      expect( @fpu.form_test_build_list_filepath('build/test/out/TestFoo/calculators/AdcCalc.o') )
        .to eq('build/test/out/TestFoo/calculators/AdcCalc.lst')
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
      allow(@configurator).to receive(:extension_object).and_return( FilenameExtension.new('.o') )
      allow(@configurator).to receive(:paths_source).and_return( ['drivers'] )
    end

    it 'mirrors each object beneath whichever configured source root matched its file, distinguishing same-named sources' do
      objects = @fpu.form_release_build_objects_filelist( ['drivers/foo/bar.c', 'drivers/baz/bar.c'] )
      expect( objects ).to include('build/release/out/foo/bar.o')
      expect( objects ).to include('build/release/out/baz/bar.o')
    end

    it 'leaves a file matching no configured source root flat' do
      objects = @fpu.form_release_build_objects_filelist( ['vendor/unity.c'] )
      expect( objects ).to eq(['build/release/out/unity.o'])
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
      allow(@configurator).to receive(:extension_dependencies).and_return( FilenameExtension.new('.d') )
      allow(@configurator).to receive(:paths_source).and_return( ['drivers'] )
    end

    it 'mirrors each dependency file the same way as its corresponding object' do
      deps = @fpu.form_release_dependencies_filelist( ['drivers/foo/bar.c', 'drivers/baz/bar.c'] )
      expect( deps ).to include('build/release/dependencies/foo/bar.d')
      expect( deps ).to include('build/release/dependencies/baz/bar.d')
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
      allow(@configurator).to receive(:paths_source).and_return( ['drivers'] )
      allow(@configurator).to receive(:paths_support).and_return( ['support'] )
    end

    it 'mirrors a module-under-test or support source beneath its matching configured root' do
      objects = @fpu.form_test_build_objects_filelist(
        'build/test/out/TestFoo', ['drivers/foo/bar.c', 'drivers/baz/bar.c']
      )
      expect( objects ).to include('build/test/out/TestFoo/foo/bar.o')
      expect( objects ).to include('build/test/out/TestFoo/baz/bar.o')
    end

    it 'leaves the test file itself, mocks, and other unmatched inputs flat' do
      objects = @fpu.form_test_build_objects_filelist(
        'build/test/out/TestFoo', ['test/TestFoo.c', 'MockBar.c', 'support/qux.c']
      )
      expect( objects ).to eq([
        'build/test/out/TestFoo/TestFoo.o',
        'build/test/out/TestFoo/MockBar.o',
        'build/test/out/TestFoo/qux.o'
      ])
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
      allow(@configurator).to receive(:paths_test).and_return( ['test'] )
    end

    it 'mirrors each expected results file beneath the same test identity its own build directory uses' do
      results = @fpu.form_pass_results_filelist(
        'build/test/results', ['test/unit/test_foo.c', 'test/integration/test_foo.c']
      )
      expect( results ).to include('build/test/results/unit/test_foo.pass')
      expect( results ).to include('build/test/results/integration/test_foo.pass')
    end

    it 'leaves a flat test\'s own results file flat, undisturbed by mirroring' do
      results = @fpu.form_pass_results_filelist('build/test/results', ['test/test_bar.c'])
      expect( results ).to eq(['build/test/results/test_bar.pass'])
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
    end

    it 'uses the fixed internal .yml extension regardless of a project-configured :extension ↳ :yaml setting' do
      expect(@configurator).to_not receive(:extension_yaml)
      expect( @fpu.form_preprocessed_includes_list_filepath('test/TestFoo.c', 'TestFoo') )
        .to eq('build/test/preprocess/includes/TestFoo/TestFoo.c.yml')
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
