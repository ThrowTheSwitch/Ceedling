# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/includes/include_pathinator'
require 'ceedling/filename_extension'

describe IncludePathinator do
  before(:each) do
    @configurator = double( "Configurator" )
    @extractor = double( "TestContextExtractor" )
    @loginator = double( "Loginator" )
    @file_wrapper = double( "FileWrapper" )

    allow(@configurator).to receive(:extension_header).and_return( FilenameExtension.new('.h') )

    @pathinator = described_class.new(
      {
        :configurator => @configurator,
        :test_context_extractor => @extractor,
        :loginator => @loginator,
        :file_wrapper => @file_wrapper
      }
    )
  end

  describe '#ordered_header_files' do
    it 'returns an empty list given an empty search path list' do
      expect(@pathinator.ordered_header_files([])).to eq([])
    end

    it 'lists headers from a single search path' do
      allow(@file_wrapper).to receive(:directory_listing).with(['inc/*.h']).and_return( ['inc/foo.h', 'inc/bar.h'] )
      expect(@pathinator.ordered_header_files(['inc'])).to eq( ['inc/foo.h', 'inc/bar.h'] )
    end

    it 'concatenates headers from multiple search paths in the order the paths are given' do
      allow(@file_wrapper).to receive(:directory_listing).with(['first/*.h']).and_return( ['first/foo.h'] )
      allow(@file_wrapper).to receive(:directory_listing).with(['second/*.h']).and_return( ['second/foo.h'] )

      expect(@pathinator.ordered_header_files(['first', 'second'])).to eq( ['first/foo.h', 'second/foo.h'] )
    end

    it "ranks an earlier search path's same-named header ahead of a later path's, regardless of either path's own alphabetical position" do
      # 'zzz' precedes 'aaa' in the search path list even though it would sort after it --
      # a TEST_INCLUDE_PATH() directory, for instance, ranks ahead of :include even when its
      # own directory name would otherwise sort later.
      allow(@file_wrapper).to receive(:directory_listing).with(['zzz/*.h']).and_return( ['zzz/dup.h'] )
      allow(@file_wrapper).to receive(:directory_listing).with(['aaa/*.h']).and_return( ['aaa/dup.h'] )

      expect(@pathinator.ordered_header_files(['zzz', 'aaa'])).to eq( ['zzz/dup.h', 'aaa/dup.h'] )
    end

    it 'de-duplicates an identical filepath reachable more than once, keeping its first occurrence' do
      allow(@file_wrapper).to receive(:directory_listing).with(['inc/*.h']).and_return( ['inc/foo.h'] )

      expect(@pathinator.ordered_header_files(['inc', 'inc'])).to eq( ['inc/foo.h'] )
    end
  end
end
