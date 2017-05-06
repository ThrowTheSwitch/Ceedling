require 'spec_helper'
require 'ceedling/generator_test_results_sanity_checker'
require 'ceedling/generator_test_results'
require 'ceedling/yaml_wrapper'
require 'ceedling/constants'
require 'ceedling/streaminator'
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
    @configurator = Configurator.new({:configurator_setup => nil, :configurator_builder => nil, :configurator_plugins => nil, :cmock_builder => nil, :yaml_wrapper => nil, :system_wrapper => nil})
    @streaminator = Streaminator.new({:streaminator_helper => nil, :verbosinator => nil, :loginator => nil, :stream_wrapper => nil})
    
    # these will always be used as is.
    @yaml_wrapper = YamlWrapper.new
    @sanity_checker = GeneratorTestResultsSanityChecker.new({:configurator => @configurator, :streaminator => @streaminator})
    
    @generate_test_results = described_class.new({:configurator => @configurator, :generator_test_results_sanity_checker => @sanity_checker, :yaml_wrapper => @yaml_wrapper})
  end

  after(:each) do
    if File.exists?(TEST_OUT_FILE)
      File.delete(TEST_OUT_FILE)
    end
  end
  
  describe '#process_and_write_results' do
    it 'handles an empty input' do
      @generate_test_results.process_and_write_results({:output => ''}, TEST_OUT_FILE, 'some/place/test_example.c')
      expect(IO.read(TEST_OUT_FILE)).to eq(IO.read('spec/support/test_example_empty.pass'))
    end

    it 'handles a normal test output' do
      @generate_test_results.process_and_write_results({:output => NORMAL_OUTPUT}, TEST_OUT_FILE, 'some/place/test_example.c')
      expect(IO.read(TEST_OUT_FILE)).to eq(IO.read('spec/support/test_example.pass'))
    end

    it 'handles a normal test output with ignores' do
      @generate_test_results.process_and_write_results({:output => IGNORE_OUTPUT}, TEST_OUT_FILE, 'some/place/test_example.c')
      expect(IO.read(TEST_OUT_FILE)).to eq(IO.read('spec/support/test_example_ignore.pass'))
    end

    it 'handles a normal test output with failures' do
      allow(@configurator).to receive(:extension_testfail).and_return('.fail')
      @generate_test_results.process_and_write_results({:output => FAIL_OUTPUT}, TEST_OUT_FILE, 'some/place/test_example.c')
      expect(IO.read(TEST_OUT_FILE_FAIL)).to eq(IO.read('spec/support/test_example.fail'))
    end

    it 'handles a mangled test output as gracefully as it can' do
      @generate_test_results.process_and_write_results({:output => MANGLED_OUTPUT}, TEST_OUT_FILE, 'some/place/test_example.c')
      expect(IO.read(TEST_OUT_FILE)).to eq(IO.read('spec/support/test_example_mangled.pass'))
    end

  end
end
