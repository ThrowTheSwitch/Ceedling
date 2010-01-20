require File.expand_path(File.dirname(__FILE__) + "/../test_helper")
require 'hardmock/method_cleanout'
require 'hardmock/mock'
require 'hardmock/mock_control'
require 'hardmock/expectation_builder'
require 'hardmock/expector'
require 'hardmock/trapper'

class MockTest < Test::Unit::TestCase
  include Hardmock

  def test_build_with_control
    mc1 = MockControl.new
    mock = Mock.new('hi', mc1)
    assert_equal 'hi', mock._name, "Wrong name"
    assert_same mc1, mock._control, "Wrong contol"
  end

  def test_basics
    mock = Mock.new('a name')
    assert_equal 'a name', mock._name, "Wrong name for mock"
    assert_not_nil mock._control, "Nil control in mock"
  end

  def test_expects
    mock = Mock.new('order')
    control = mock._control
    assert control.happy?, "Mock should start out satisfied"

    mock.expects.absorb_something(:location, 'garbage')
    assert !control.happy?, "mock control should be unhappy"

    # Do the call
    mock.absorb_something(:location, 'garbage')
    assert control.happy?, "mock control should be happy again"

    # Verify
    assert_nothing_raised Exception do
      mock._verify
    end 
  end

  def test_expects_using_arguments_for_method_and_arguments
    mock = Mock.new('order')
    mock.expects(:absorb_something, :location, 'garbage')
    mock.absorb_something(:location, 'garbage')
    mock._verify
  end

  def test_expects_using_arguments_for_method_and_arguments_with_block
    mock = Mock.new('order')
    mock.expects(:absorb_something, :location, 'garbage') { |a,b,block|
      assert_equal :location, a, "Wrong 'a' argument"
      assert_equal 'garbage', b, "Wrong 'b' argument"
      assert_equal 'innards', block.call, "Wrong block"
    }
    mock.absorb_something(:location, 'garbage') do "innards" end
    mock._verify
  end

  def test_expects_using_string_method_name
    mock = Mock.new('order')
    mock.expects('absorb_something', :location, 'garbage')
    mock.absorb_something(:location, 'garbage')
    mock._verify
  end


  def test_expects_assignment
    mock = Mock.new('order')
    mock.expects.account_number = 1234

    mock.account_number = 1234

    mock._verify
  end

  def test_expects_assigment_using_arguments_for_method_and_arguments
    mock = Mock.new('order')
    mock.expects(:account_number=, 1234)
    mock.account_number = 1234
    mock._verify
  end

  def test_expects_assigment_using_string_method_name
    mock = Mock.new('order')
    mock.expects('account_number=', 1234)
    mock.account_number = 1234
    mock._verify
  end

  def test_expects_assignment_and_return_is_overruled_by_ruby_syntax
    # Prove that we can set up a return but that it doesn't mean much,
    # because ruby's parser will 'do the right thing' as regards semantic
    # values for assignment.  (That is, the rvalue of the assignment)
    mock = Mock.new('order')
    mock.expects(:account_number=, 1234).returns "gold"
    got = mock.account_number = 1234
    mock._verify
    assert_equal 1234, got, "Expected rvalue"
  end

  def test_expects_assignment_and_raise
    mock = Mock.new('order')
    mock.expects(:account_number=, 1234).raises StandardError.new("kaboom")
    err = assert_raise StandardError do
      mock.account_number = 1234
    end
    assert_match(/kaboom/i, err.message) 
    mock._verify
  end


  def test_expects_multiple
    mock = Mock.new('order')
    control = mock._control

    assert control.happy?

    mock.expects.one_thing :hi, { :goose => 'neck' }
    mock.expects.another 5,6,7
    assert !control.happy?

    mock.one_thing :hi, { :goose => 'neck' }
    assert !control.happy?

    mock.another 5,6,7
    assert control.happy?
  end

  def test_surprise_call
    mock = Mock.new('order')
    err = assert_raise ExpectationError do
      mock.uh_oh
    end
    assert_match(/surprise/i, err.message) 
    assert_match(/uh_oh/i, err.message) 
    
    err = assert_raise ExpectationError do
      mock.whoa :horse  
    end
    assert_match(/surprise/i, err.message) 
    assert_match(/order\.whoa\(:horse\)/i, err.message) 
  end

  def test_wrong_call
    mock = Mock.new('order')
    mock.expects.pig 'arse'
    err = assert_raise ExpectationError do
      mock.whoa :horse  
    end
    assert_match(/wrong method/i, err.message) 
    assert_match(/order\.whoa\(:horse\)/i, err.message) 
    assert_match(/order\.pig\("arse"\)/i, err.message) 
  end

  def test_wrong_arguments
    mock = Mock.new('order')
    mock.expects.go_fast(:a, 1, 'three')

    err = assert_raise ExpectationError do
      mock.go_fast :a, 1, 'not right'  
    end
    assert_match(/wrong argument/i, err.message) 
    assert_match(/order\.go_fast\(:a, 1, "three"\)/i, err.message) 
    assert_match(/order\.go_fast\(:a, 1, "not right"\)/i, err.message) 
  end

  def test_expects_and_return
    mock = Mock.new('order')
    mock.expects.delivery_date.returns Date.today
    assert_equal Date.today, mock.delivery_date
    mock._verify
  end

  def test_expects_and_return_with_arguments
    mock = Mock.new('order')
    mock.expects.delivery_date(:arf,14).returns(Date.today)
    assert_equal Date.today, mock.delivery_date(:arf,14)
    mock._verify
  end

  def test_expects_and_raise
    mock = Mock.new('order')
    mock.expects.delivery_date.raises StandardError.new("bloof")

    err = assert_raise StandardError do
      mock.delivery_date
    end
    assert_match(/bloof/i, err.message) 

    mock._verify
    
    # Try convenience argument String 
    mock.expects.pow.raises "hell"
    err = assert_raise RuntimeError do
      mock.pow
    end
    assert_match(/hell/i, err.message) 

    mock._verify

    # Try convenience argument nothing
    mock.expects.pow.raises 
    err = assert_raise RuntimeError do
      mock.pow
    end
    assert_match(/an error/i, err.message) 

    mock._verify
  end

  def test_expects_a_runtime_block
    mock = Mock.new('order')
    got_val = nil

    mock.expects.when(:something) { |e,block|
      got_val = block.call
    }

    mock.when :something do "hi there" end

    assert_equal "hi there", got_val, "Expectation block not invoked"
    mock._verify
  end

  def test_trap_block
    mock = Mock.new('order')
    exp = mock.trap.observe

    # use it
    mock.observe { "burp" }

    assert_equal "burp", exp.block_value.call
  end

  def test_trap_arguments_and_block
    mock = Mock.new('order')
    exp = mock.trap.subscribe(:data_changed)

    # use it
    mock.subscribe(:data_changed) { "burp" }
    assert_equal "burp", exp.block_value.call
    mock._verify
  end

  def test_trap_arguments_and_block_wrong_num_args
    mock = Mock.new('order')
    exp = mock.trap.subscribe(:data_changed)

    assert_raise ExpectationError do
      mock.subscribe(:data_changed,1) { "burp" }
    end
    mock._verify
  end

  def test_trap_arguments_and_block_wrong_args
    mock = Mock.new('order')
    exp = mock.trap.subscribe(:data_changed)

    assert_raise ExpectationError do
      mock.subscribe("no good") { "burp" }
    end

    mock._verify
  end

  def test_trap_is_not_leniant_about_arguments
    mock = Mock.new('order')
    exp = mock.trap.subscribe

    assert_raise ExpectationError do
      mock.subscribe("no good") { "burp" }
    end

    mock._verify
  end

end
