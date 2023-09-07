require 'spec_helper'
require 'ceedling/file_finder_helper'
require 'ceedling/constants'
require 'ceedling/streaminator'

FILE_LIST = ['some/dir/a.c', 'some/dir/a.h', \
             'another/place/b.c','another/place/b.h',\
             'here/src/c.cpp', 'here/inc/c.hpp',\
             'copy/SRC/c.cpp', 'copy/inc/c.hpp'].freeze

describe FileFinderHelper do
  before(:each) do
    # this will always be mocked
    @streaminator = Streaminator.new({:streaminator_helper => nil, :verbosinator => nil, :loginator => nil, :stream_wrapper => nil})

    @ff_helper = described_class.new({:streaminator => @streaminator})
  end
  
  
  describe '#find_file_in_collection' do
    it 'returns the full path of the matching file' do
      expect(@ff_helper.find_file_in_collection('a.c', FILE_LIST, :ignore)).to eq(FILE_LIST[0])
      expect(@ff_helper.find_file_in_collection('b.h', FILE_LIST, :ignore)).to eq(FILE_LIST[3])
    end

    it 'handles duplicate files with best match' do
      expect(@ff_helper.find_file_in_collection('c.hpp', FILE_LIST, :ignore)).to eq(FILE_LIST[5])
      expect(@ff_helper.find_file_in_collection('c.hpp', FILE_LIST, :ignore, 'inc/c.hpp')).to eq(FILE_LIST[5])
      expect(@ff_helper.find_file_in_collection('c.hpp', FILE_LIST, :ignore, 'here/inc/c.hpp')).to eq(FILE_LIST[5])
      expect(@ff_helper.find_file_in_collection('c.hpp', FILE_LIST, :ignore, 'copy/inc/c.hpp')).to eq(FILE_LIST[7])

      expect(@ff_helper.find_file_in_collection('c.cpp', FILE_LIST, :ignore)).to eq(FILE_LIST[4])
      expect(@ff_helper.find_file_in_collection('c.cpp', FILE_LIST, :ignore, 'src/c.cpp')).to eq(FILE_LIST[4])
      expect(@ff_helper.find_file_in_collection('c.cpp', FILE_LIST, :ignore, 'SRC/c.cpp')).to eq(FILE_LIST[6])
      expect(@ff_helper.find_file_in_collection('c.cpp', FILE_LIST, :ignore, 'test/src/c.cpp')).to eq(FILE_LIST[4])
      expect(@ff_helper.find_file_in_collection('c.cpp', FILE_LIST, :ignore, 'meh/SRC/c.cpp')).to eq(FILE_LIST[6])
      expect(@ff_helper.find_file_in_collection('c.cpp', FILE_LIST, :ignore, 'c/c.cpp')).to eq(FILE_LIST[4])
      expect(@ff_helper.find_file_in_collection('c.cpp', FILE_LIST, :ignore, 'copy/meh/c.cpp')).to eq(FILE_LIST[6])
      expect(@ff_helper.find_file_in_collection('c.cpp', FILE_LIST, :ignore, 'here/too/and/fro/c.cpp')).to eq(FILE_LIST[4])
    end

    context 'file not found' do
      it 'returns nil' do
        expect(@ff_helper.find_file_in_collection('unknown/d.c', FILE_LIST, :ignore)).to be_nil
      end

      it 'outputs nothing if complain is ignore' do
        @ff_helper.find_file_in_collection('unknown/d.c', FILE_LIST, :ignore)
      end

      it 'outputs a complaint if complain is warn' do
        msg = 'WARNING: Found no file \'d.c\' in search paths.'
        expect(@streaminator).to receive(:stderr_puts).with(msg, Verbosity::COMPLAIN)
        @ff_helper.find_file_in_collection('d.c', FILE_LIST, :warn)
      end

      it 'outputs and raises an error if  complain is error' do
        msg = 'ERROR: Found no file \'d.c\' in search paths.'
        allow(@streaminator).to receive(:stderr_puts).with(msg, Verbosity::ERRORS) do
          expect{@ff_helper.find_file_in_collection('d.c', FILE_LIST, :warn)}.to raise_error
        end
      end
    end

  end
end
