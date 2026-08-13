# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/system_wrapper'

describe SystemWrapper do
  before(:each) do
    @sys_wrapper = described_class.new
  end

  # Portable, real subprocess invocations -- no shell scripting, no signals (those are
  # covered where they're actually consumed, via doubles, in generator_helper_spec.rb).
  # This spec exists to characterize shell_capture3's own contract: it is the sole place
  # a subprocess's real Process::Status is captured, and the one thing downstream crash
  # detection depends on entirely.
  def ruby_command(code)
    "#{RbConfig.ruby} -e #{code.inspect}"
  end

  describe '#shell_capture3' do
    context 'boom: false (the default, and how test-fixture execution always runs)' do
      it 'forces exit_code to 0 even though the real subprocess exited nonzero' do
        result = @sys_wrapper.shell_capture3( command: ruby_command('exit 3'), boom: false )
        expect(result[:exit_code]).to eq(0)
      end

      it 'still relays the real, un-neutered Process::Status' do
        result = @sys_wrapper.shell_capture3( command: ruby_command('exit 3'), boom: false )
        expect(result[:status]).not_to be_nil
        expect(result[:status].exitstatus).to eq(3)
        expect(result[:status].success?).to be false
      end

      it 'forces exit_code to 0 for a genuinely successful subprocess too' do
        result = @sys_wrapper.shell_capture3( command: ruby_command('exit 0'), boom: false )
        expect(result[:exit_code]).to eq(0)
        expect(result[:status].success?).to be true
      end
    end

    context 'boom: true' do
      it 'surfaces the real nonzero exit code' do
        result = @sys_wrapper.shell_capture3( command: ruby_command('exit 3'), boom: true )
        expect(result[:exit_code]).to eq(3)
      end

      it 'reports 0 for a genuinely successful subprocess' do
        result = @sys_wrapper.shell_capture3( command: ruby_command('exit 0'), boom: true )
        expect(result[:exit_code]).to eq(0)
      end

      it 'still relays the same real Process::Status as boom: false does' do
        result = @sys_wrapper.shell_capture3( command: ruby_command('exit 3'), boom: true )
        expect(result[:status].exitstatus).to eq(3)
      end
    end

    it 'combines stdout and stderr into :output while keeping each stream separately available' do
      result = @sys_wrapper.shell_capture3(
        command: ruby_command('STDOUT.print "out"; STDERR.print "err"'), boom: false
      )
      expect(result[:stdout]).to eq('out')
      expect(result[:stderr]).to eq('err')
      expect(result[:output]).to eq('outerr')
    end
  end
end
