# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/generator_test_results_sanity_checker'
require 'ceedling/generator_test_results'
require 'ceedling/yaml_wrapper'
require 'ceedling/constants'
require 'ceedling/loginator'
require 'ceedling/configurator'

NORMAL_OUTPUT =
  "Verbose output one\n" +
  "Verbous output two\n" +
  "test_example.c:257:test_one:PASS\n" +
  "test_example.c:269:test_two:PASS\n" +
  "\n" +
  "-----------------------\n" +
  "2 Tests 0 Failures 0 Ignored \n" +
  "OK\n".freeze

IGNORE_OUTPUT =
  "Verbose output one\n" +
  "Verbous output two\n" +
  "test_example.c:257:test_one:IGNORE\n" +
  "test_example.c:269:test_two:IGNORE\n" +
  "\n" +
  "-----------------------\n" +
  "2 Tests 0 Failures 2 Ignored \n" +
  "OK\n".freeze


FAIL_OUTPUT =
  "Verbose output one\n" +
  "Verbous output two\n" +
  "test_example.c:257:test_one:FAIL\n" +
  "test_example.c:269:test_two:FAIL\n" +
  "\n" +
  "-----------------------\n" +
  "2 Tests 2 Failures 0 Ignored \n" +
  "OK\n".freeze


MANGLED_OUTPUT =
  "Verbose output one\n" +
  "test_example.c:257:test_one:PASS\n" +
  "test_example.c:269:test_tVerbous output two\n" +
  "wo:PASS\n" +
  "\n" +
  "-----------------------\n" +
  "2 Tests 0 Failures 0 Ignored \n" +
  "OK\n".freeze

TEST_OUT_FILE = 'out.pass'
TEST_OUT_FILE_FAIL = 'out.fail'


describe GeneratorTestResults do
  before(:each) do
    # these will always be mocked
    # this will always be mocked
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
    
    # these will always be used as is.
    @yaml_wrapper = YamlWrapper.new
    @sanity_checker = GeneratorTestResultsSanityChecker.new({:configurator => @configurator, :loginator => @loginator})

    @generate_test_results = described_class.new(
      {
        :configurator => @configurator,
        :generator_test_results_sanity_checker => @sanity_checker,
        :yaml_wrapper => @yaml_wrapper
      }
    )
  end

  after(:each) do
    if File.exist?(TEST_OUT_FILE)
      File.delete(TEST_OUT_FILE)
    end
  end
  
  describe '#process_and_write_results' do
    it 'raises on an empty input' do
      expect{ 
        @generate_test_results.process_and_write_results('test_example.out', {:output => ''}, TEST_OUT_FILE, 'some/place/test_example.c')
      }.to raise_error( /Could not parse/i )
    end

    it 'raises on mangled test output' do
      expect{ 
        @generate_test_results.process_and_write_results('test_example.out', {:output => MANGLED_OUTPUT}, TEST_OUT_FILE, 'some/place/test_example.c')
      }.to raise_error( /Could not parse/i )
    end

    it 'handles a normal test output' do
      @generate_test_results.process_and_write_results('test_example.out', {:output => NORMAL_OUTPUT}, TEST_OUT_FILE, 'some/place/test_example.c')
      expect(IO.read(TEST_OUT_FILE)).to eq(IO.read('spec/support/test_example.pass'))
    end

    it 'handles a normal test output with time' do
      @generate_test_results.process_and_write_results('test_example.out', {:output => NORMAL_OUTPUT, :time => 0.01234}, TEST_OUT_FILE, 'some/place/test_example.c')
      expect(IO.read(TEST_OUT_FILE)).to eq(IO.read('spec/support/test_example_with_time.pass'))
    end

    it 'handles a normal test output with ignores' do
      @generate_test_results.process_and_write_results('test_example.out', {:output => IGNORE_OUTPUT}, TEST_OUT_FILE, 'some/place/test_example.c')
      expect(IO.read(TEST_OUT_FILE)).to eq(IO.read('spec/support/test_example_ignore.pass'))
    end

    it 'handles a normal test output with failures' do
      allow(@configurator).to receive(:extension_testfail).and_return('.fail')
      @generate_test_results.process_and_write_results('test_example.out', {:output => FAIL_OUTPUT}, TEST_OUT_FILE, 'some/place/test_example.c')
      expect(IO.read(TEST_OUT_FILE_FAIL)).to eq(IO.read('spec/support/test_example.fail'))
    end
  end
end
