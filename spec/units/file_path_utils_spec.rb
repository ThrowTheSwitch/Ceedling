# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/file_path_utils'

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

end
