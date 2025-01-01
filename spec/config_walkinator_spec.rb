# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/config_walkinator'

describe ConfigWalkinator do
  before(:each) do
    @cw = described_class.new
  end
 
  describe '#fetch_value' do

    it 'fetches a boolean 1 levels in' do
      config = {:foo => false}
      expect(@cw.fetch_value(:foo, hash:config)).to eq([false, 1])

      config = {:foo => true}
      expect(@cw.fetch_value(:foo, hash:config)).to eq([true, 1])
    end

    it 'fetches a list two levels in' do
      config = {:foo => {:bar => [1, 2, 3]}}

      expect(@cw.fetch_value(:foo, :bar, hash:config)).to eq([[1,2,3], 2])
    end

    it 'fetches a hash 3 levels in' do
      config = {:foo => {:bar => {:baz => {:setting => 5}}}}

      expect(@cw.fetch_value(:foo, :bar, :baz, hash:config)).to eq([{:setting => 5}, 3])
    end

    it 'fetches nothing for nil config hash' do
      expect(@cw.fetch_value(:foo, :bar, :baz, hash:nil)).to eq([nil, 0])
    end

    it 'fetches nothing for a level deeper than exists' do
      config = {:foo => {:bar => 'a'}}

      expect(@cw.fetch_value(:foo, :bar, :oops, hash:config)).to eq([nil, 2])
    end

    it 'fetches nothing if non-symbol provided as key' do
      config = {:foo => {:bar => 'a'}}

      expect(@cw.fetch_value(:foo, :bar, 'a', hash:config)).to eq([nil, 2])
    end

    it 'fetches the provided default value if a key does not exist' do
      config = {:foo => {:bar => {:baz => true}}}

      expect(@cw.fetch_value(:foo, :bar, :oops, hash:config, default:false)).to eq([false, 2])
    end

  end

end
