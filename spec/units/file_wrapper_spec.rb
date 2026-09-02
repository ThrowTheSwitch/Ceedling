# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/file_wrapper'
require 'ceedling/system_wrapper'

describe FileWrapper do
  before(:each) do
    @loginator    = double('loginator')
    @verbosinator = double('verbosinator')

    @file_wrapper = described_class.new({
      :loginator    => @loginator,
      :verbosinator => @verbosinator
    })

    # Debug verbosity off by default in these examples -- explicitly enabled
    # only in the origin-prefix examples below.
    allow(@verbosinator).to receive(:should_output?).with(Verbosity::DEBUG).and_return(false)
    allow(@loginator).to receive(:log)

    # Pin the platform so limit-selection is deterministic regardless of the
    # machine actually running this spec.
    allow(SystemWrapper).to receive(:windows?).and_return(false)
    allow(SystemWrapper).to receive(:macos?).and_return(false)
  end

  # Absolute paths throughout: check_path_length measures File.expand_path(path).length,
  # so a relative path would pick up the test-runner's own CWD and throw off the
  # precise threshold arithmetic these examples depend on. The padding is sized off
  # File.expand_path('/')'s own actual length rather than assumed to be 1, since Windows
  # expands a bare '/' by prepending a drive letter (e.g. "C:/") -- without probing that
  # overhead first, expanded lengths on Windows would run a couple characters longer than
  # intended and throw off the precise threshold boundaries these examples depend on.
  def path_of_length(n)
    overhead = File.expand_path('/').length - 1
    '/' + ('a' * (n - 1 - overhead))
  end

  describe '#check_path_length' do
    # Linux limit (4096) is the default platform pinned in before(:each) above.

    it 'logs nothing for a path well under the limit' do
      @file_wrapper.check_path_length('/short/path.c', origin: 'Test')
      expect(@loginator).not_to have_received(:log)
    end

    it 'logs a WARNING once length is within the fixed margin (25) of the limit' do
      # 4096 - 25 == 4071 -- the first length at/over threshold
      @file_wrapper.check_path_length(path_of_length(4071), origin: 'Test')
      expect(@loginator).to have_received(:log).with(any_args, Verbosity::COMPLAIN)
    end

    it 'does not yet log a WARNING one character under the margin threshold' do
      @file_wrapper.check_path_length(path_of_length(4070), origin: 'Test')
      expect(@loginator).not_to have_received(:log)
    end

    it 'logs an ERROR once length reaches the limit' do
      @file_wrapper.check_path_length(path_of_length(4096), origin: 'Test')
      expect(@loginator).to have_received(:log).with(any_args, Verbosity::ERRORS)
    end

    it 'logs an ERROR for a length beyond the limit' do
      @file_wrapper.check_path_length(path_of_length(5000), origin: 'Test')
      expect(@loginator).to have_received(:log).with(any_args, Verbosity::ERRORS)
    end

    it 'never raises regardless of path length' do
      expect { @file_wrapper.check_path_length(path_of_length(10_000), origin: 'Test') }.not_to raise_error
    end

    context 'origin prefix' do
      it 'omits the origin from the message when verbosity is below DEBUG' do
        allow(@verbosinator).to receive(:should_output?).with(Verbosity::DEBUG).and_return(false)
        @file_wrapper.check_path_length(path_of_length(5000), origin: 'FileWrapper#mkdir_tmp')
        expect(@loginator).to have_received(:log) do |message, _verbosity|
          expect(message).not_to include('FileWrapper#mkdir_tmp')
        end
      end

      it 'includes the origin in the message when verbosity is DEBUG' do
        allow(@verbosinator).to receive(:should_output?).with(Verbosity::DEBUG).and_return(true)
        @file_wrapper.check_path_length(path_of_length(5000), origin: 'FileWrapper#mkdir_tmp')
        expect(@loginator).to have_received(:log) do |message, _verbosity|
          expect(message).to include('FileWrapper#mkdir_tmp')
        end
      end
    end

    context 'platform limit selection' do
      it 'uses the Windows limit (260) when SystemWrapper.windows? is true' do
        allow(SystemWrapper).to receive(:windows?).and_return(true)
        @file_wrapper.check_path_length(path_of_length(260), origin: 'Test')
        expect(@loginator).to have_received(:log).with(any_args, Verbosity::ERRORS)
      end

      it 'does not yet flag a path under the Windows limit' do
        allow(SystemWrapper).to receive(:windows?).and_return(true)
        @file_wrapper.check_path_length(path_of_length(200), origin: 'Test')
        expect(@loginator).not_to have_received(:log)
      end

      it 'uses the macOS limit (1024) when SystemWrapper.macos? is true' do
        allow(SystemWrapper).to receive(:macos?).and_return(true)
        @file_wrapper.check_path_length(path_of_length(1024), origin: 'Test')
        expect(@loginator).to have_received(:log).with(any_args, Verbosity::ERRORS)
      end

      it 'does not yet flag a path under the macOS limit' do
        allow(SystemWrapper).to receive(:macos?).and_return(true)
        @file_wrapper.check_path_length(path_of_length(900), origin: 'Test')
        expect(@loginator).not_to have_received(:log)
      end

      it 'falls back to the Linux limit (4096) when neither Windows nor macOS' do
        @file_wrapper.check_path_length(path_of_length(4096), origin: 'Test')
        expect(@loginator).to have_received(:log).with(any_args, Verbosity::ERRORS)
      end
    end
  end

  # #104 -- plain FileList.new(files)/#include treats every entry as a glob pattern to
  # (re-)resolve via Dir.glob, which drops a literal `[`/`]` survivor in an already-
  # concrete filename, and can only ever match files that already exist on disk at all
  # -- wrong for a caller that already has the real, final answer in hand (e.g. an
  # object file this same build is about to create). `<<` bypasses glob interpretation
  # entirely.
  describe '#instantiate_file_list_literal' do
    it 'returns a FileList instance' do
      expect( @file_wrapper.instantiate_file_list_literal( [] ) ).to be_a( Rake::FileList )
    end

    it 'returns an empty FileList for an empty array' do
      expect( @file_wrapper.instantiate_file_list_literal( [] ).to_a ).to eq( [] )
    end

    it 'preserves every entry exactly, including a not-yet-existing path with literal [] brackets' do
      files = ['src/[legacy]/foo.c', 'build/test/out/a_test/[legacy]/foo.o']
      expect( @file_wrapper.instantiate_file_list_literal( files ).to_a ).to eq( files )
    end

    it 'preserves entry order and duplicates as given, with no glob re-resolution' do
      files = ['b.c', 'a.c', 'a.c']
      expect( @file_wrapper.instantiate_file_list_literal( files ).to_a ).to eq( files )
    end
  end
end
