# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/test_runner_manager'
require 'ceedling/constants'

describe TestRunnerManager do
  let(:manager) { described_class.new }

  describe 'initial state' do
    it 'returns an empty array from #collect_cmdline_args before configuration' do
      expect(manager.collect_cmdline_args).to eq([])
    end

    it 'returns an empty array from #collect_defines before configuration' do
      expect(manager.collect_defines).to eq([])
    end
  end

  describe '#configure_build_options' do
    it 'adds the cmdline-args define when :cmdline_args is truthy' do
      manager.configure_build_options({ test_runner: { cmdline_args: true } })

      expect(manager.collect_defines).to eq([RUNNER_BUILD_CMDLINE_ARGS_DEFINE])
    end

    it 'does not add the define when :cmdline_args is false' do
      manager.configure_build_options({ test_runner: { cmdline_args: false } })

      expect(manager.collect_defines).to eq([])
    end

    it 'returns early, adding nothing, when :cmdline_args is nil' do
      manager.configure_build_options({ test_runner: { cmdline_args: nil } })

      expect(manager.collect_defines).to eq([])
    end
  end

  describe '#configure_runtime_options / #collect_cmdline_args' do
    it 'returns an empty array when both include and exclude test case filters are empty' do
      manager.configure_runtime_options('', '')

      expect(manager.collect_cmdline_args).to eq([])
    end

    it 'returns only the -f flag when only an include filter is given' do
      manager.configure_runtime_options('test_foo', '')

      expect(manager.collect_cmdline_args).to eq(['-f test_foo'])
    end

    it 'returns only the -x flag when only an exclude filter is given' do
      manager.configure_runtime_options('', 'test_bar')

      expect(manager.collect_cmdline_args).to eq(['-x test_bar'])
    end

    it 'returns both flags, include before exclude, when both filters are given' do
      manager.configure_runtime_options('test_foo', 'test_bar')

      expect(manager.collect_cmdline_args).to eq(['-f test_foo', '-x test_bar'])
    end
  end
end
