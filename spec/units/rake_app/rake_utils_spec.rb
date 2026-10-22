# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/rake_app/rake_utils'

describe RakeUtils do
  before(:each) do
    @rake_wrapper = double('rake_wrapper')
    @rake_utils = described_class.new({ :rake_wrapper => @rake_wrapper })
  end

  describe '#task_invoked?' do
    it 'returns false when no tasks exist' do
      allow(@rake_wrapper).to receive(:task_list).and_return([])

      expect(@rake_utils.task_invoked?(/^test(:|$)/)).to eq(false)
    end

    it 'returns true for a task that has been invoked and matches the regex' do
      task = double('task', already_invoked: true, to_s: 'test:all')
      allow(@rake_wrapper).to receive(:task_list).and_return([task])

      expect(@rake_utils.task_invoked?(/^test(:|$)/)).to eq(true)
    end

    it 'returns false for a task that matches the regex but has not been invoked' do
      task = double('task', already_invoked: false, to_s: 'test:all')
      allow(@rake_wrapper).to receive(:task_list).and_return([task])

      expect(@rake_utils.task_invoked?(/^test(:|$)/)).to eq(false)
    end

    it 'returns false for a task that has been invoked but does not match the regex' do
      task = double('task', already_invoked: true, to_s: 'release:all')
      allow(@rake_wrapper).to receive(:task_list).and_return([task])

      expect(@rake_utils.task_invoked?(/^test(:|$)/)).to eq(false)
    end

    it 'finds a matching invoked task among several non-matching ones, regardless of position' do
      not_invoked  = double('task', already_invoked: false, to_s: 'test:all')
      wrong_name   = double('task', already_invoked: true, to_s: 'release:all')
      matching     = double('task', already_invoked: true, to_s: 'test:foo')
      allow(@rake_wrapper).to receive(:task_list).and_return([not_invoked, wrong_name, matching])

      expect(@rake_utils.task_invoked?(/^test(:|$)/)).to eq(true)
    end
  end
end
