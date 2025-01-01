# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/generator_test_results_sanity_checker'
require 'ceedling/constants'
require 'ceedling/loginator'
require 'ceedling/configurator'

describe GeneratorTestResultsSanityChecker do
  before(:each) do
    # These will always be mocked
    @loginator = Loginator.new({:verbosinator => nil, :file_wrapper => nil, :system_wrapper => nil})
    @configurator = Configurator.new({
      :configurator_setup => nil,
      :configurator_builder => nil,
      :configurator_plugins => nil,
      :config_walkinator => nil,
      :yaml_wrapper => nil,
      :system_wrapper => nil,
      :loginator => @loginator,
      :reportinator => nil
    })

    @sanity_checker = described_class.new({:configurator => @configurator, :loginator => @loginator})
  
    @results = {}
    @results[:ignores] = ['', '', '']
    @results[:failures] = ['', '', '']
    @results[:successes] = ['', '', '']
    @results[:source] = {:file => "test_file.c"}
    @results[:counts] = {:ignored => @results[:ignores].size, :failed => @results[:failures].size, :total => 9}
  end
  
  
  describe '#verify' do
    it 'returns immediately if sanity_checker set to NONE' do
      @configurator.sanity_checks = TestResultsSanityChecks::NONE
      expect(@sanity_checker.verify(nil, 255)).to be_nil
    end

    it 'rasies error if results are nil' do
      @configurator.sanity_checks = TestResultsSanityChecks::NORMAL
      expect{@sanity_checker.verify(nil, 3)}.to raise_error(RuntimeError)
    end

    it 'rasies error if results are empty' do
      @configurator.sanity_checks = TestResultsSanityChecks::NORMAL
      expect{@sanity_checker.verify({}, 3)}.to raise_error(RuntimeError)
    end

    it 'returns nil if basic checks are good' do
      @configurator.sanity_checks = TestResultsSanityChecks::NORMAL
      expect(@sanity_checker.verify(@results, 3)).to be_nil
    end

    it 'rasies error if basic check fails for ignore' do
      @configurator.sanity_checks = TestResultsSanityChecks::NORMAL
      @results[:counts][:ignored] = 0
      allow(@configurator).to receive(:extension_executable).and_return('')
      allow(@loginator).to receive(:log)
      expect{@sanity_checker.verify(@results, 3)}.to raise_error(RuntimeError)
    end

    it 'rasies error if basic check fails for failed' do
      @configurator.sanity_checks = TestResultsSanityChecks::NORMAL
      @results[:counts][:failed] = 0
      allow(@configurator).to receive(:extension_executable).and_return('')
      allow(@loginator).to receive(:log)
      expect{@sanity_checker.verify(@results, 3)}.to raise_error(RuntimeError)
    end

    it 'rasies error if basic check fails for total' do
      @configurator.sanity_checks = TestResultsSanityChecks::NORMAL
      @results[:counts][:total] = 0
      allow(@configurator).to receive(:extension_executable).and_return('')
      allow(@loginator).to receive(:log)
      expect{@sanity_checker.verify(@results, 3)}.to raise_error(RuntimeError)
    end

    it 'rasies error if thorough check fails for error code not 255 not equal' do
      @configurator.sanity_checks = TestResultsSanityChecks::THOROUGH
      allow(@configurator).to receive(:extension_executable).and_return('')
      allow(@loginator).to receive(:log)
      expect{@sanity_checker.verify(@results, 2)}.to raise_error(RuntimeError)
    end

    it 'rasies error if thorough check fails for error code 255 less than 255' do
      @configurator.sanity_checks = TestResultsSanityChecks::THOROUGH
      allow(@configurator).to receive(:extension_executable).and_return('')
      allow(@loginator).to receive(:log)
      expect{@sanity_checker.verify(@results, 255)}.to raise_error(RuntimeError)
    end

    it 'returns nil if thorough checks are good' do
      @configurator.sanity_checks = TestResultsSanityChecks::THOROUGH
      expect(@sanity_checker.verify(@results, 3)).to be_nil
    end
  end
end
