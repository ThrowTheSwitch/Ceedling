# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/constants'
require 'ceedling/tool_executor_helper'
require 'ceedling/system_wrapper'
require 'ceedling/loginator'
require 'ceedling/system_utils'
require 'ceedling/verbosinator'


describe ToolExecutorHelper do
  before(:each) do
    # these will always be mocked
    @sys_wrapper = SystemWrapper.new
    @sys_utils = SystemUtils.new({:system_wrapper => @sys_wrapper})
    @loginator = Loginator.new({:verbosinator => nil, :file_wrapper => nil, :system_wrapper => nil})
    @verbosinator = Verbosinator.new()
    
    @tool_exe_helper = described_class.new(
      {
        :loginator => @loginator,
        :system_utils => @sys_utils,
        :system_wrapper => @sys_wrapper,
        :verbosinator => @verbosinator
      }
    )
  end
  

  describe '#osify_path_separators' do
    it 'returns path if system is not windows' do
      exe = '/just/some/executable.out'
      expect(@sys_wrapper).to receive(:windows?).and_return(false)
      expect(@tool_exe_helper.osify_path_separators(exe)).to eq(exe)
    end

    it 'returns modifed if system is windows' do
      exe = '/just/some/executable.exe'
      expect(@sys_wrapper).to receive(:windows?).and_return(true)
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
        expect(@sys_wrapper).to receive(:windows?).and_return(true)
        expect(@tool_exe_helper.stderr_redirect_cmdline_append(@tool_config)).to eq('2>&1')
      end

      it 'returns "|&" if system is tcsh' do
        expect(@sys_wrapper).to receive(:windows?).and_return(false)
        expect(@sys_utils).to receive(:tcsh_shell?).and_return(true)
        expect(@tool_exe_helper.stderr_redirect_cmdline_append(@tool_config)).to eq('|&')
      end

      it 'returns "2>&1" if system is unix' do
        expect(@sys_wrapper).to receive(:windows?).and_return(false)
        expect(@sys_utils).to receive(:tcsh_shell?).and_return(false)
        expect(@tool_exe_helper.stderr_redirect_cmdline_append(@tool_config)).to eq('2>&1')
      end     
    end
  end

  describe '#log_results' do
    it 'insufficient logging verbosity' do
      # Do nothing
      expect(@verbosinator).to receive(:should_output?).with(Verbosity::OBNOXIOUS).and_return(false)
      @tool_exe_helper.log_results("gcc ab.c", {})
    end

    context 'when debug logging' do
      before(:each) do
        expect(@verbosinator).to receive(:should_output?).with(Verbosity::OBNOXIOUS).and_return(true)
        expect(@verbosinator).to receive(:should_output?).with(Verbosity::DEBUG).and_return(true)
        @shell_result = {:status => '<status>'}
      end

      it 'and $stderr and $stdout are both empty' do
        @shell_result[:stderr] = ''
        @shell_result[:stdout] = ''

        message =
          "> Shell executed command:\n" +
          "`gcc ab.c`\n" +
          "> With $stdout: <empty>\n" +
          "> With $stderr: <empty>\n" +
          "> And terminated with status: <status>\n"

        expect(@loginator).to receive(:log).with('', Verbosity::DEBUG)
        expect(@loginator).to receive(:log).with(message, Verbosity::DEBUG)
        expect(@loginator).to receive(:log).with('', Verbosity::DEBUG)

        @tool_exe_helper.log_results("gcc ab.c", @shell_result)
      end

      it 'and $stderr is not empty' do
        @shell_result[:stderr] = "error output\n\n\n"
        @shell_result[:stdout] = ''

        message =
          "> Shell executed command:\n" +
          "`test.exe`\n" +
          "> With $stdout: <empty>\n" +
          "> With $stderr: \nerror output\n" +
          "> And terminated with status: <status>\n"

        expect(@loginator).to receive(:log).with('', Verbosity::DEBUG)
        expect(@loginator).to receive(:log).with(message, Verbosity::DEBUG)
        expect(@loginator).to receive(:log).with('', Verbosity::DEBUG)

        @tool_exe_helper.log_results("test.exe", @shell_result)
      end

      it 'and $stdout is not empty' do
        @shell_result[:stderr] = ''
        @shell_result[:stdout] = "output\n\n\n"

        message =
          "> Shell executed command:\n" +
          "`utility --flag`\n" +
          "> With $stdout: \noutput\n" +
          "> With $stderr: <empty>\n" +
          "> And terminated with status: <status>\n"

        expect(@loginator).to receive(:log).with('', Verbosity::DEBUG)
        expect(@loginator).to receive(:log).with(message, Verbosity::DEBUG)
        expect(@loginator).to receive(:log).with('', Verbosity::DEBUG)

        @tool_exe_helper.log_results("utility --flag", @shell_result)
      end
    end

    context 'when obnoxious logging' do
      before(:each) do
        expect(@verbosinator).to receive(:should_output?).with(Verbosity::OBNOXIOUS).and_return(true)
        expect(@verbosinator).to receive(:should_output?).with(Verbosity::DEBUG).and_return(false)
        @shell_result = {}
      end

      it 'and executable probably crashed' do
        @shell_result[:output] = ''
        @shell_result[:exit_code] = nil

        message =
          "> Shell executed command:\n" +
          "`gcc ab.c`\n" +
          "> And exited prematurely\n"

        expect(@loginator).to receive(:log).with('', Verbosity::OBNOXIOUS)
        expect(@loginator).to receive(:log).with(message, Verbosity::OBNOXIOUS)
        expect(@loginator).to receive(:log).with('', Verbosity::OBNOXIOUS)

        @tool_exe_helper.log_results("gcc ab.c", @shell_result)
      end

      it 'and executable produced output and zero exit code' do
        @shell_result[:output] = 'some output'
        @shell_result[:exit_code] = 0

        message =
          "> Shell executed command:\n" +
          "`test.exe --a_flag`\n" +
          "> Produced output: \nsome output\n" +
          "> And terminated with exit code: [0]\n"

        expect(@loginator).to receive(:log).with('', Verbosity::OBNOXIOUS)
        expect(@loginator).to receive(:log).with(message, Verbosity::OBNOXIOUS)
        expect(@loginator).to receive(:log).with('', Verbosity::OBNOXIOUS)

        @tool_exe_helper.log_results("test.exe --a_flag", @shell_result)
      end

      it 'and executable produced output and non-zero exit code' do
        @shell_result[:output] = 'some more output'
        @shell_result[:exit_code] = 37

        message =
          "> Shell executed command:\n" +
          "`utility.out args`\n" +
          "> Produced output: \nsome more output\n" +
          "> And terminated with exit code: [37]\n"

        expect(@loginator).to receive(:log).with('', Verbosity::OBNOXIOUS)
        expect(@loginator).to receive(:log).with(message, Verbosity::OBNOXIOUS)
        expect(@loginator).to receive(:log).with('', Verbosity::OBNOXIOUS)

        @tool_exe_helper.log_results("utility.out args", @shell_result)
      end
    end

  end
end
