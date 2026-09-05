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

  describe '.resolve' do
    it 'returns the single match and an empty passed-over list when a bare basename is unique' do
      winner, others = described_class.resolve('a.c', COLLECTION)
      expect(winner).to eq('some/dir/a.c')
      expect(others).to eq([])
    end

    it 'returns nil and an empty passed-over list when nothing matches' do
      winner, others = described_class.resolve('nope.c', COLLECTION)
      expect(winner).to be_nil
      expect(others).to eq([])
    end

    it 'never raises on an ambiguous bare basename -- picks the first candidate in collection order' do
      winner, others = described_class.resolve('c.cpp', COLLECTION)
      expect(winner).to eq('here/src/c.cpp')
      expect(others).to eq(['copy/SRC/c.cpp'])
    end

    it 'still resolves via disambiguating trailing path exactly as .match does, with nothing passed over' do
      winner, others = described_class.resolve('src/c.cpp', COLLECTION)
      expect(winner).to eq('here/src/c.cpp')
      expect(others).to eq([])
    end

    it 'picks the first of three or more ambiguous candidates, naming the rest as passed over' do
      collection = ['b/x.h', 'a/x.h', 'c/x.h']
      winner, others = described_class.resolve('x.h', collection)
      expect(winner).to eq('b/x.h')
      expect(others).to eq(['a/x.h', 'c/x.h'])
    end

    it 'resolves an empty collection to nil with nothing passed over' do
      winner, others = described_class.resolve('a.c', [])
      expect(winner).to be_nil
      expect(others).to eq([])
    end
  end

  describe '.resolve_relative' do
    it 'returns a query with no .. segment completely unchanged, anchor or not' do
      expect(described_class.resolve_relative('foo/bar.h')).to eq('foo/bar.h')
      expect(described_class.resolve_relative('foo/bar.h', anchor: 'test/unit')).to eq('foo/bar.h')
    end

    it 'resolves a single leading .. against the anchor directory' do
      expect(described_class.resolve_relative('../common/helper.h', anchor: 'test/unit')).to eq('test/common/helper.h')
    end

    it 'resolves multiple leading .. segments, one anchor segment popped per ..' do
      expect(described_class.resolve_relative('../../common/helper.h', anchor: 'test/unit/adc')).to eq('test/common/helper.h')
    end

    it 'collapses an internal .. against an empty-string anchor, for an already self-contained path' do
      # This is the shape GCC itself produces for a directory-relative quoted include --
      # a complete, project-root-relative path that merely needs its own .. collapsed,
      # not prefixed onto some other anchor.
      expect(described_class.resolve_relative('test/unit/../common/helper.h', anchor: '')).to eq('test/common/helper.h')
    end

    it 'raises a CeedlingException naming the query when .. is present and no anchor is available' do
      expect { described_class.resolve_relative('../common/helper.h') }.to raise_error(CeedlingException) do |error|
        expect(error.message).to include('../common/helper.h')
      end
    end

    it 'raises a CeedlingException naming the query when .. traverses past the anchor root' do
      expect { described_class.resolve_relative('../../common/helper.h', anchor: 'test') }.to raise_error(CeedlingException) do |error|
        expect(error.message).to include('../../common/helper.h')
      end
    end

    it 'passes an absolute query through unchanged, even one containing .., deferring to expand_path-based matching elsewhere' do
      expect(described_class.resolve_relative('/abs/unit/../common/helper.h')).to eq('/abs/unit/../common/helper.h')
    end

    it 'passes a Windows drive-letter query through unchanged, even one containing ..' do
      expect(described_class.resolve_relative('C:\\unit\\..\\common\\helper.h')).to eq('C:\\unit\\..\\common\\helper.h')
    end

    it 'treats a backslash-separated .. query the same as a forward-slash one' do
      expect(described_class.resolve_relative('..\\common\\helper.h', anchor: 'test/unit')).to eq('test/common/helper.h')
    end
  end

end
