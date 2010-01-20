require File.expand_path(File.dirname(__FILE__) + "/../test_helper")
require 'hardmock/utils'
require 'hardmock/errors'
require 'hardmock/mock_control'

class MockControlTest < Test::Unit::TestCase
  include Hardmock

  def setup
    @unmock = OpenStruct.new( :_name => 'fakemock' )

    @control = MockControl.new
    assert @control.happy?, "Control should start out happy"
  end

  def teardown
  end

  #
  # HELPERS
  #

  class MyExp  
    attr_reader :mock, :mname, :args, :block
    def apply_method_call(mock, mname, args, block)
      @mock = mock
      @mname = mname
      @args = args
      @block = block
    end
  end

  class BoomExp < MyExp
    def apply_method_call(mock, mname, args, block)
      super
      raise "BOOM"
    end
  end

  #
  # TESTS
  #

  def test_add_exepectation_and_apply_method_call
    e1 = MyExp.new

    @control.add_expectation e1
    assert !@control.happy?

    @control.apply_method_call @unmock, 'some_func', [ 'the', :args ], nil
    assert @control.happy?
    
    assert_same @unmock, e1.mock, "Wrong mock"
    assert_equal 'some_func', e1.mname, "Wrong method"
    assert_equal [ 'the', :args ], e1.args, "Wrong args"

    @control.verify
  end

  def test_add_exepectation_and_apply_method_call_with_block
    e1 = MyExp.new

    @control.add_expectation e1
    assert !@control.happy?

    runtime_block = Proc.new { "hello" }
    @control.apply_method_call @unmock, 'some_func', [ 'the', :args ], runtime_block
    assert @control.happy?
    
    assert_same @unmock, e1.mock, "Wrong mock"
    assert_equal 'some_func', e1.mname, "Wrong method"
    assert_equal [ 'the', :args ], e1.args, "Wrong args"
    assert_equal "hello", e1.block.call, "Wrong block in expectation"

    @control.verify
  end

  def test_add_expectation_then_verify
    e1 = MyExp.new

    @control.add_expectation e1
    assert !@control.happy?, "Shoudn't be happy"
    err = assert_raise VerifyError do
      @control.verify
    end
    assert_match(/unmet expectations/i, err.message) 

    @control.apply_method_call @unmock, 'some_func', [ 'the', :args ], nil
    assert @control.happy?
    
    assert_same @unmock, e1.mock, "Wrong mock"
    assert_equal 'some_func', e1.mname, "Wrong method"
    assert_equal [ 'the', :args ], e1.args, "Wrong args"

    @control.verify
  end

  def test_expectation_explosion
    be1 = BoomExp.new

    @control.add_expectation be1

    err = assert_raise RuntimeError do
      @control.apply_method_call @unmock, 'a func', [:arg], nil
    end
    assert_match(/BOOM/i, err.message) 

    assert_same @unmock, be1.mock
    assert_equal 'a func', be1.mname
    assert_equal [:arg], be1.args
  end

  def test_disappointment_on_bad_verify
    @control.add_expectation MyExp.new
    assert !@control.happy?, "Shouldn't be happy"
    assert !@control.disappointed?, "too early to be disappointed"

    # See verify fails
    err = assert_raise VerifyError do
      @control.verify
    end
    assert_match(/unmet expectations/i, err.message) 

    assert !@control.happy?, "Still have unmet expectation"
    assert @control.disappointed?, "We should be disappointed following that failure"

    @control.apply_method_call @unmock, 'something', [], nil
    assert @control.happy?, "Should be happy"
    assert @control.disappointed?, "We should be skeptical"

    @control.verify

    assert !@control.disappointed?, "Should be non-disappointed"
  end

  def test_disappointment_from_surprise_calls
    assert @control.happy?, "Should be happy"
    assert !@control.disappointed?, "too early to be disappointed"

    # See verify fails
    err = assert_raise ExpectationError do
      @control.apply_method_call @unmock, "something", [], nil
    end
    assert_match(/surprise/i, err.message) 

    assert @control.happy?, "Happiness is an empty list of expectations"
    assert @control.disappointed?, "We should be disappointed following that failure"

    @control.verify
    assert !@control.disappointed?, "Disappointment should be gone"
  end

  def test_disappointment_from_bad_calls
    be1 = BoomExp.new
    assert !@control.disappointed?, "Shouldn't be disappointed"
    @control.add_expectation be1
    assert !@control.disappointed?, "Shouldn't be disappointed"

    err = assert_raise RuntimeError do
      @control.apply_method_call @unmock, 'a func', [:arg], nil
    end
    assert_match(/BOOM/i, err.message) 
    assert @control.disappointed?, "Should be disappointed"

    assert_same @unmock, be1.mock
    assert_equal 'a func', be1.mname
    assert_equal [:arg], be1.args

    assert @control.happy?, "Happiness is an empty list of expectations"
    @control.verify
    assert !@control.disappointed?, "Disappointment should be gone"
  end


end
