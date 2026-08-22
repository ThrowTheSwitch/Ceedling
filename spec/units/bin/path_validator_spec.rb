# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'path_validator'
require 'ceedling/constants'

describe PathValidator do
  before(:each) do
    @file_wrapper = double('file_wrapper')
    @loginator    = double('loginator').as_null_object

    @path_validator = described_class.new({
      :file_wrapper => @file_wrapper,
      :loginator    => @loginator,
    })
  end

  describe '#validate' do
    it 'passes when every path exists as a filepath' do
      allow(@file_wrapper).to receive(:exist?).and_return( true )

      expect(@path_validator.validate( paths: ['a.yml', 'b.yml'], source: 'Test' )).to eq( true )
    end

    it 'fails and logs when a path is empty' do
      expect(@loginator).to receive(:log).with( /contains an empty path/, Verbosity::ERRORS )

      expect(@path_validator.validate( paths: [''], source: 'Test' )).to eq( false )
    end

    it 'fails and logs when a filepath does not exist' do
      allow(@file_wrapper).to receive(:exist?).and_return( false )
      expect(@loginator).to receive(:log).with( /does not exist in the filesystem/, Verbosity::ERRORS )

      expect(@path_validator.validate( paths: ['missing.yml'], source: 'Test' )).to eq( false )
    end

    it 'fails and logs when a directory does not exist' do
      allow(@file_wrapper).to receive(:directory?).and_return( false )
      expect(@loginator).to receive(:log).with( /does not exist as a directory/, Verbosity::ERRORS )

      expect(@path_validator.validate( paths: ['missing/'], source: 'Test', type: :directory )).to eq( false )
    end

    it 'checks every path rather than stopping at the first failure' do
      allow(@file_wrapper).to receive(:exist?).and_return( false )
      expect(@loginator).to receive(:log).twice

      expect(@path_validator.validate( paths: ['a.yml', 'b.yml'], source: 'Test' )).to eq( false )
    end
  end

  describe '#standardize_paths' do
    # Current behavior: converts backslashes in place via String#gsub!, mutating
    # the caller's own String objects rather than returning new ones.
    it 'converts backslashes to forward slashes in place' do
      path = 'some\\windows\\path.yml'

      @path_validator.standardize_paths( path )

      expect(path).to eq( 'some/windows/path.yml' )
    end

    it 'mutates every argument given' do
      a = 'one\\two'
      b = 'three\\four'

      @path_validator.standardize_paths( a, b )

      expect(a).to eq( 'one/two' )
      expect(b).to eq( 'three/four' )
    end

    it 'leaves already-forward-slash paths unchanged' do
      path = 'already/unix/style.yml'

      @path_validator.standardize_paths( path )

      expect(path).to eq( 'already/unix/style.yml' )
    end

    it 'skips nil and empty arguments without raising' do
      expect { @path_validator.standardize_paths( nil, '' ) }.to_not raise_error
    end
  end

  describe '#filepath?' do
    it 'is true for a value with a file extension' do
      expect(@path_validator.filepath?( 'clang.yml' )).to eq( true )
    end

    it 'is true for a value containing a path separator, even without an extension' do
      expect(@path_validator.filepath?( File.join('mixins', 'clang') )).to eq( true )
    end

    it 'is false for a bare name with neither an extension nor a separator' do
      expect(@path_validator.filepath?( 'clang' )).to eq( false )
    end
  end
end
