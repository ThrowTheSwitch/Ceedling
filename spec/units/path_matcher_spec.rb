# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/path_matcher'
require 'ceedling/exceptions'

describe PathMatcher do

  COLLECTION = [
    'some/dir/a.c',
    'another/place/b.c',
    'here/src/c.cpp',
    'here/inc/c.hpp',
    'copy/SRC/c.cpp',
    'copy/inc/c.hpp'
  ].freeze

  describe '.match' do
    it 'finds a file by bare basename when it is unique in the collection' do
      expect(described_class.match('a.c', COLLECTION)).to eq('some/dir/a.c')
      expect(described_class.match('b.c', COLLECTION)).to eq('another/place/b.c')
    end

    it 'returns nil when no file in the collection has that basename' do
      expect(described_class.match('nope.c', COLLECTION)).to be_nil
    end

    it 'returns nil when a query with a path prefix matches nothing' do
      expect(described_class.match('missing/dir/a.c', COLLECTION)).to be_nil
    end

    it 'raises a CeedlingException naming every candidate when a bare basename is ambiguous' do
      expect { described_class.match('c.cpp', COLLECTION) }.to raise_error(CeedlingException) do |error|
        expect(error.message).to include('here/src/c.cpp')
        expect(error.message).to include('copy/SRC/c.cpp')
      end
    end

    it 'resolves an ambiguous basename when the query supplies enough trailing path to disambiguate' do
      expect(described_class.match('src/c.cpp', COLLECTION)).to eq('here/src/c.cpp')
      expect(described_class.match('SRC/c.cpp', COLLECTION)).to eq('copy/SRC/c.cpp')
      expect(described_class.match('copy/inc/c.hpp', COLLECTION)).to eq('copy/inc/c.hpp')
      expect(described_class.match('here/inc/c.hpp', COLLECTION)).to eq('here/inc/c.hpp')
    end

    it 'is still ambiguous when the supplied path narrows nothing (both candidates share that parent directory name)' do
      expect { described_class.match('inc/c.hpp', COLLECTION) }.to raise_error(CeedlingException)
    end

    it 'matches path segments exactly, case-sensitively, not as a substring' do
      # 'rc/c.cpp' is a substring of both 'src/c.cpp' entries' tails but is not a real
      # path segment sequence of either -- it must not match anything.
      expect(described_class.match('rc/c.cpp', COLLECTION)).to be_nil
    end

    it 'returns nil when the supplied path prefix matches no candidate at all' do
      expect(described_class.match('other/c.cpp', COLLECTION)).to be_nil
    end

    it 'treats backslash-separated queries the same as forward-slash queries' do
      expect(described_class.match('src\\c.cpp', COLLECTION)).to eq('here/src/c.cpp')
    end

    it 'matches an absolute path query only against its exact expanded file' do
      absolute = File.expand_path('here/src/c.cpp')
      expect(described_class.match(absolute, COLLECTION)).to eq('here/src/c.cpp')
    end

    it 'returns nil for an absolute path query with no corresponding file' do
      absolute = File.expand_path('nowhere/c.cpp')
      expect(described_class.match(absolute, COLLECTION)).to be_nil
    end

    it 'requires more path than just the basename when a query supplies only one segment among duplicates, even given an empty collection' do
      expect(described_class.match('a.c', [])).to be_nil
    end
  end

end
