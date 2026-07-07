# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/generators/generator_test_results_backtrace'
require 'ceedling/constants'

# ── Representative gdb output constants ──────────────────────────────────────

# From issue #1038: assert(0) crash → SIGABRT with glibc assertion message
GDB_SIGABRT_ASSERT_OUTPUT = <<~GDB.freeze
  [Thread debugging using libthread_db enabled]
  Using host libthread_db library "/lib/x86_64-linux-gnu/libthread_db.so.1".
  test_lib.out: src/lib.c:5: asserting: Assertion `0' failed.

  Program received signal SIGABRT, Aborted.
  __GI_raise (sig=sig@entry=6) at ../sysdeps/unix/sysv/linux/raise.c:50
  50	../sysdeps/unix/sysv/linux/raise.c: No such file or directory.
  #0  __GI_raise (sig=sig@entry=6) at ../sysdeps/unix/sysv/linux/raise.c:50
  #1  0x00007f8b2c3a7d22 in __GI_abort () at abort.c:79
  #2  0x00007f8b2c3a7c96 in __assert_fail_base.cold () at assert.c:92
  #3  0x00007f8b2c3b6f66 in __GI___assert_fail () at assert.c:101
  #4  0x0000555555555175 in asserting () at src/lib.c:5
  #5  0x000055555555519d in test_asserting () at test/test_lib.c:9
  #6  0x0000555555555350 in run_test (func=0x55555555518a <test_asserting>, name=0x555555556004 "test_asserting", line_num=8) at build/test/runners/test_lib_runner.c:76
GDB

# Classic SIGSEGV from null pointer dereference
GDB_SIGSEGV_OUTPUT = <<~GDB.freeze
  [Thread debugging using libthread_db enabled]
  Using host libthread_db library "/lib/x86_64-linux-gnu/libthread_db.so.1".

  Program received signal SIGSEGV, Segmentation fault.
  0x00005618066ea1fb in testCrash () at test/TestUsartModel.c:40
  40	uint32_t i = *null_ptr;
  #0  0x00005618066ea1fb in testCrash () at test/TestUsartModel.c:40
  #1  0x00005618066eb4de in run_test (func=0x5618066ea1e7 <testCrash>, name=0x5618066eb2e0 "testCrash", line_num=37) at build/test/runners/TestUsartModel_runner.c:76
GDB

# SIGBUS: bus error (alignment or bad address) — no source line in gdb output
GDB_SIGBUS_OUTPUT = <<~GDB.freeze

  Program received signal SIGBUS, Bus error.
  0x0000555555555190 in testBusError () at test/test_widget.c:22
  #0  0x0000555555555190 in testBusError () at test/test_widget.c:22
  #1  run_test () at build/test/runners/test_widget_runner.c:76
GDB

# All frames unresolved — no debug symbols
GDB_UNSYMBOLIZED_OUTPUT = <<~GDB.freeze
  [Thread debugging using libthread_db enabled]

  Program received signal SIGSEGV, Segmentation fault.
  #0  ?? ()
  #1  ?? ()
GDB

# No recognizable crash signal — gdb produced no useful output
GDB_NO_SIGNAL_OUTPUT = <<~GDB.freeze
  [Thread debugging using libthread_db enabled]
  Inferior 1 (process 12345) exited with code 0139.
GDB

# Windows SIGSEGV — Thread N prefix, space-padded source line, DLL frames
# Single-quoted heredoc: backslashes in Windows paths are literal, not escape sequences
GDB_WINDOWS_SIGSEGV_OUTPUT = <<~'GDB'.freeze
  Thread 2 received signal SIGSEGV, Segmentation fault.
  [Switching to Thread 8412.0x21c8]
  0x00007ff62b14115d in testCrash () at test/TestUsartModel.c:40
  40         uint32_t i = *null_ptr;

  #0  0x00007ff62b14115d in testCrash () at test/TestUsartModel.c:40
  #1  0x00007ff62b1418fa in run_test (func=0x7ff62b141xxx <testCrash>, name=0x7ff62b147000 "testCrash", line_num=37) at build/test/runners/TestUsartModel_runner.c:76
  #2  0x00007ff8b49e7034 in KERNEL32!BaseThreadInitThunk () from C:\Windows\System32\kernel32.dll
  #3  0x00007ff8b5cc26a1 in ntdll!RtlUserThreadStart () from C:\Windows\System32\ntdll.dll
GDB

# Minimal Windows assert-only gdb output — no signal line, no backtrace frames
GDB_WINDOWS_ASSERT_BRIEF_OUTPUT = <<~'GDB'.freeze
  [New Thread 4168.0xa14]
  [Thread 4168.0xa14 exited with code 3]
  [Inferior 1 (process 4168) exited with code 03]
  Assertion failed: 0, file test/test_example_file_crash_assert.c, line 24
GDB

# Windows assert(0) — signal ?, DLL abort frames, assertion text at end of output
# Single-quoted heredoc: backslashes in Windows paths are literal, not escape sequences
GDB_WINDOWS_ASSERT_OUTPUT = <<~'GDB'.freeze
  Thread 1 received signal ?, Unknown signal.
  0x00007ff938364aee in ucrtbase!abort () from C:\Windows\System32\ucrtbase.dll
  #0  0x00007ff938364aee in ucrtbase!abort () from C:\Windows\System32\ucrtbase.dll
  #1  0x00007ff938320fb9 in ucrtbase!_isctype_l () from C:\Windows\System32\ucrtbase.dll
  #2  0x00007ff938382b01 in ucrtbase!_assert () from C:\Windows\System32\ucrtbase.dll
  #3  0x00007ff691745367 in _assert (message=0x7ff691747026 "0", file=0x7ff691747000 "test/test_example_file_crash_assert.c", line=24)
  #4  0x00007ff691741523 in test_add_numbers_triggers_assert () at test/test_example_file_crash_assert.c:24
  #5  0x00007ff691741675 in run_test (func=0x7ff6917414ff <test_add_numbers_triggers_assert>, name=0x7ff6917470d8 "test_add_numbers_triggers_assert", line_num=20) at build/test/runners/test_example_file_crash_assert_runner.c:77
  #6  0x00007ff6917418ce in main (argc=3, argv=0x8000e0) at build/test/runners/test_example_file_crash_assert_runner.c:123
  Kill the program being debugged? (y or n) [answered Y; input not from terminal]
  [Inferior 1 (process 8364) killed]
  Assertion failed: 0, file test/test_example_file_crash_assert.c, line 24
  gdb: unknown target exception 0xc0000409 at 0x7ff938364aee
GDB

# ── Representative do_simple output constants ─────────────────────────────────

# Running test_asserting alone — only stderr crash output, no Unity result line
SIMPLE_ASSERT_CRASH_OUTPUT =
  "test_lib.out: src/lib.c:5: asserting: Assertion `0' failed.\n" \
  "Aborted (core dumped)\n"

SIMPLE_PASS_OUTPUT   = "test_lib.c:3:test_empty:PASS\n"
SIMPLE_FAIL_OUTPUT   = "test_lib.c:8:test_bad:FAIL: Expected 1 Was 2\n"
SIMPLE_IGNORE_OUTPUT = "test_lib.c:12:test_skip:IGNORE\n"


describe GeneratorTestResultsBacktrace do

  before(:each) do
    # Configurator's tool accessors are added dynamically, so instance_double
    # cannot verify them against the class — use a plain double instead.
    @configurator            = double('Configurator')
    @tool_executor           = instance_double('ToolExecutor')
    @generator_test_results  = instance_double('GeneratorTestResults')
    @file_path_utils         = instance_double('FilePathUtils')
    @file_wrapper            = instance_double('FileWrapper')

    @backtrace = described_class.new({
      :configurator           => @configurator,
      :tool_executor          => @tool_executor,
      :generator_test_results => @generator_test_results,
      :file_path_utils        => @file_path_utils,
      :file_wrapper           => @file_wrapper
    })
    @backtrace.setup()

    # Standard stubs used by most tests
    allow(@tool_executor).to receive(:build_command_line).and_return({ options: {} })
    allow(@file_path_utils).to receive(:form_test_gdb_log) do |test, context:, name:|
      "/build/logs/#{context}/#{test}/#{name}.gdb.log"
    end
    allow(@file_wrapper).to receive(:mkdir)
    allow(@file_wrapper).to receive(:write)
    allow(@generator_test_results).to receive(:regenerate_test_executable_stdout).and_return('regenerated')
  end

  # ── #do_gdb ────────────────────────────────────────────────────────────────

  describe '#do_gdb' do
    let(:filename)    { 'test_lib.c' }
    let(:executable)  { 'build/test/out/test_lib/test_lib.out' }
    let(:shell_result){ { exit_code: 1, output: '', time: 0.0 } }
    let(:test_cases)  { [{ test: 'test_asserting', line_number: 8 }] }

    before(:each) do
      allow(@configurator).to receive(:project_build_tests_root).and_return('build/test')
      allow(@configurator).to receive(:tools_test_backtrace_gdb).and_return({})
    end

    it 'handles a PASS test case and does not write a log' do
      allow(@tool_executor).to receive(:exec)
        .and_return({ output: "test_lib.c:9:test_asserting:PASS\n", time: 0.1, exit_code: 0 })

      expect(@file_wrapper).not_to receive(:write)

      result = @backtrace.do_gdb( filename, executable, shell_result, test_cases, context: :test )

      expect(result[:exit_code]).to eq(0)
    end

    it 'handles an IGNORE test case and does not write a log' do
      allow(@tool_executor).to receive(:exec)
        .and_return({ output: "test_lib.c:9:test_asserting:IGNORE\n", time: 0.1, exit_code: 0 })

      expect(@file_wrapper).not_to receive(:write)

      result = @backtrace.do_gdb( filename, executable, shell_result, test_cases, context: :test )

      expect(result[:exit_code]).to eq(0)
    end

    it 'handles a FAIL test case and does not write a log' do
      allow(@tool_executor).to receive(:exec)
        .and_return({ output: "test_lib.c:9:test_asserting:FAIL: Expected 1 Was 2\n", time: 0.1, exit_code: 1 })

      expect(@file_wrapper).not_to receive(:write)

      result = @backtrace.do_gdb( filename, executable, shell_result, test_cases, context: :test )

      expect(result[:exit_code]).to eq(1)
    end

    it 'handles a SIGSEGV crash — writes log, includes signal label, backtick source line, and log path' do
      test_cases_sigsegv = [{ test: 'testCrash', line_number: 37 }]
      filename_sigsegv   = 'TestUsartModel.c'

      allow(@tool_executor).to receive(:exec)
        .and_return({ output: GDB_SIGSEGV_OUTPUT, time: 0.5, exit_code: 139 })

      expected_output_lines = []
      allow(@generator_test_results).to receive(:regenerate_test_executable_stdout) do |**kwargs|
        expected_output_lines = kwargs[:output]
        'regenerated'
      end

      expect(@file_wrapper).to receive(:write)
        .with('/build/logs/test/TestUsartModel/testCrash.gdb.log', /=== testCrash ===/, 'a')

      @backtrace.do_gdb( filename_sigsegv, executable, shell_result, test_cases_sigsegv, context: :test )

      crash_line = expected_output_lines.first
      expect(crash_line).to include('>> [SIGSEGV] Segmentation fault')
      expect(crash_line).not_to include('testCrash() at TestUsartModel.c:40')
      expect(crash_line).to include("#{NEWLINE_TOKEN}`uint32_t i = *null_ptr;`")
      expect(crash_line).not_to include('(log: ')
      expect(crash_line).to include('(/build/logs/test/TestUsartModel/testCrash.gdb.log)')
    end

    it 'handles a SIGABRT crash from assert() — shows assertion text, no source line (issue #1038)' do
      test_cases_assert = [{ test: 'test_asserting', line_number: 8 }]

      allow(@tool_executor).to receive(:exec)
        .and_return({ output: GDB_SIGABRT_ASSERT_OUTPUT, time: 0.3, exit_code: 134 })

      expected_output_lines = []
      allow(@generator_test_results).to receive(:regenerate_test_executable_stdout) do |**kwargs|
        expected_output_lines = kwargs[:output]
        'regenerated'
      end

      @backtrace.do_gdb( filename, executable, shell_result, test_cases_assert, context: :test )

      crash_line = expected_output_lines.first
      expect(crash_line).to include('>> [SIGABRT]')
      expect(crash_line).to include("Assertion '0' failed")
      expect(crash_line).not_to include('Aborted')
      expect(crash_line).not_to include('asserting() at lib.c:5')
      expect(crash_line).not_to include('(log: ')
      expect(crash_line).to include('(/build/logs/test/test_lib/test_asserting.gdb.log)')
    end

    it 'handles a crash with no identifiable signal — fallback message, log path without "log: " prefix' do
      allow(@tool_executor).to receive(:exec)
        .and_return({ output: GDB_NO_SIGNAL_OUTPUT, time: 0.1, exit_code: 1 })

      expected_output_lines = []
      allow(@generator_test_results).to receive(:regenerate_test_executable_stdout) do |**kwargs|
        expected_output_lines = kwargs[:output]
        'regenerated'
      end

      @backtrace.do_gdb( filename, executable, shell_result, test_cases, context: :test )

      crash_line = expected_output_lines.first
      expect(crash_line).not_to include(' >> ')
      expect(crash_line).not_to include('(log: ')
      expect(crash_line).to include('(/build/logs/test/test_lib/test_asserting.gdb.log)')
    end
  end

  # ── #do_simple ─────────────────────────────────────────────────────────────

  describe '#do_simple' do
    let(:filename)    { 'test_lib.c' }
    let(:executable)  { 'build/test/out/test_lib/test_lib.out' }
    let(:shell_result){ { exit_code: 1, output: '', time: 0.0 } }
    let(:test_cases)  { [{ test: 'test_empty', line_number: 3 }] }

    before(:each) do
      allow(@configurator).to receive(:tools_test_fixture_simple_backtrace).and_return({})
    end

    it 'handles a PASS test case' do
      allow(@tool_executor).to receive(:exec)
        .and_return({ output: SIMPLE_PASS_OUTPUT, time: 0.05, exit_code: 0 })

      result = @backtrace.do_simple( filename, executable, shell_result, test_cases, context: :test )

      expect(result[:exit_code]).to eq(0)
    end

    it 'handles a FAIL test case with a message' do
      test_cases_fail = [{ test: 'test_bad', line_number: 8 }]

      allow(@tool_executor).to receive(:exec)
        .and_return({ output: SIMPLE_FAIL_OUTPUT, time: 0.05, exit_code: 1 })

      result = @backtrace.do_simple( filename, executable, shell_result, test_cases_fail, context: :test )

      expect(result[:exit_code]).to eq(1)
    end

    it 'handles an IGNORE test case' do
      test_cases_ignore = [{ test: 'test_skip', line_number: 12 }]

      allow(@tool_executor).to receive(:exec)
        .and_return({ output: SIMPLE_IGNORE_OUTPUT, time: 0.02, exit_code: 0 })

      result = @backtrace.do_simple( filename, executable, shell_result, test_cases_ignore, context: :test )

      expect(result[:exit_code]).to eq(0)
    end

    it 'handles a crash and includes extra executable output in the failure message' do
      test_cases_crash = [{ test: 'test_asserting', line_number: 8 }]

      allow(@tool_executor).to receive(:exec)
        .and_return({ output: SIMPLE_ASSERT_CRASH_OUTPUT, time: 0.1, exit_code: 134 })

      expected_output_lines = []
      allow(@generator_test_results).to receive(:regenerate_test_executable_stdout) do |**kwargs|
        expected_output_lines = kwargs[:output]
        'regenerated'
      end

      @backtrace.do_simple( filename, executable, shell_result, test_cases_crash, context: :test )

      crash_line = expected_output_lines.first
      expect(crash_line).to include(':FAIL: Test case crashed')
      expect(crash_line).to include(' >> ')
      expect(crash_line).to include("Assertion `0' failed")
    end

    it 'handles a crash with no extra output — no >> segment in the failure message' do
      test_cases_crash = [{ test: 'test_asserting', line_number: 8 }]

      allow(@tool_executor).to receive(:exec)
        .and_return({ output: "\n\n\n", time: 0.1, exit_code: 134 })

      expected_output_lines = []
      allow(@generator_test_results).to receive(:regenerate_test_executable_stdout) do |**kwargs|
        expected_output_lines = kwargs[:output]
        'regenerated'
      end

      @backtrace.do_simple( filename, executable, shell_result, test_cases_crash, context: :test )

      crash_line = expected_output_lines.first
      expect(crash_line).to include(':FAIL: Test case crashed')
      expect(crash_line).not_to include(' >> ')
    end
  end

  # ── private #format_signal_label ───────────────────────────────────────────

  describe '#format_signal_label (private)' do
    subject { |ex| @backtrace.send(:format_signal_label, ex.metadata[:output]) }

    context 'with SIGSEGV', output: GDB_SIGSEGV_OUTPUT do
      it 'returns bracketed signal name and description' do
        expect(subject).to eq('[SIGSEGV] Segmentation fault')
      end
    end

    context 'with SIGBUS', output: GDB_SIGBUS_OUTPUT do
      it 'returns bracketed signal name and description' do
        expect(subject).to eq('[SIGBUS] Bus error')
      end
    end

    context 'with SIGABRT and assertion text (issue #1038)', output: GDB_SIGABRT_ASSERT_OUTPUT do
      it 'substitutes assertion text for the bare signal description' do
        expect(subject).to eq("[SIGABRT] Assertion '0' failed")
      end

      it 'does not include the bare "Aborted" description' do
        expect(subject).not_to include('Aborted')
      end
    end

    context 'with all ?? () frames (no debug symbols)', output: GDB_UNSYMBOLIZED_OUTPUT do
      it 'still returns the signal label (crash site is not part of this method)' do
        expect(subject).to eq('[SIGSEGV] Segmentation fault')
      end
    end

    context 'with no signal line', output: GDB_NO_SIGNAL_OUTPUT do
      it 'returns an empty string' do
        expect(subject).to eq('')
      end
    end

    context 'with Windows SIGSEGV (Thread N prefix)', output: GDB_WINDOWS_SIGSEGV_OUTPUT do
      it 'handles Thread N signal line and returns bracketed signal name and description' do
        expect(subject).to eq('[SIGSEGV] Segmentation fault')
      end
    end

    context 'with Windows assert(0) — unknown signal (?), assertion text at end of output', output: GDB_WINDOWS_ASSERT_OUTPUT do
      it 'shows assertion text without brackets or SIGABRT claim' do
        expect(subject).to eq("Assertion '0' failed")
      end

      it 'does not include "Unknown signal" in the label' do
        expect(subject).not_to include('Unknown signal')
      end

      it 'does not claim SIGABRT when signal was not explicitly named' do
        expect(subject).not_to include('SIGABRT')
      end
    end

    context 'with brief Windows assert — no signal line, only assertion text at end' do
      it 'returns assertion text with no brackets and no SIGABRT claim' do
        result = @backtrace.send(:format_signal_label, GDB_WINDOWS_ASSERT_BRIEF_OUTPUT)
        expect(result).to eq("Assertion '0' failed")
      end

      it 'does not include SIGABRT' do
        result = @backtrace.send(:format_signal_label, GDB_WINDOWS_ASSERT_BRIEF_OUTPUT)
        expect(result).not_to include('SIGABRT')
      end
    end

    context 'with Windows unknown signal (?) and exception code, no assertion' do
      it 'returns the exception code without brackets' do
        output = "Thread 1 received signal ?, Unknown signal.\ngdb: unknown target exception 0xc0000005\n"
        result = @backtrace.send(:format_signal_label, output)
        expect(result).to eq('Windows exception 0xc0000005')
      end
    end

    context 'with Windows unknown signal (?) and no assertion or exception code' do
      it 'returns empty string — Unknown signal alone is not useful' do
        output = "Thread 1 received signal ?, Unknown signal.\n"
        result = @backtrace.send(:format_signal_label, output)
        expect(result).to eq('')
      end
    end
  end

  # ── private #extract_source_line ───────────────────────────────────────────

  describe '#extract_source_line (private)' do
    it 'extracts the source line from SIGSEGV output' do
      result = @backtrace.send(:extract_source_line, GDB_SIGSEGV_OUTPUT, 'testCrash', 'TestUsartModel.c')
      expect(result).to eq('uint32_t i = *null_ptr;')
    end

    it 'returns nil for assertion crashes — description is already informative' do
      result = @backtrace.send(:extract_source_line, GDB_SIGABRT_ASSERT_OUTPUT, 'test_asserting', 'test_lib.c')
      expect(result).to be_nil
    end

    it 'returns nil when no source line follows the crash location (SIGBUS)' do
      result = @backtrace.send(:extract_source_line, GDB_SIGBUS_OUTPUT, 'testBusError', 'test_widget.c')
      expect(result).to be_nil
    end

    it 'returns nil for brief Windows assert-only output' do
      result = @backtrace.send(:extract_source_line, GDB_WINDOWS_ASSERT_BRIEF_OUTPUT, 'test_add_numbers_triggers_assert', 'test_example_file_crash_assert.c')
      expect(result).to be_nil
    end
  end

  # ── private #format_signal_label (Windows brief form) → #do_gdb ──────────

  describe '#do_gdb with brief Windows assert (no crash frame)' do
    let(:filename_assert)   { 'test_example_file_crash_assert.c' }
    let(:test_cases_assert) { [{ test: 'test_add_numbers_triggers_assert', line_number: 20 }] }
    let(:executable)        { 'build/test/out/test_example_file_crash_assert/test_example_file_crash_assert.out' }
    let(:shell_result)      { { exit_code: 1, output: '', time: 0.0 } }

    before(:each) do
      allow(@configurator).to receive(:project_build_tests_root).and_return('build/test')
      allow(@configurator).to receive(:tools_test_backtrace_gdb).and_return({})
    end

    it 'uses assertion label and metadata line number when no crash location frame is found' do
      allow(@tool_executor).to receive(:exec)
        .and_return({ output: GDB_WINDOWS_ASSERT_BRIEF_OUTPUT, time: 0.1, exit_code: 3 })

      expected_output_lines = []
      allow(@generator_test_results).to receive(:regenerate_test_executable_stdout) do |**kwargs|
        expected_output_lines = kwargs[:output]
        'regenerated'
      end

      @backtrace.do_gdb( filename_assert, executable, shell_result, test_cases_assert, context: :test )

      crash_line = expected_output_lines.first
      expect(crash_line).to include(">> Assertion '0' failed")
      expect(crash_line).not_to include('failed to extract')
      expect(crash_line).not_to include('SIGABRT')
      expect(crash_line).to include(':20:')  # metadata line number used
    end
  end

end
