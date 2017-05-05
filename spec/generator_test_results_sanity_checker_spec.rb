require 'spec_helper'
require 'ceedling/generator_test_results_sanity_checker'
require 'ceedling/constants'
require 'ceedling/streaminator'
require 'ceedling/configurator'

describe GeneratorTestResultsSanityChecker do
  before(:each) do
    # this will always be mocked
    @configurator = Configurator.new({:configurator_setup => nil, :configurator_builder => nil, :configurator_plugins => nil, :cmock_builder => nil, :yaml_wrapper => nil, :system_wrapper => nil})
    @streaminator = Streaminator.new({:streaminator_helper => nil, :verbosinator => nil, :loginator => nil, :stream_wrapper => nil})

    @sanity_checker = described_class.new({:configurator => @configurator, :streaminator => @streaminator})
  
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
      allow(@streaminator).to receive(:stderr_puts)
      expect{@sanity_checker.verify(@results, 3)}.to raise_error(RuntimeError)
    end

    it 'rasies error if basic check fails for failed' do
      @configurator.sanity_checks = TestResultsSanityChecks::NORMAL
      @results[:counts][:failed] = 0
      allow(@configurator).to receive(:extension_executable).and_return('')
      allow(@streaminator).to receive(:stderr_puts)
      expect{@sanity_checker.verify(@results, 3)}.to raise_error(RuntimeError)
    end

    it 'rasies error if basic check fails for total' do
      @configurator.sanity_checks = TestResultsSanityChecks::NORMAL
      @results[:counts][:total] = 0
      allow(@configurator).to receive(:extension_executable).and_return('')
      allow(@streaminator).to receive(:stderr_puts)
      expect{@sanity_checker.verify(@results, 3)}.to raise_error(RuntimeError)
    end

    it 'rasies error if thorough check fails for error code not 255 not equal' do
      @configurator.sanity_checks = TestResultsSanityChecks::THOROUGH
      allow(@configurator).to receive(:extension_executable).and_return('')
      allow(@streaminator).to receive(:stderr_puts)
      expect{@sanity_checker.verify(@results, 2)}.to raise_error(RuntimeError)
    end

    it 'rasies error if thorough check fails for error code 255 less than 255' do
      @configurator.sanity_checks = TestResultsSanityChecks::THOROUGH
      allow(@configurator).to receive(:extension_executable).and_return('')
      allow(@streaminator).to receive(:stderr_puts)
      expect{@sanity_checker.verify(@results, 255)}.to raise_error(RuntimeError)
    end

    it 'returns nil if thorough checks are good' do
      @configurator.sanity_checks = TestResultsSanityChecks::THOROUGH
      expect(@sanity_checker.verify(@results, 3)).to be_nil
    end
  end
end
