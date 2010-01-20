require 'hardmock/method_cleanout'
require 'hardmock/mock'
require 'hardmock/mock_control'
require 'hardmock/utils'
require 'hardmock/errors'
require 'hardmock/trapper'
require 'hardmock/expector'
require 'hardmock/expectation'
require 'hardmock/expectation_builder'
require 'hardmock/stubbing'

module Hardmock

  # Create one or more new Mock instances in your test suite. 
  # Once created, the Mocks are accessible as instance variables in your test.
  # Newly built Mocks are added to the full set of Mocks for this test, which will
  # be verified when you call verify_mocks.
  #
  #   create_mocks :donkey, :cat # Your test now has @donkey and @cat
  #   create_mock  :dog          # Test now has @donkey, @cat and @dog
  #   
  # The first call returned a hash { :donkey => @donkey, :cat => @cat }
  # and the second call returned { :dog => @dog }
  #
  # For more info on how to use your mocks, see Mock and Expectation
  #
  def create_mocks(*mock_names)
    prepare_hardmock_control unless @main_mock_control

    mocks = {}
    mock_names.each do |mock_name|
      raise ArgumentError, "'nil' is not a valid name for a mock" if mock_name.nil?
      mock_name = mock_name.to_s
      mock_object = Mock.new(mock_name, @main_mock_control)
      mocks[mock_name.to_sym] = mock_object
      self.instance_variable_set "@#{mock_name}", mock_object
    end
    @all_mocks ||= {}
    @all_mocks.merge! mocks

    return mocks.clone
  end

  def prepare_hardmock_control
    if @main_mock_control.nil?
      @main_mock_control = MockControl.new
      $main_mock_control = @main_mock_control
    else
      raise "@main_mock_control is already setup for this test!"
    end
  end

  alias :create_mock :create_mocks

  # Ensures that all expectations have been met.  If not, VerifyException is
  # raised.
  #
  # <b>You normally won't need to call this yourself.</b> Within Test::Unit::TestCase, this will be done automatically at teardown time.
  #
  # * +force+ -- if +false+, and a VerifyError or ExpectationError has already occurred, this method will not raise.  This is to help you suppress repeated errors when if you're calling #verify_mocks in the teardown method of your test suite.  BE WARNED - only use this if you're sure you aren't obscuring useful information.  Eg, if your code handles exceptions internally, and an ExpectationError gets gobbled up by your +rescue+ block, the cause of failure for your test may be hidden from you.  For this reason, #verify_mocks defaults to force=true as of Hardmock 1.0.1
  def verify_mocks(force=true)
    return unless @main_mock_control
    return if @main_mock_control.disappointed? and !force
    @main_mock_control.verify
  ensure
    @main_mock_control.clear_expectations if @main_mock_control
    $main_mock_control = nil
    reset_stubs
  end
  
  alias :verify_hardmocks :verify_mocks

  # Purge the main MockControl of all expectations, restore all concrete stubbed/mocked methods
  def clear_expectations
    @main_mock_control.clear_expectations if @main_mock_control
    reset_stubs
    $main_mock_control = nil
  end

  def reset_stubs
    Hardmock.restore_all_replaced_methods
  end

end

require 'extend_test_unit'
