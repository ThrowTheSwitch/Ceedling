# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'ceedling/generators/generator_test_results_sanity_checker'
require 'ceedling/generators/generator_test_results'
require 'ceedling/yaml_wrapper'
require 'ceedling/constants'
require 'ceedling/config/configurator'

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

TIMED_OUTPUT =
  "test_example.c:257:test_one:PASS (1.5 ms)\n" +
  "test_example.c:269:test_two:PASS (0.3 ms)\n" +
  "\n" +
  "-----------------------\n" +
  "2 Tests 0 Failures 0 Ignored \n" +
  "OK\n".freeze

MIXED_OUTPUT =
  "test_example.c:257:test_one:PASS\n" +
  "test_example.c:269:test_two:FAIL: Expected 2 Was 3\n" +
  "test_example.c:281:test_three:IGNORE\n" +
  "test_example.c:293:test_four:PASS\n" +
  "\n" +
  "-----------------------\n" +
  "4 Tests 1 Failures 1 Ignored \n" +
  "FAIL\n".freeze

# Simulates Unity built with UNITY_OUTPUT_COLOR.
# ANSI escape codes wrap individual status tokens and the summary result token.
COLOR_NORMAL_OUTPUT =
  "Verbose output one\n" +
  "Verbous output two\n" +
  "test_example.c:257:test_one:\e[0;32mPASS\e[0m\n" +
  "test_example.c:269:test_two:\e[0;32mPASS\e[0m\n" +
  "\n" +
  "-----------------------\n" +
  "2 Tests 0 Failures 0 Ignored \n" +
  "\e[0;32mOK\e[0m\n".freeze

COLOR_IGNORE_OUTPUT =
  "Verbose output one\n" +
  "Verbous output two\n" +
  "test_example.c:257:test_one:\e[0;33mIGNORE\e[0m\n" +
  "test_example.c:269:test_two:\e[0;33mIGNORE\e[0m\n" +
  "\n" +
  "-----------------------\n" +
  "2 Tests 0 Failures 2 Ignored \n" +
  "\e[0;32mOK\e[0m\n".freeze

COLOR_FAIL_OUTPUT =
  "Verbose output one\n" +
  "Verbous output two\n" +
  "test_example.c:257:test_one:\e[0;31mFAIL\e[0m\n" +
  "test_example.c:269:test_two:\e[0;31mFAIL\e[0m\n" +
  "\n" +
  "-----------------------\n" +
  "2 Tests 2 Failures 0 Ignored \n" +
  "\e[0;31mFAIL\e[0m\n".freeze

# UNITY_OUTPUT_COLOR + UNITY_INCLUDE_EXEC_TIME together
COLOR_TIMED_OUTPUT =
  "test_example.c:257:test_one:\e[0;32mPASS\e[0m (1.5 ms)\n" +
  "test_example.c:269:test_two:\e[0;32mPASS\e[0m (0.3 ms)\n" +
  "\n" +
  "-----------------------\n" +
  "2 Tests 0 Failures 0 Ignored \n" +
  "\e[0;32mOK\e[0m\n".freeze

TEST_OUT_FILE = 'out.pass'
TEST_OUT_FILE_FAIL = 'out.fail'


describe GeneratorTestResults do
  before(:each) do
    # Stub logging dependencies — all log/progress calls are silently ignored in tests
    @loginator = double('loginator')
    allow(@loginator).to receive(:log)

    @reportinator = double('reportinator')
    allow(@reportinator).to receive(:generate_progress).and_return('')

    @configurator = Configurator.new({
      :configurator_setup   => nil,
      :configurator_builder => nil,
      :configurator_plugins => nil,
      :config_walkinator    => nil,
      :yaml_wrapper         => nil,
      :system_wrapper       => nil,
      :loginator            => @loginator,
      :reportinator         => @reportinator,
      :ruby_expandinator    => nil
    })

    @yaml_wrapper = YamlWrapper.new
    @sanity_checker = GeneratorTestResultsSanityChecker.new({
      :configurator => @configurator,
      :loginator    => @loginator
    })

    @generate_test_results = described_class.new({
      :configurator                          => @configurator,
      :generator_test_results_sanity_checker => @sanity_checker,
      :loginator                             => @loginator,
      :reportinator                          => @reportinator,
      :yaml_wrapper                          => @yaml_wrapper
    })

    @tmpdir = Dir.mktmpdir
    @tmp_out_file = File.join(@tmpdir, TEST_OUT_FILE)
    @tmp_out_file_fail = File.join(@tmpdir, TEST_OUT_FILE_FAIL)
  end

  after(:each) do
    FileUtils.rm_rf(@tmpdir)
  end

  describe '#process_and_write_results' do
    it 'raises on an empty input' do
      expect{
        @generate_test_results.process_and_write_results(
          { :executable => 'test_example.out',
            :output => '',
            :result_file => @tmp_out_file,
            :test_file => 'some/place/test_example.c'
          }
        )
      }.to raise_error( /Could not parse/i )
    end

    it 'raises on mangled test output' do
      expect{
        @generate_test_results.process_and_write_results(
          { :executable => 'test_example.out',
            :output => MANGLED_OUTPUT,
            :result_file => @tmp_out_file,
            :test_file => 'some/place/test_example.c'
          }
        )
      }.to raise_error( /Could not parse/i )
    end

    it 'handles a normal test output' do
      @generate_test_results.process_and_write_results(
        { :executable => 'test_example.out',
          :output => NORMAL_OUTPUT,
          :result_file => @tmp_out_file,
          :test_file => 'some/place/test_example.c'
        }
      )
      expect(IO.read(@tmp_out_file)).to eq(IO.read('spec/support/test_example.pass'))
    end

    it 'returns :results key containing parsed counts' do
      result = @generate_test_results.process_and_write_results(
        { :executable => 'test_example.out',
          :output => NORMAL_OUTPUT,
          :result_file => @tmp_out_file,
          :test_file => 'some/place/test_example.c'
        }
      )
      expect(result).to have_key(:results)
      expect(result[:results][:counts]).to include(:failed => 0)
    end

    it 'handles a normal test output with time' do
      @generate_test_results.process_and_write_results(
        { :executable => 'test_example.out',
          :output => NORMAL_OUTPUT,
          :time => 0.01234,
          :result_file => @tmp_out_file,
          :test_file => 'some/place/test_example.c'
        }
      )
      expect(IO.read(@tmp_out_file)).to eq(IO.read('spec/support/test_example_with_time.pass'))
    end

    it 'handles a normal test output with ignores' do
      @generate_test_results.process_and_write_results(
        { :executable => 'test_example.out',
          :output => IGNORE_OUTPUT,
          :result_file => @tmp_out_file,
          :test_file => 'some/place/test_example.c'
        }
      )
      expect(IO.read(@tmp_out_file)).to eq(IO.read('spec/support/test_example_ignore.pass'))
    end

    it 'handles a normal test output with failures' do
      allow(@configurator).to receive(:extension_testfail).and_return('.fail')
      @generate_test_results.process_and_write_results(
        { :executable => 'test_example.out',
          :output => FAIL_OUTPUT,
          :result_file => @tmp_out_file,
          :test_file => 'some/place/test_example.c'
        }
      )
      expect(IO.read(@tmp_out_file_fail)).to eq(IO.read('spec/support/test_example.fail'))
    end

    it 'handles color (ANSI) test output for passing tests' do
      @generate_test_results.process_and_write_results(
        { :executable => 'test_example.out',
          :output => COLOR_NORMAL_OUTPUT,
          :result_file => @tmp_out_file,
          :test_file => 'some/place/test_example.c'
        }
      )
      expect(IO.read(@tmp_out_file)).to eq(IO.read('spec/support/test_example.pass'))
    end

    it 'handles color (ANSI) test output for ignored tests' do
      @generate_test_results.process_and_write_results(
        { :executable => 'test_example.out',
          :output => COLOR_IGNORE_OUTPUT,
          :result_file => @tmp_out_file,
          :test_file => 'some/place/test_example.c'
        }
      )
      expect(IO.read(@tmp_out_file)).to eq(IO.read('spec/support/test_example_ignore.pass'))
    end

    it 'handles color (ANSI) test output for failing tests' do
      allow(@configurator).to receive(:extension_testfail).and_return('.fail')
      @generate_test_results.process_and_write_results(
        { :executable => 'test_example.out',
          :output => COLOR_FAIL_OUTPUT,
          :result_file => @tmp_out_file,
          :test_file => 'some/place/test_example.c'
        }
      )
      expect(IO.read(@tmp_out_file_fail)).to eq(IO.read('spec/support/test_example.fail'))
    end

    it 'handles color (ANSI) output combined with per-test timing' do
      @generate_test_results.process_and_write_results(
        { :executable => 'test_example.out',
          :output => COLOR_TIMED_OUTPUT,
          :result_file => @tmp_out_file,
          :test_file => 'some/place/test_example.c'
        }
      )
      result = YAML.load(IO.read(@tmp_out_file))
      expect(result[:counts][:passed]).to eq(2)
      expect(result[:successes][0][:unity_test_time]).to be_within(0.001).of(0.0015)
      expect(result[:successes][1][:unity_test_time]).to be_within(0.001).of(0.0003)
    end

    it 'extracts per-test timing when UNITY_INCLUDE_EXEC_TIME is enabled' do
      @generate_test_results.process_and_write_results(
        { :executable => 'test_example.out',
          :output => TIMED_OUTPUT,
          :result_file => @tmp_out_file,
          :test_file => 'some/place/test_example.c'
        }
      )
      result = YAML.load(IO.read(@tmp_out_file))
      expect(result[:counts][:passed]).to eq(2)
      expect(result[:successes][0][:unity_test_time]).to be_within(0.0001).of(0.0015)
      expect(result[:successes][1][:unity_test_time]).to be_within(0.0001).of(0.0003)
    end

    it 'separates passes, failures, and ignores from a mixed-result run' do
      allow(@configurator).to receive(:extension_testfail).and_return('.fail')
      @generate_test_results.process_and_write_results(
        { :executable => 'test_example.out',
          :output => MIXED_OUTPUT,
          :result_file => @tmp_out_file,
          :test_file => 'some/place/test_example.c'
        }
      )
      result = YAML.load(IO.read(@tmp_out_file_fail))
      expect(result[:counts]).to eq({ :total => 4, :passed => 2, :failed => 1, :ignored => 1 })
      expect(result[:successes].map { |s| s[:test] }).to eq(['test_one', 'test_four'])
      expect(result[:failures][0][:test]).to eq('test_two')
      expect(result[:failures][0][:message]).to eq('Expected 2 Was 3')
      expect(result[:ignores][0][:test]).to eq('test_three')
    end
  end

  describe '#filter_test_cases' do
    let(:test_cases) do
      [
        { :test => 'test_init',          :line_number => 10 },
        { :test => 'test_process_valid', :line_number => 20 },
        { :test => 'test_process_error', :line_number => 30 },
        { :test => 'test_shutdown',      :line_number => 40 }
      ]
    end

    it 'returns all cases when no filter is set' do
      allow(@configurator).to receive(:include_test_case).and_return('')
      allow(@configurator).to receive(:exclude_test_case).and_return('')
      expect(@generate_test_results.filter_test_cases(test_cases)).to eq(test_cases)
    end

    it 'keeps only cases matching --test_case substring' do
      allow(@configurator).to receive(:include_test_case).and_return('process')
      allow(@configurator).to receive(:exclude_test_case).and_return('')
      result = @generate_test_results.filter_test_cases(test_cases)
      expect(result.map { |tc| tc[:test] }).to eq(['test_process_valid', 'test_process_error'])
    end

    it 'keeps only the exact case when --test_case is a full name' do
      allow(@configurator).to receive(:include_test_case).and_return('test_init')
      allow(@configurator).to receive(:exclude_test_case).and_return('')
      result = @generate_test_results.filter_test_cases(test_cases)
      expect(result.map { |tc| tc[:test] }).to eq(['test_init'])
    end

    it 'removes cases matching --exclude_test_case substring' do
      allow(@configurator).to receive(:include_test_case).and_return('')
      allow(@configurator).to receive(:exclude_test_case).and_return('process')
      result = @generate_test_results.filter_test_cases(test_cases)
      expect(result.map { |tc| tc[:test] }).to eq(['test_init', 'test_shutdown'])
    end

    it 'does not modify the original array' do
      allow(@configurator).to receive(:include_test_case).and_return('test_init')
      allow(@configurator).to receive(:exclude_test_case).and_return('')
      original = test_cases.dup
      @generate_test_results.filter_test_cases(test_cases)
      expect(test_cases).to eq(original)
    end

    it 'returns empty array when include filter matches nothing' do
      allow(@configurator).to receive(:include_test_case).and_return('test_nonexistent')
      allow(@configurator).to receive(:exclude_test_case).and_return('')
      expect(@generate_test_results.filter_test_cases(test_cases)).to be_empty
    end

    it 'applies include then exclude when both filters are set' do
      allow(@configurator).to receive(:include_test_case).and_return('process')
      allow(@configurator).to receive(:exclude_test_case).and_return('error')
      result = @generate_test_results.filter_test_cases(test_cases)
      expect(result.map { |tc| tc[:test] }).to eq(['test_process_valid'])
    end

    it 'supports regex syntax in --test_case for intentional pattern matching' do
      # Users may intentionally provide regex syntax to match multiple cases at once.
      # e.g. 'process_(valid|error)' selects both process variants.
      allow(@configurator).to receive(:include_test_case).and_return('process_(valid|error)')
      allow(@configurator).to receive(:exclude_test_case).and_return('')
      result = @generate_test_results.filter_test_cases(test_cases)
      expect(result.map { |tc| tc[:test] }).to eq(['test_process_valid', 'test_process_error'])
    end

    it 'raises CeedlingException when --test_case contains an invalid regex' do
      # An invalid regex raises RegexpError at match time; the fix wraps this in a
      # CeedlingException with a descriptive message.
      allow(@configurator).to receive(:include_test_case).and_return('(*invalid')
      allow(@configurator).to receive(:exclude_test_case).and_return('')
      expect { @generate_test_results.filter_test_cases(test_cases) }
        .to raise_error(CeedlingException, /Invalid --test_case regex/)
    end

    it 'raises CeedlingException when --exclude_test_case contains an invalid regex' do
      allow(@configurator).to receive(:include_test_case).and_return('')
      allow(@configurator).to receive(:exclude_test_case).and_return('(*invalid')
      expect { @generate_test_results.filter_test_cases(test_cases) }
        .to raise_error(CeedlingException, /Invalid --exclude_test_case regex/)
    end
  end
end
