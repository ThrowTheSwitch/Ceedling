require File.expand_path(File.dirname(__FILE__) + "/../test_helper")
require 'hardmock'

class DirectMockUsageTest < Test::Unit::TestCase

  def setup
    @bird = Mock.new('bird')
  end

  def teardown
  end

  #
  # TESTS
  #

  it "raises VerifyError if expected method not called" do
    @bird.expects.flap_flap

    err = assert_raise VerifyError do
      @bird._verify
    end
    assert_match(/unmet expectations/i, err.message)
  end

  should "not raise when expected calls are made in order" do
    @bird.expects.flap_flap
    @bird.expects.bang
    @bird.expects.plop

    @bird.flap_flap
    @bird.bang
    @bird.plop

    @bird._verify
  end

  it "raises ExpectationError when unexpected method are called" do
    @bird.expects.flap_flap

    err = assert_raise ExpectationError do
      @bird.shoot
    end
    assert_match(/wrong method/i, err.message) 
  end

  it "raises ExpectationError on bad arguments" do
    @bird.expects.flap_flap(:swoosh)

    err = assert_raise ExpectationError do
      @bird.flap_flap(:rip)
    end
    assert_match(/wrong arguments/i, err.message) 
  end
  
  it "raises VerifyError when not all expected methods are called" do
    @bird.expects.flap_flap
    @bird.expects.bang
    @bird.expects.plop

    @bird.flap_flap

    err = assert_raise VerifyError do
      @bird._verify
    end
    assert_match(/unmet expectations/i, err.message)
  end

  it "raises ExpectationError when calls are made out of order" do
    @bird.expects.flap_flap
    @bird.expects.bang
    @bird.expects.plop

    @bird.flap_flap
    err = assert_raise ExpectationError do
      @bird.plop
    end
    assert_match(/wrong method/i, err.message) 
  end

  it "returns the configured value" do 
    @bird.expects.plop.returns(':P')
    assert_equal ':P', @bird.plop
    @bird._verify

    @bird.expects.plop.returns(':x')
    assert_equal ':x', @bird.plop
    @bird._verify
  end

  it "returns nil when no return is specified" do
    @bird.expects.plop
    assert_nil @bird.plop
    @bird._verify
  end

  it "raises the configured exception" do
    err = RuntimeError.new('shaq')
    @bird.expects.plop.raises(err)
    actual_err = assert_raise RuntimeError do
      @bird.plop
    end
    assert_same err, actual_err, 'should be the same error'
    @bird._verify
  end

  it "raises a RuntimeError when told to 'raise' a string" do
    @bird.expects.plop.raises('shaq')
    err = assert_raise RuntimeError do
      @bird.plop
    end
    assert_match(/shaq/i, err.message) 
    @bird._verify
  end

  it "raises a default RuntimeError" do
    @bird.expects.plop.raises
    err = assert_raise RuntimeError do
      @bird.plop
    end
    assert_match(/error/i, err.message) 
    @bird._verify
  end

  it "is quiet when correct arguments given" do
    thing = Object.new
    @bird.expects.plop(:big,'one',thing)
    @bird.plop(:big,'one',thing)
    @bird._verify
  end

  it "raises ExpectationError when wrong number of arguments specified" do
    thing = Object.new
    @bird.expects.plop(:big,'one',thing)
    err = assert_raise ExpectationError do
      # more
      @bird.plop(:big,'one',thing,:other)
    end
    assert_match(/wrong arguments/i, err.message)
    @bird._verify

    @bird.expects.plop(:big,'one',thing)
    err = assert_raise ExpectationError do
      # less
      @bird.plop(:big,'one')
    end
    assert_match(/wrong arguments/i, err.message)
    @bird._verify
    
    @bird.expects.plop
    err = assert_raise ExpectationError do
      # less
      @bird.plop(:big)
    end
    assert_match(/wrong arguments/i, err.message)
    @bird._verify
  end

  it "raises ExpectationError when arguments don't match" do
    thing = Object.new
    @bird.expects.plop(:big,'one',thing)
    err = assert_raise ExpectationError do
      @bird.plop(:big,'two',thing,:other)
    end
    assert_match(/wrong arguments/i, err.message)
    @bird._verify
  end

  it "can use a block for custom reactions" do
    mitt = nil
    @bird.expects.plop { mitt = :ball }
    assert_nil mitt
    @bird.plop
    assert_equal :ball, mitt, 'didnt catch the ball'
    @bird._verify

    @bird.expects.plop { raise 'ball' }
    err = assert_raise RuntimeError do
      @bird.plop
    end
    assert_match(/ball/i, err.message) 
    @bird._verify
  end

  it "passes mock-call arguments to the expectation block" do
    ball = nil
    mitt = nil
    @bird.expects.plop {|arg1,arg2| 
      ball = arg1  
      mitt = arg2  
    }
    assert_nil ball
    assert_nil mitt
    @bird.plop(:ball,:mitt)
    assert_equal :ball, ball
    assert_equal :mitt, mitt
    @bird._verify
  end

  it "validates arguments if specified in addition to a block" do
    ball = nil
    mitt = nil
    @bird.expects.plop(:ball,:mitt) {|arg1,arg2| 
      ball = arg1  
      mitt = arg2  
    }
    assert_nil ball
    assert_nil mitt
    @bird.plop(:ball,:mitt)
    assert_equal :ball, ball
    assert_equal :mitt, mitt
    @bird._verify

    ball = nil
    mitt = nil
    @bird.expects.plop(:bad,:stupid) {|arg1,arg2| 
      ball = arg1  
      mitt = arg2  
    }
    assert_nil ball
    assert_nil mitt
    err = assert_raise ExpectationError do
      @bird.plop(:ball,:mitt)
    end
    assert_match(/wrong arguments/i, err.message) 
    assert_nil ball
    assert_nil mitt
    @bird._verify

    ball = nil
    mitt = nil
    @bird.expects.plop(:ball,:mitt) {|arg1,arg2| 
      ball = arg1  
      mitt = arg2  
    }
    assert_nil ball
    assert_nil mitt
    err = assert_raise ExpectationError do
      @bird.plop(:ball)
    end
    assert_match(/wrong arguments/i, err.message) 
    assert_nil ball
    assert_nil mitt
    @bird._verify
  end

  it "passes runtime blocks to the expectation block as the final argument" do
    runtime_block_called = false
    got_arg = nil

    # Eg, bird expects someone to subscribe to :tweet using the 'when' method
    @bird.expects.when(:tweet) { |arg1, block| 
      got_arg = arg1
      block.call
    }

    @bird.when(:tweet) do 
      runtime_block_called = true
    end

    assert_equal :tweet, got_arg, "Wrong arg"
    assert runtime_block_called, "The runtime block should have been invoked by the user block"

    @bird.expects.when(:warnk) { |e,blk| }

    err = assert_raise ExpectationError do
      @bird.when(:honk) { }
    end
    assert_match(/wrong arguments/i, err.message) 

    @bird._verify
  end

  it "passes the runtime block to the expectation block as sole argument if no other args come into play" do
    runtime_block_called = false
    @bird.expects.subscribe { |block| block.call }
    @bird.subscribe do 
      runtime_block_called = true
    end
    assert runtime_block_called, "The runtime block should have been invoked by the user block"
  end

  it "provides nil as final argument if expectation block seems to want a block" do
    invoked = false
    @bird.expects.kablam(:scatter) { |shot,block| 
      assert_equal :scatter, shot, "Wrong shot"
      assert_nil block, "The expectation block should get a nil block when user neglects to pass one"
      invoked = true
    }
    @bird.kablam :scatter
    assert invoked, "Expectation block not invoked"

    @bird._verify
  end

  it "can set explicit return after an expectation block" do
    got = nil
    @bird.expects.kablam(:scatter) { |shot|
      got = shot
    }.returns(:death)

    val = @bird.kablam :scatter 
    assert_equal :death, val, "Wrong return value"
    assert_equal :scatter, got, "Wrong argument"
    @bird._verify
  end

  it "can raise after an expectation block" do
    got = nil
    @bird.expects.kablam(:scatter) do |shot|
      got = shot
    end.raises "hell"

    err = assert_raise RuntimeError do
      @bird.kablam :scatter 
    end
    assert_match(/hell/i, err.message) 

    @bird._verify
  end

  it "stores the semantic value of the expectation block after it executes" do
    expectation = @bird.expects.kablam(:slug) { |shot|
      "The shot was #{shot}"
    }

    assert_not_nil expectation, "Expectation nil"
    assert_nil expectation.block_value, "Block value should start out nil"

    ret_val = @bird.kablam :slug 

    assert_equal "The shot was slug", expectation.block_value
    assert_equal "The shot was slug", ret_val, "Block value should also be used for return"

    @bird._verify
  end


  it "uses the value of the expectation block as the default return value" do 
    @bird.expects.kablam(:scatter) { |shot|
      "The shot was #{shot}"
    }
    val = @bird.kablam :scatter 
    assert_equal "The shot was scatter", val, "Wrong return value"
    @bird._verify
  end

  it "returns the Expectation even if 'returns' is used" do
    expectation = @bird.expects.kablam(:slug) { |shot|
      "The shot was #{shot}"
    }.returns :hosed

    assert_not_nil expectation, "Expectation nil"
    assert_nil expectation.block_value, "Block value should start out nil"

    ret_val = @bird.kablam :slug 

    assert_equal "The shot was slug", expectation.block_value
    assert_equal :hosed, ret_val, "Block value should also be used for return"

    @bird._verify
  end

  it "returns the Expectation even if 'raises' is used" do
    expectation = @bird.expects.kablam(:slug) { |shot|
      "The shot was #{shot}"
    }.raises "aiee!"

    assert_not_nil expectation, "Expectation nil"
    assert_nil expectation.block_value, "Block value should start out nil"

    err = assert_raise RuntimeError do
     @bird.kablam :slug 
    end
    assert_match(/aiee!/i, err.message)
    assert_equal "The shot was slug", expectation.block_value
    @bird._verify
  end


  it "supports assignment-style methods" do
    @bird.expects.size = "large"
    @bird.size = "large"
    @bird._verify
  end

  it "supports assignments and raising (using explicit-method syntax)" do
    @bird.expects('size=','large').raises "boom"

    err = assert_raise RuntimeError do
      @bird.size = "large"
    end
    assert_match(/boom/i, err.message) 
  end

end
