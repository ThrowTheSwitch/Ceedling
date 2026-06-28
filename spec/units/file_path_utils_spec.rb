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

end
