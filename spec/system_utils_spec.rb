require 'spec_helper'
require 'ceedling/system_utils'


describe SystemUtils do
  before(:each) do
    # this will always be mocked
    @sys_wrapper = nil
    allow_message_expectations_on_nil

    @sys_utils = described_class.new({:system_wrapper => @sys_wrapper})
    @sys_utils.setup

    @echo_test_cmd = {:command=>'echo $version'}
  end
 
  describe '#setup' do
    it 'sets tcsh_shell to nil' do
      expect(@sys_utils.instance_variable_get(:@tcsh_shell)).to eq(nil)
    end

    it 'sets tcsh_shell to nil after being set' do
      expect(@sys_utils.instance_variable_get(:@tcsh_shell)).to eq(nil)
     

      allow(@streaminator).to receive(:shell_backticks).with(@echo_test_cmd).and_return({:exit_code => 0, :output =>'tcsh 1234567890'})
      @sys_utils.tcsh_shell?
      
      @sys_utils.setup
      expect(@sys_utils.instance_variable_get(:@tcsh_shell)).to eq(nil)
    end
  end


  describe '#tcsh_shell?' do
    it 'returns true if exit code is zero and output contains tcsh' do
      allow(@streaminator).to receive(:shell_backticks).with(@echo_test_cmd).and_return({:exit_code => 0, :output =>'tcsh 1234567890'})
      expect(@sys_utils.tcsh_shell?).to eq(true)
    end

    it 'returns false if exit code is not 0' do
      allow(@streaminator).to receive(:shell_backticks).with(@echo_test_cmd).and_return({:exit_code => 1, :output =>'tcsh 1234567890'})
      expect(@sys_utils.tcsh_shell?).to eq(false)
    end

    it 'returns false if output does not contain tcsh' do
      allow(@streaminator).to receive(:shell_backticks).with(@echo_test_cmd).and_return({:exit_code => 0, :output =>'???'})
      expect(@sys_utils.tcsh_shell?).to eq(false)
    end

    it 'returns last value if already run' do
      allow(@streaminator).to receive(:shell_backticks).with(@echo_test_cmd).and_return({:exit_code => 1, :output =>'???'})
      expect(@sys_utils.tcsh_shell?).to eq(false)
      allow(@streaminator).to receive(:shell_backticks).with(@echo_test_cmd).and_return({:exit_code => 0, :output =>'tcsh 1234567890'})
      expect(@sys_utils.tcsh_shell?).to eq(false)
    end
  end
end
