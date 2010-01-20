require File.expand_path(File.dirname(__FILE__) + "/../test_helper")
require 'hardmock/method_cleanout'
require 'hardmock/mock_control'
require 'hardmock/errors'
require 'hardmock/expectation_builder'
require 'hardmock/expectation'
require 'hardmock/mock'

class VerifyErrorTest < Test::Unit::TestCase
  include Hardmock

  #
  # TESTS
  #

  def test_formatted_list_of_unmet_expectations
    mock1 = Mock.new('mock1')
    mock2 = Mock.new('mock2')
    exp1 = Expectation.new( :mock => mock1, :method => 'send_parts', :arguments => [1,2,:a] )
    exp2 = Expectation.new( :mock => mock2, :method => 'grind_it', :arguments => [] )

    exp_list = [ exp1, exp2 ]

    err = VerifyError.new("This is the error", exp_list)
    assert_equal "This is the error:\n * #{exp1.to_s}\n * #{exp2.to_s}", err.message
  end

  def test_empty_list_of_expectations
    # this is not a normal case; not spending a lot of time to make this better
    exp_list = []
    err = VerifyError.new("This is the error:\n", exp_list)
  end

  def test_nil_expectation_list
    # this is not a normal case; not spending a lot of time to make this better
    exp_list = []
    err = VerifyError.new("This is the error:\n", exp_list)
  end

end
