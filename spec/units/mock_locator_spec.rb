# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/constants'
require 'ceedling/includes/includes'
require 'ceedling/test_invoker/mock_locator'

describe MockLocator do
  before(:each) do
    @configurator       = double( "Configurator", cmock_mock_prefix: 'Mock' )
    @include_pathinator = double( "IncludePathinator" )
    @file_finder        = double( "FileFinder" )
    @file_path_utils    = double( "FilePathUtils" )

    allow(@file_path_utils).to receive(:form_mock_output_path) do |root, subdir|
      subdir.nil? || subdir.empty? ? root : File.join( root, subdir )
    end

    @locator = described_class.new(
      configurator: @configurator, include_pathinator: @include_pathinator, file_finder: @file_finder, file_path_utils: @file_path_utils
    )
  end

  describe "#header_collection" do
    it "orders the headers on a test's search paths without its own mock directories" do
      expect(@include_pathinator).to receive(:ordered_header_files).with( ['src'] ).and_return( ['src/foo.h'] )

      expect(@locator.header_collection( ['mocks/drivers', 'src'], ['mocks/drivers'] )).to eq( ['src/foo.h'] )
    end
  end

  describe "#locate" do
    it "resolves a mock's real header and its mirrored subdirectory against a collection" do
      allow(@file_finder).to receive(:resolve_mock).with( 'MockFoo.h', collection: ['src/drivers/foo.h'], complain: :error )
        .and_return( ['src/drivers/foo.h', 'drivers'] )

      expect(@locator.locate( MockInclude.new( 'MockFoo.h' ), collection: ['src/drivers/foo.h'] )).to eq( ['src/drivers/foo.h', 'drivers'] )
    end

    it "passes on how to treat a missing header" do
      expect(@file_finder).to receive(:resolve_mock).with( 'MockFoo.h', collection: [], complain: :ignore ).and_return( [nil, nil] )

      expect(@locator.locate( MockInclude.new( 'MockFoo.h' ), collection: [], complain: :ignore )).to eq( [nil, nil] )
    end
  end

  describe "#directories" do
    it "gives each mock's mirrored directory below the mock root, once" do
      allow(@file_finder).to receive(:resolve_mock).with( 'MockFoo.h', collection: [], complain: :error ).and_return( ['src/drivers/foo.h', 'drivers'] )
      allow(@file_finder).to receive(:resolve_mock).with( 'MockBar.h', collection: [], complain: :error ).and_return( ['src/drivers/bar.h', 'drivers'] )
      allow(@file_finder).to receive(:resolve_mock).with( 'MockBaz.h', collection: [], complain: :error ).and_return( ['src/baz.h', ''] )
      mocks = %w[MockFoo.h MockBar.h MockBaz.h].map { |name| MockInclude.new( name ) }

      expect(@locator.directories( mocks, mocks_root: 'mocks', collection: [] )).to eq( ['mocks/drivers', 'mocks'] )
    end

    it "skips a Partial mock, which has no real header" do
      expect(@file_finder).to_not receive(:resolve_mock)

      expect(@locator.directories( [MockInclude.new( "Mock#{PARTIAL_FILENAME_PREFIX}foo_interface.h" )], mocks_root: 'mocks', collection: [] )).to eq( [] )
    end

    it "skips a mock whose missing header the caller tolerates" do
      allow(@file_finder).to receive(:resolve_mock).with( 'MockGone.h', collection: [], complain: :ignore ).and_return( [nil, nil] )

      expect(@locator.directories( [MockInclude.new( 'MockGone.h' )], mocks_root: 'mocks', collection: [], complain: :ignore )).to eq( [] )
    end
  end
end
