# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/constants'
require 'ceedling/exceptions'
require 'ceedling/generators/generator_helper'

# Minimal Unity test-statistics footer that satisfies PATTERNS::TEST_STDOUT_STATISTICS.
VALID_STATS_OUTPUT = "\n---------\n2 Tests 0 Failures 0 Ignored\nOK\n"

describe GeneratorHelper do

  before(:each) do
    @loginator = double('loginator').as_null_object

    @helper = described_class.new({ :loginator => @loginator })

    # A minimal status double for shell_result[:status].
    @ok_status = double('status', termsig: nil)
  end


  # ---------------------------------------------------------------------------
  # Helper: build a shell_result hash
  # ---------------------------------------------------------------------------
  def shell_result(output: VALID_STATS_OUTPUT, stderr: '', termsig: nil)
    status = double('status', termsig: termsig)
    { :output => output, :stderr => stderr, :status => status }
  end


  describe '#test_crash?' do

    context 'SIGSEGV detection (termsig == 11)' do
      it 'returns true when the process was terminated by signal 11' do
        result = shell_result(termsig: 11)
        expect( @helper.test_crash?('test_foo.c', 'test_foo.out', result) ).to be true
      end

      it 'does not flag SIGSEGV for other signal numbers' do
        result = shell_result(termsig: 6)   # SIGABRT
        # output still has stats, stderr is empty → only the signal check matters here
        expect( @helper.test_crash?('test_foo.c', 'test_foo.out', result) ).to be false
      end
    end


    context 'missing Unity test statistics in output' do
      it 'returns true when output contains no test-result footer' do
        result = shell_result(output: "some partial output with no stats\n")
        expect( @helper.test_crash?('test_foo.c', 'test_foo.out', result) ).to be true
      end

      it 'returns false when output contains a valid Unity statistics footer' do
        result = shell_result(output: VALID_STATS_OUTPUT)
        expect( @helper.test_crash?('test_foo.c', 'test_foo.out', result) ).to be false
      end
    end


    context 'segfault detection in STDERR' do
      it 'returns true when stderr reports a segfault unrelated to the test file' do
        # The segfault line does not begin with the test filename → flagged as a crash.
        result = shell_result(stderr: "Segmentation fault (core dumped)\n")
        expect( @helper.test_crash?('test_foo.c', 'test_foo.out', result) ).to be true
      end

      it 'returns true for case-insensitive segfault variants' do
        result = shell_result(stderr: "SEGMENTATION FAULT at 0xDEADBEEF\n")
        expect( @helper.test_crash?('test_foo.c', 'test_foo.out', result) ).to be true
      end

      it 'returns false when stderr is empty' do
        result = shell_result(stderr: '')
        expect( @helper.test_crash?('test_foo.c', 'test_foo.out', result) ).to be false
      end

      it 'returns false when stderr contains a segfault line attributed to the test file' do
        # Unity reports test-case failures that mention the source file by name.
        # A line starting with the test filename is a handled test failure, not a crash.
        # The negative lookahead in the regex must suppress the crash flag in this case.
        stderr = "test_foo.c:10:test_segv_case:FAIL: Segmentation fault\n"
        result = shell_result(stderr: stderr)
        expect( @helper.test_crash?('test_foo.c', 'test_foo.out', result) ).to be false
      end

      it 'returns true when stderr has both an attributed failure line and a bare segfault line' do
        # If there is a bare OS-level segfault *in addition to* a Unity-attributed line,
        # the crash is real and should be flagged.
        stderr = "test_foo.c:10:test_segv_case:FAIL: assertion failed\n" \
                 "Segmentation fault (core dumped)\n"
        result = shell_result(stderr: stderr)
        expect( @helper.test_crash?('test_foo.c', 'test_foo.out', result) ).to be true
      end
    end


    context 'clean execution' do
      it 'returns false for fully passing output with no stderr' do
        result = shell_result(output: VALID_STATS_OUTPUT, stderr: '')
        expect( @helper.test_crash?('test_foo.c', 'test_foo.out', result) ).to be false
      end
    end

  end

end
