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
    @ok_status = double('status', termsig: nil, signaled?: false, exitstatus: 0, success?: true)
  end


  # ---------------------------------------------------------------------------
  # Helper: build a shell_result hash
  # ---------------------------------------------------------------------------
  # `success` left unspecified derives from `termsig`/`exitstatus` the way a real
  # Process::Status would -- signaled or nonzero-exit is never success. Callers that
  # need an inconsistent combination (a status that looks successful despite a nonzero
  # exit, exercised nowhere here) can still pass `success:` explicitly.
  def shell_result(output: VALID_STATS_OUTPUT, stderr: '', termsig: nil, exitstatus: 0, success: nil)
    success = (termsig.nil? && exitstatus == 0) if success.nil?
    status = double(
      'status', termsig: termsig, signaled?: !termsig.nil?, exitstatus: exitstatus, success?: success
    )
    { :output => output, :stderr => stderr, :status => status }
  end


  describe '#test_crash?' do

    context 'signal death (any signal, not just SIGSEGV)' do
      it 'returns true when the process was terminated by signal 11 (SIGSEGV)' do
        result = shell_result(termsig: 11)
        expect( @helper.test_crash?('test_foo.c', 'test_foo.out', result) ).to be true
      end

      it 'returns true when the process was terminated by signal 6 (SIGABRT) -- e.g. UBSan/ASan halt_on_error' do
        result = shell_result(termsig: 6)
        # output still has stats, stderr is empty → only the signal check matters here
        expect( @helper.test_crash?('test_foo.c', 'test_foo.out', result) ).to be true
      end
    end

    context 'a clean summary contradicted by the real exit status' do
      it 'returns true when 0 failures are reported but the real process exited nonzero and unsignaled' do
        # e.g. LeakSanitizer detecting a leak during teardown, after every test case
        # already printed and Unity's own summary already looked clean.
        result = shell_result(output: VALID_STATS_OUTPUT, exitstatus: 1, success: false)
        expect( @helper.test_crash?('test_foo.c', 'test_foo.out', result) ).to be true
      end

      it 'returns false when a nonzero real exit is consistent with Unity reporting real failures' do
        failing_output = "\n---------\n2 Tests 1 Failures 0 Ignored\nFAIL\n"
        result = shell_result(output: failing_output, exitstatus: 1, success: false)
        expect( @helper.test_crash?('test_foo.c', 'test_foo.out', result) ).to be false
      end

      it 'returns false when 0 failures are reported and the real process exited successfully' do
        result = shell_result(output: VALID_STATS_OUTPUT, exitstatus: 0, success: true)
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


  describe '#explain_possible_mock_partial_collision' do
    let(:mocked_headers) { { 'gpio.h' => '/project/library/gpio.h' } }

    it 'returns nil for output with no redeclaration-family error at all' do
      output = "/project/library/gpio.h:12:8: error: some unrelated compiler error\n"
      expect( @helper.explain_possible_mock_partial_collision( output: output, mocked_headers: mocked_headers ) ).to be_nil
    end

    it 'returns nil for nil output' do
      expect( @helper.explain_possible_mock_partial_collision( output: nil, mocked_headers: mocked_headers ) ).to be_nil
    end

    it 'returns nil when a redeclaration error matches but names no header this test mocks or Partializes' do
      output = "/project/library/other.h:10:5: error: redeclaration of 'struct other'\n"
      expect( @helper.explain_possible_mock_partial_collision( output: output, mocked_headers: mocked_headers ) ).to be_nil
    end

    it 'returns a notice naming the mocked header and its real path when a redeclaration error mentions it' do
      output = "/project/library/gpio.h:12:8: error: redeclaration of 'struct gpio'\n"
      notice = @helper.explain_possible_mock_partial_collision( output: output, mocked_headers: mocked_headers )

      expect( notice ).to_not be_nil
      expect( notice ).to include( 'gpio.h' )
      expect( notice ).to include( '/project/library/gpio.h' )
    end

    it 'matches a "conflicting types for" error the same way' do
      output = "/project/library/gpio.h:12:8: error: conflicting types for 'gpio_init'\n"
      expect( @helper.explain_possible_mock_partial_collision( output: output, mocked_headers: mocked_headers ) ).to_not be_nil
    end

    it 'matches a "previous definition of" error the same way' do
      output = "/project/library/gpio.h:12:8: note: previous definition of 'gpio_init' was here\n"
      expect( @helper.explain_possible_mock_partial_collision( output: output, mocked_headers: mocked_headers ) ).to_not be_nil
    end

    it 'does not match a header of the same basename resolving to a different real path' do
      output = "/some/other/place/gpio.h:12:8: error: redeclaration of 'struct gpio'\n"
      expect( @helper.explain_possible_mock_partial_collision( output: output, mocked_headers: mocked_headers ) ).to be_nil
    end
  end

end
