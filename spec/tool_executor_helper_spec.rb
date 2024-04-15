# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/constants'
require 'ceedling/tool_executor_helper'
require 'ceedling/system_wrapper'
require 'ceedling/streaminator'
require 'ceedling/system_utils'

HAPPY_OUTPUT =
  "> Shell executed command:\n" +
  "'gcc ab.c'\n" +
  "\n".freeze

HAPPY_OUTPUT_WITH_STATUS =
  "> Shell executed command:\n" +
  "'gcc ab.c'\n" +
  "> And exited with status: [1].\n" +
  "\n".freeze

HAPPY_OUTPUT_WITH_MESSAGE =
  "> Shell executed command:\n" +
  "'gcc ab.c'\n" +
  "> Produced output:\n" +
  "xyz\n" +
  "\n".freeze

HAPPY_OUTPUT_WITH_MESSAGE_AND_STATUS =
  "> Shell executed command:\n" +
  "'gcc ab.c'\n" +
  "> Produced output:\n" +
  "xyz\n" +
  "> And exited with status: [1].\n" +
  "\n".freeze

ERROR_OUTPUT =
  "ERROR: Shell command failed.\n" +
  "> Shell executed command:\n" +
  "'gcc ab.c'\n" +
  "> And exited with status: [1].\n" +
  "\n"

ERROR_OUTPUT_WITH_MESSAGE =
  "ERROR: Shell command failed.\n" +
  "> Shell executed command:\n" +
  "'gcc ab.c'\n" +
  "> Produced output:\n" +
  "xyz\n" +
  "> And exited with status: [1].\n" +
  "\n"


describe ToolExecutorHelper do
  before(:each) do
    # these will always be mocked
    @sys_wraper = SystemWrapper.new
    @sys_utils = SystemUtils.new({:system_wrapper => @sys_wraper})
    @streaminator = Streaminator.new({:streaminator_helper => nil, :verbosinator => nil, :loginator => nil, :stream_wrapper => @sys_wraper})
    
    
    @tool_exe_helper = described_class.new({:streaminator => @streaminator, :system_utils => @sys_utils, :system_wrapper => @sys_wraper})
  end

  
  describe '#stderr_redirection' do
    it 'returns stderr_redirect if logging is false' do
      expect(@tool_exe_helper.stderr_redirection({:stderr_redirect => StdErrRedirect::NONE}, false)).to eq(StdErrRedirect::NONE)
    end

    it 'returns stderr_redirect if logging is true and is a string' do
      expect(@tool_exe_helper.stderr_redirection({:stderr_redirect => 'abc'}, true)).to eq('abc')
    end

    it 'returns AUTO if logging is true and stderr_redirect is not a string' do
      expect(@tool_exe_helper.stderr_redirection({:stderr_redirect => StdErrRedirect::NONE}, true)).to eq(StdErrRedirect::AUTO)
    end
  end


  describe '#osify_path_separators' do
    it 'returns path if system is not windows' do
      exe = '/just/some/executable.out'
      expect(@sys_wraper).to receive(:windows?).and_return(false)
      expect(@tool_exe_helper.osify_path_separators(exe)).to eq(exe)
    end

    it 'returns modifed if system is windows' do
      exe = '/just/some/executable.exe'
      expect(@sys_wraper).to receive(:windows?).and_return(true)
      expect(@tool_exe_helper.osify_path_separators(exe)).to eq("\\just\\some\\executable.exe")
    end
  end


  describe '#stderr_redirect_cmdline_append' do
    it 'returns nil if tool_config is nil' do
      expect(@tool_exe_helper.stderr_redirect_cmdline_append(nil)).to be_nil
    end

    it 'returns nil if tool_config[:stderr_redirect] is nil' do
      tool_config = {:stderr_redirect => nil}
      expect(@tool_exe_helper.stderr_redirect_cmdline_append(tool_config)).to be_nil
    end

    it 'returns nil if tool_config is set to none' do
      tool_config = {:stderr_redirect => StdErrRedirect::NONE}
      expect(@tool_exe_helper.stderr_redirect_cmdline_append(tool_config)).to be_nil
    end

    context 'StdErrRedirect::AUTO' do
      before(:each) do
        @tool_config = {:stderr_redirect => StdErrRedirect::AUTO}
      end


      it 'returns "2>&1" if system is windows' do
        expect(@sys_wraper).to receive(:windows?).and_return(true)
        expect(@tool_exe_helper.stderr_redirect_cmdline_append(@tool_config)).to eq('2>&1')
      end

      it 'returns "|&" if system is tcsh' do
        expect(@sys_wraper).to receive(:windows?).and_return(false)
        expect(@sys_utils).to receive(:tcsh_shell?).and_return(true)
        expect(@tool_exe_helper.stderr_redirect_cmdline_append(@tool_config)).to eq('|&')
      end

      it 'returns "2>&1" if system is unix' do
        expect(@sys_wraper).to receive(:windows?).and_return(false)
        expect(@sys_utils).to receive(:tcsh_shell?).and_return(false)
        expect(@tool_exe_helper.stderr_redirect_cmdline_append(@tool_config)).to eq('2>&1')
      end     
    end
  end

  describe '#print_happy_results' do
    context 'when exit code is 0' do
      before(:each) do
        @shell_result = {:exit_code => 0, :output => ""}
      end

      it 'and boom is true displays output' do
        expect(@streaminator).to receive(:stream_puts).with(HAPPY_OUTPUT, Verbosity::OBNOXIOUS)
        @tool_exe_helper.print_happy_results("gcc ab.c", @shell_result, true)
      end

      it 'and boom is true with message displays output' do
        @shell_result[:output] = "xyz"
        expect(@streaminator).to receive(:stream_puts).with(HAPPY_OUTPUT_WITH_MESSAGE, Verbosity::OBNOXIOUS)
        @tool_exe_helper.print_happy_results("gcc ab.c", @shell_result, true)
      end

      it 'and boom is false displays output' do
        expect(@streaminator).to receive(:stream_puts).with(HAPPY_OUTPUT, Verbosity::OBNOXIOUS)
        @tool_exe_helper.print_happy_results("gcc ab.c", @shell_result, false)
      end

      it 'and boom is false with message displays output' do
        @shell_result[:output] = "xyz"
        expect(@streaminator).to receive(:stream_puts).with(HAPPY_OUTPUT_WITH_MESSAGE, Verbosity::OBNOXIOUS)
        @tool_exe_helper.print_happy_results("gcc ab.c", @shell_result, false)
      end
    end

    context 'when exit code is not 0' do
      before(:each) do
        @shell_result = {:exit_code => 1, :output => ""}
      end

      it 'and boom is true does not displays output' do
        @tool_exe_helper.print_happy_results("gcc ab.c", @shell_result, true)
      end

      it 'and boom is true with message does not displays output' do
        @shell_result[:output] = "xyz"
        @tool_exe_helper.print_happy_results("gcc ab.c", @shell_result, true)
      end

      it 'and boom is false displays output' do
        expect(@streaminator).to receive(:stream_puts).with(HAPPY_OUTPUT_WITH_STATUS, Verbosity::OBNOXIOUS)
        @tool_exe_helper.print_happy_results("gcc ab.c", @shell_result, false)
      end

      it 'and boom is false with message displays output' do
        @shell_result[:output] = "xyz"
        expect(@streaminator).to receive(:stream_puts).with(HAPPY_OUTPUT_WITH_MESSAGE_AND_STATUS, Verbosity::OBNOXIOUS)
        @tool_exe_helper.print_happy_results("gcc ab.c", @shell_result, false)
      end
    end
  end

  describe '#print_error_results' do
    context 'when exit code is 0' do
      before(:each) do
        @shell_result = {:exit_code => 0, :output => ""}
      end

      it 'and boom is true does not display output' do
        @tool_exe_helper.print_error_results("gcc ab.c", @shell_result, true)
      end

      it 'and boom is true with message does not display output' do
        @shell_result[:output] = "xyz"
        @tool_exe_helper.print_error_results("gcc ab.c", @shell_result, true)
      end

      it 'and boom is false does not display output' do
        @tool_exe_helper.print_error_results("gcc ab.c", @shell_result, false)
      end

      it 'and boom is false with message does not display output' do
        @shell_result[:output] = "xyz"
        @tool_exe_helper.print_error_results("gcc ab.c", @shell_result, false)
      end
    end

    context 'when exit code is non 0' do
      before(:each) do
        @shell_result = {:exit_code => 1, :output => ""}
      end

      it 'and boom is true displays output' do
        expect(@streaminator).to receive(:stream_puts).with(ERROR_OUTPUT, Verbosity::ERRORS)
        @tool_exe_helper.print_error_results("gcc ab.c", @shell_result, true)
      end

      it 'and boom is true with message displays output' do
        @shell_result[:output] = "xyz"
        expect(@streaminator).to receive(:stream_puts).with(ERROR_OUTPUT_WITH_MESSAGE, Verbosity::ERRORS)
        @tool_exe_helper.print_error_results("gcc ab.c", @shell_result, true)
      end

      it 'and boom is false dose not display output' do
        @tool_exe_helper.print_error_results("gcc ab.c", @shell_result, false)
      end

      it 'and boom is false with message does not display output' do
        @shell_result[:output] = "xyz"
        @tool_exe_helper.print_error_results("gcc ab.c", @shell_result, false)
      end
    end
  end
end
