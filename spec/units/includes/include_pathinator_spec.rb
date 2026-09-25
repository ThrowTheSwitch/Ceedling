# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/includes/include_pathinator'
require 'ceedling/filename_extension'
require 'rake'

EXTENSION_HEADER = FilenameExtension.new('.h') unless defined?(EXTENSION_HEADER)

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

  describe '#validate_test_build_directive_paths' do
    it 'completes without raising when inspect_include_paths yields nothing' do
      allow(@extractor).to receive(:inspect_include_paths)

      expect { @pathinator.validate_test_build_directive_paths }.not_to raise_error
    end

    it 'does not raise when every yielded path exists' do
      allow(@extractor).to receive(:inspect_include_paths).and_yield('test_foo.c', ['inc'])
      allow(@file_wrapper).to receive(:exist?).with('inc').and_return(true)

      expect { @pathinator.validate_test_build_directive_paths }.not_to raise_error
    end

    it "raises CeedlingException naming the missing path and the test file when a path doesn't exist" do
      allow(@extractor).to receive(:inspect_include_paths).and_yield('test_foo.c', ['missing_dir'])
      allow(@file_wrapper).to receive(:exist?).with('missing_dir').and_return(false)

      expect { @pathinator.validate_test_build_directive_paths }.to raise_error(
        CeedlingException, /'missing_dir'.*TEST_INCLUDE_PATH\(\).*test_foo\.c/
      )
    end

    it 'raises when a later path is missing even though an earlier path for the same test file exists' do
      allow(@extractor).to receive(:inspect_include_paths).and_yield('test_foo.c', ['inc', 'missing_dir'])
      allow(@file_wrapper).to receive(:exist?).with('inc').and_return(true)
      allow(@file_wrapper).to receive(:exist?).with('missing_dir').and_return(false)

      expect { @pathinator.validate_test_build_directive_paths }.to raise_error(CeedlingException, /missing_dir/)
    end
  end

  describe '#validate_header_files_collection' do
    it 'returns collection_all_headers unaugmented when there are no directive paths' do
      allow(@configurator).to receive(:collection_all_headers).and_return(Rake::FileList.new(['inc/foo.h']))
      allow(@extractor).to receive(:lookup_all_include_paths).and_return([])
      allow(@file_wrapper).to receive(:instantiate_file_list).with([]).and_return(Rake::FileList.new)
      allow(@loginator).to receive(:log)

      result = @pathinator.validate_header_files_collection

      expect(result.to_a).to eq(['inc/foo.h'])
    end

    it 'combines collection_all_headers with headers found via directive paths, resolved and de-duplicated' do
      allow(@configurator).to receive(:collection_all_headers).and_return(Rake::FileList.new(['inc/foo.h']))
      allow(@extractor).to receive(:lookup_all_include_paths).and_return(['extra'])
      allow(@file_wrapper).to receive(:instantiate_file_list)
        .with(EXTENSION_HEADER.glob_patterns('extra'))
        .and_return(Rake::FileList.new(['extra/bar.h']))
      allow(@loginator).to receive(:log)

      result = @pathinator.validate_header_files_collection

      expect(result.to_a).to match_array(['inc/foo.h', 'extra/bar.h'])
    end

    it 'de-duplicates a header reachable both via collection_all_headers and a directive path' do
      allow(@configurator).to receive(:collection_all_headers).and_return(Rake::FileList.new(['inc/foo.h']))
      allow(@extractor).to receive(:lookup_all_include_paths).and_return(['inc'])
      allow(@file_wrapper).to receive(:instantiate_file_list)
        .with(EXTENSION_HEADER.glob_patterns('inc'))
        .and_return(Rake::FileList.new(['inc/foo.h']))
      allow(@loginator).to receive(:log)

      result = @pathinator.validate_header_files_collection

      expect(result.to_a).to eq(['inc/foo.h'])
    end

    it 'logs a COMPLAIN-level message naming TEST_INCLUDE_PATH() when no headers are found at all' do
      allow(@configurator).to receive(:collection_all_headers).and_return(Rake::FileList.new)
      allow(@extractor).to receive(:lookup_all_include_paths).and_return([])
      allow(@file_wrapper).to receive(:instantiate_file_list).with([]).and_return(Rake::FileList.new)

      expect(@loginator).to receive(:log)
        .with(a_string_matching(/No header files found/), Verbosity::COMPLAIN)

      @pathinator.validate_header_files_collection
    end

    it 'does not log when headers are found' do
      allow(@configurator).to receive(:collection_all_headers).and_return(Rake::FileList.new(['inc/foo.h']))
      allow(@extractor).to receive(:lookup_all_include_paths).and_return([])
      allow(@file_wrapper).to receive(:instantiate_file_list).with([]).and_return(Rake::FileList.new)

      expect(@loginator).not_to receive(:log)

      @pathinator.validate_header_files_collection
    end
  end

  describe '#augment_environment_header_files' do
    it 'delegates to configurator.redefine_element with :collection_all_headers and the given headers, unchanged' do
      headers = ['inc/foo.h', 'inc/bar.h']
      expect(@configurator).to receive(:redefine_element).with(:collection_all_headers, headers)

      @pathinator.augment_environment_header_files(headers)
    end
  end

  describe '#lookup_test_directive_include_paths' do
    it "delegates to the extractor's lookup_include_paths_list and returns its result unchanged" do
      allow(@extractor).to receive(:lookup_include_paths_list).with('test_foo.c').and_return(['a', 'b'])

      expect(@pathinator.lookup_test_directive_include_paths('test_foo.c')).to eq(['a', 'b'])
    end
  end

  describe '#collect_test_include_paths' do
    it 'returns an empty list when there are no configured test paths' do
      allow(@configurator).to receive(:collection_paths_test).and_return([])

      expect(@pathinator.collect_test_include_paths).to eq([])
    end

    it 'includes a path that contains header files' do
      allow(@configurator).to receive(:collection_paths_test).and_return(['test/support'])
      allow(@file_wrapper).to receive(:directory_listing)
        .with(['test/support/*.h']).and_return(['test/support/mock.h'])

      expect(@pathinator.collect_test_include_paths).to eq(['test/support'])
    end

    it 'excludes a path that contains no header files' do
      allow(@configurator).to receive(:collection_paths_test).and_return(['test/support'])
      allow(@file_wrapper).to receive(:directory_listing).with(['test/support/*.h']).and_return([])

      expect(@pathinator.collect_test_include_paths).to eq([])
    end

    it 'returns only header-bearing paths, in the original order, from a mixed list' do
      allow(@configurator).to receive(:collection_paths_test).and_return(['empty_dir', 'has_headers', 'also_empty'])
      allow(@file_wrapper).to receive(:directory_listing).with(['empty_dir/*.h']).and_return([])
      allow(@file_wrapper).to receive(:directory_listing).with(['has_headers/*.h']).and_return(['has_headers/foo.h'])
      allow(@file_wrapper).to receive(:directory_listing).with(['also_empty/*.h']).and_return([])

      expect(@pathinator.collect_test_include_paths).to eq(['has_headers'])
    end
  end
end
