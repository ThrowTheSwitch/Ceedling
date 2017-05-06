require 'spec_helper'
require 'ceedling/build_invoker_utils'
require 'ceedling/constants'
require 'ceedling/streaminator'
require 'ceedling/configurator'

describe BuildInvokerUtils do
  before(:each) do
    # this will always be mocked
    @configurator = Configurator.new({:configurator_setup => nil, :configurator_builder => nil,
                                      :configurator_plugins => nil, :cmock_builder => nil,
                                      :yaml_wrapper => nil, :system_wrapper => nil})
    @streaminator = Streaminator.new({:streaminator_helper => nil, :verbosinator => nil,
                                      :loginator => nil, :stream_wrapper => nil})

    # this is what is being tested
    @bi_utils = described_class.new({:configurator => @configurator, :streaminator => @streaminator})
 
    # these keep the actual test cleaner
    @exception_msg = 'Don\'t know how to build task \'xyz\''
    @basic_msg =  "ERROR: Rake could not find file referenced in source or test: 'xyz'. Possible stale dependency."
    @deep_dep_msg = "Try fixing #include statements or adding missing file. Then run '#{REFRESH_TASK_ROOT}#{TEST_SYM.to_s}' task and try again."
    @exception = RuntimeError.new(@exception_msg)
  end
  
  describe '#process_exception' do

    it 'passes given error if message does not contain handled messagr' do
      expect{@bi_utils.process_exception(ArgumentError.new('oops...'), TEST_SYM)}.to raise_error(ArgumentError)
    end

    it 'prints to stderr for test with test_build flag set true' do
      allow(@streaminator).to receive(:stderr_puts).with(@basic_msg)
      allow(@configurator).to receive(:project_use_deep_dependencies).and_return(false)
      expect{@bi_utils.process_exception(@exception, TEST_SYM, true)}.to raise_error(RuntimeError)
    end

    it 'prints to stderr for test with test_build flag set false' do
      allow(@streaminator).to receive(:stderr_puts).with(@basic_msg.sub(' or test', ''))
      allow(@configurator).to receive(:project_use_deep_dependencies).and_return(false)
      expect{@bi_utils.process_exception(@exception, TEST_SYM, false)}.to raise_error(RuntimeError)
    end

    it 'prints to stderr with extra message when deep dependencies is true' do
      allow(@streaminator).to receive(:stderr_puts).with(@basic_msg.sub(' or test', ''))
      allow(@configurator).to receive(:project_use_deep_dependencies).and_return(true)
      allow(@streaminator).to receive(:stderr_puts).with(@deep_dep_msg)
      
      expect{@bi_utils.process_exception(@exception, TEST_SYM, false)}.to raise_error(RuntimeError)
    end


  end
end
