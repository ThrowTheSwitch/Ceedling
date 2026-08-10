# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/file_finder_helper'
require 'ceedling/constants'
require 'ceedling/loginator'

FILE_LIST = ['some/dir/a.c', 'some/dir/a.h', \
             'another/place/b.c','another/place/b.h',\
             'here/src/c.cpp', 'here/inc/c.hpp',\
             'copy/SRC/c.cpp', 'copy/inc/c.hpp'].freeze

describe FileFinderHelper do
  before(:each) do
    # this will always be mocked
    @loginator = Loginator.new({:verbosinator => nil, :file_wrapper => nil, :system_wrapper => nil})

    @ff_helper = described_class.new({:loginator => @loginator})
  end
  
  
  describe '#find_file_in_collection' do
    it 'returns the full path of the matching file' do
      expect(@ff_helper.find_file_in_collection('a.c', FILE_LIST, :ignore)).to eq(FILE_LIST[0])
      expect(@ff_helper.find_file_in_collection('b.h', FILE_LIST, :ignore)).to eq(FILE_LIST[3])
    end

    it 'raises a CeedlingException naming every candidate when a bare basename is ambiguous' do
      expect { @ff_helper.find_file_in_collection('c.hpp', FILE_LIST, :ignore) }.to raise_error(CeedlingException) do |error|
        expect(error.message).to include('here/inc/c.hpp')
        expect(error.message).to include('copy/inc/c.hpp')
      end

      expect { @ff_helper.find_file_in_collection('c.cpp', FILE_LIST, :ignore) }.to raise_error(CeedlingException) do |error|
        expect(error.message).to include('here/src/c.cpp')
        expect(error.message).to include('copy/SRC/c.cpp')
      end
    end

    it 'resolves an ambiguous basename when the query supplies enough path to disambiguate' do
      expect(@ff_helper.find_file_in_collection('here/inc/c.hpp', FILE_LIST, :ignore)).to eq(FILE_LIST[5])
      expect(@ff_helper.find_file_in_collection('copy/inc/c.hpp', FILE_LIST, :ignore)).to eq(FILE_LIST[7])

      expect(@ff_helper.find_file_in_collection('src/c.cpp', FILE_LIST, :ignore)).to eq(FILE_LIST[4])
      expect(@ff_helper.find_file_in_collection('here/src/c.cpp', FILE_LIST, :ignore)).to eq(FILE_LIST[4])
      expect(@ff_helper.find_file_in_collection('SRC/c.cpp', FILE_LIST, :ignore)).to eq(FILE_LIST[6])
      expect(@ff_helper.find_file_in_collection('copy/SRC/c.cpp', FILE_LIST, :ignore)).to eq(FILE_LIST[6])
    end

    context 'file not found' do
      it 'returns nil' do
        expect(@ff_helper.find_file_in_collection('unknown/d.c', FILE_LIST, :ignore)).to be_nil
      end

      it 'outputs nothing if complain is ignore' do
        @ff_helper.find_file_in_collection('unknown/d.c', FILE_LIST, :ignore)
      end

      it 'outputs a complaint if complain is warn' do
        msg = 'Found no file `d.c` in search paths.'
        expect(@loginator).to receive(:log).with(msg, Verbosity::COMPLAIN)
        @ff_helper.find_file_in_collection('d.c', FILE_LIST, :warn)
      end

      it 'outputs and raises an error if  complain is error' do
        msg = 'Found no file `d.c` in search paths.'
        allow(@loginator).to receive(:log).with(msg, Verbosity::ERRORS) do
          expect{@ff_helper.find_file_in_collection('d.c', FILE_LIST, :warn)}.to raise_error
        end
      end
    end

  end
end
