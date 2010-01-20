require File.expand_path(File.dirname(__FILE__) + "/../test_helper")
require 'hardmock/expectation'
require 'hardmock/errors'
require 'assert_error'

class ExpectationTest < Test::Unit::TestCase
  include Hardmock

  def setup
    @mock = TheMock.new
  end
  #
  # HELPERS
  #
   
  class TheMock
    def _name; 'the_mock'; end
  end
  class OtherMock
    def _name; 'other_mock'; end
  end

  #
  # TESTS
  #

  def test_to_s
    ex = Expectation.new( :mock => @mock, :method => 'a_func', :arguments => [1, "two", :three, { :four => 4 }] )  
    assert_equal %|the_mock.a_func(1, "two", :three, {:four=>4})|, ex.to_s
  end
   
  def test_apply_method_call
    se = Expectation.new(:mock => @mock, :method => 'some_func',
      :arguments => [1,'two',:three] )

    # Try it good:
    assert_nothing_raised ExpectationError do
      se.apply_method_call( @mock, 'some_func', [1,'two',:three], nil )
    end 

    # Bad func name:
    err = assert_raise ExpectationError do
      se.apply_method_call( @mock, 'wrong_func', [1,'two',:three], nil )
    end
    assert_match(/wrong method/i, err.message) 
    assert_match(/wrong_func/i, err.message) 
    assert_match(/[1, "two", :three]/i, err.message) 
    assert_match(/some_func/i, err.message) 
    assert_match(/the_mock/i, err.message) 

    # Wrong mock
    err = assert_raise ExpectationError do
      se.apply_method_call( OtherMock.new, 'some_func', [1,'two',:three], nil )
    end
    assert_match(/[1, "two", :three]/i, err.message) 
    assert_match(/some_func/i, err.message) 
    assert_match(/the_mock/i, err.message) 
    assert_match(/other_mock/i, err.message) 
    
    # Wrong args
    err = assert_raise ExpectationError do
      se.apply_method_call( @mock, 'some_func', [1,'two',:four], nil)
    end
    assert_match(/[1, "two", :three]/i, err.message) 
    assert_match(/[1, "two", :four]/i, err.message) 
    assert_match(/wrong arguments/i, err.message) 
    assert_match(/some_func/i, err.message) 
  end

  def test_apply_method_call_should_call_proc_when_given
    # now with a proc
    thinger = nil
    the_proc = Proc.new { thinger = :shaq }
    se = Expectation.new(:mock => @mock, :method => 'some_func',
      :block => the_proc)

    # Try it good:
    assert_nil thinger
    assert_nothing_raised ExpectationError do
      se.apply_method_call(@mock, 'some_func', [], nil)
    end 
    assert_equal :shaq, thinger, 'wheres shaq??'
  end

  def test_apply_method_call_passes_runtime_block_as_last_argument_to_expectation_block

    passed_block = nil
    exp_block_called = false
    exp_block = Proc.new { |blk| 
      exp_block_called = true
      passed_block = blk 
    }

    se = Expectation.new(:mock => @mock, :method => 'some_func', :block => exp_block,
      :arguments => [])

    set_flag = false
    runtime_block = Proc.new { set_flag = true }

    assert_nil passed_block, "Passed block should be nil"
    assert !set_flag, "set_flag should be off"

    # Go
    se.apply_method_call( @mock, 'some_func', [], runtime_block)

    # Examine the passed block
    assert exp_block_called, "Expectation block not called"
    assert_not_nil passed_block, "Should have been passed a block"
    assert !set_flag, "set_flag should still be off"
    passed_block.call
    assert set_flag, "set_flag should be on"
  end

  def test_apply_method_call_fails_when_theres_no_expectation_block_to_handle_the_runtime_block
    se = Expectation.new(:mock => @mock, :method => 'some_func', :arguments => [])
    runtime_block = Proc.new { set_flag = true }
    err = assert_raise ExpectationError do
      se.apply_method_call( @mock, 'some_func', [], runtime_block)
    end
    assert_match(/unexpected block/i, err.message) 
    assert_match(/the_mock.some_func()/i, err.message) 
  end

  def test_returns
    se = Expectation.new(:mock => @mock, :method => 'some_func',
      :arguments => [1,'two',:three])

    se.returns "A value"

    assert_equal "A value", se.apply_method_call(@mock, 'some_func', [1,'two',:three], nil)
  end

  def test_apply_method_call_captures_block_value
    the_proc = lambda { "in the block" }
    se = Expectation.new(:mock => @mock, :method => 'do_it', :arguments => [], :block => the_proc)

    assert_nil se.block_value, "Block value starts out nil"
    
    se.apply_method_call(@mock, 'do_it', [], nil)

    assert_equal "in the block", se.block_value, "Block value not captured"
  end

  def test_trigger
    # convenience method for block_value.call
    target = false
    inner_proc = lambda { target = true }
    the_proc = lambda { inner_proc }
    se = Expectation.new(:mock => @mock, :method => 'do_it', :arguments => [], :block => the_proc)

    assert_nil se.block_value, "Block value starts out nil"
    se.apply_method_call(@mock, 'do_it', [], nil)
    assert_not_nil se.block_value, "Block value not set"

    assert !target, "Target should still be false"
    se.trigger
    assert target, "Target not true!"
  end

  def test_trigger_with_arguments
    # convenience method for block_value.call
    target = nil
    inner_proc = lambda { |one,two| target = [one,two] }
    the_proc = lambda { inner_proc }
    se = Expectation.new(:mock => @mock, :method => 'do_it', :arguments => [], :block => the_proc)

    assert_nil se.block_value, "Block value starts out nil"
    se.apply_method_call(@mock, 'do_it', [], nil)
    assert_not_nil se.block_value, "Block value not set"

    assert_nil target, "target should still be nil"
    se.trigger 'cat','dog'
    assert_equal ['cat','dog'], target
  end

  def test_trigger_nil_block_value
    se = Expectation.new(:mock => @mock, :method => 'do_it', :arguments => [])

    assert_nil se.block_value, "Block value starts out nil"
    se.apply_method_call(@mock, 'do_it', [], nil)
    assert_nil se.block_value, "Block value should still be nil"

    err = assert_raise ExpectationError do
      se.trigger
    end
    assert_match(/do_it/i, err.message) 
    assert_match(/block value/i, err.message) 
  end

  def test_trigger_non_proc_block_value
    the_block = lambda { "woops" }
    se = Expectation.new(:mock => @mock, :method => 'do_it', :arguments => [], :block => the_block)

    se.apply_method_call(@mock, 'do_it', [], nil)
    assert_equal "woops", se.block_value

    err = assert_raise ExpectationError do
      se.trigger
    end
    assert_match(/do_it/i, err.message) 
    assert_match(/trigger/i, err.message) 
    assert_match(/woops/i, err.message) 
  end



  def test_proc_used_for_return
    the_proc = lambda { "in the block" }
    se = Expectation.new(:mock => @mock, :method => 'do_it', :arguments => [], :block => the_proc)

    assert_equal "in the block", se.apply_method_call(@mock, 'do_it', [], nil)
    assert_equal "in the block", se.block_value, "Captured block value affected wrongly"
  end

  def test_explicit_return_overrides_proc_return
    the_proc = lambda { "in the block" }
    se = Expectation.new(:mock => @mock, :method => 'do_it', :arguments => [], :block => the_proc)
    se.returns "the override"
    assert_equal "the override", se.apply_method_call(@mock, 'do_it', [], nil)
    assert_equal "in the block", se.block_value, "Captured block value affected wrongly"
  end

  def test_yields
    se = Expectation.new(:mock => @mock, :method => 'each_bean', :arguments => [:side_slot] )
    se.yields :bean1, :bean2

    things = []
    a_block = lambda { |thinger| things << thinger } 

    se.apply_method_call(@mock,'each_bean',[:side_slot],a_block)
    assert_equal [:bean1,:bean2], things, "Wrong things"
  end

  def test_yields_block_takes_no_arguments
    se = Expectation.new(:mock => @mock, :method => 'each_bean', :arguments => [:side_slot] )
    se.yields

    things = []
    a_block = lambda { things << 'OOF' }
    se.apply_method_call(@mock,'each_bean',[:side_slot],a_block)
    assert_equal ['OOF'], things
  end

  def test_yields_params_to_block_takes_no_arguments
    se = Expectation.new(:mock => @mock, :method => 'each_bean', :arguments => [:side_slot] )
    se.yields :wont_fit

    things = []
    a_block = lambda { things << 'WUP' }

    err = assert_raise ExpectationError do
      se.apply_method_call(@mock,'each_bean',[:side_slot],a_block)
    end
    assert_match(/wont_fit/i, err.message) 
    assert_match(/arity -1/i, err.message) 
    assert_equal [], things, "Wrong things"
  end

  def test_yields_with_returns
    se = Expectation.new(:mock => @mock, :method => 'each_bean', :arguments => [:side_slot] ,
      :returns => 'the results')
    
    exp = se.yields :bean1, :bean2
    assert_same se, exp, "'yields' needs to return a reference to the expectation"
    things = []
    a_block = lambda { |thinger| things << thinger } 
    returned = se.apply_method_call(@mock,'each_bean',[:side_slot],a_block)
    assert_equal [:bean1,:bean2], things, "Wrong things"
    assert_equal 'the results', returned, "Wrong return value"
  end

  def test_yields_with_raises
    se = Expectation.new(:mock => @mock, :method => 'each_bean', :arguments => [:side_slot],
      :raises => RuntimeError.new("kerboom"))
    
    exp = se.yields :bean1, :bean2
    assert_same se, exp, "'yields' needs to return a reference to the expectation"
    things = []
    a_block = lambda { |thinger| things << thinger } 
    err = assert_raise RuntimeError do
      se.apply_method_call(@mock,'each_bean',[:side_slot],a_block)
    end
    assert_match(/kerboom/i, err.message) 
    assert_equal [:bean1,:bean2], things, "Wrong things"
  end

  def test_yields_and_inner_block_explodes
    se = Expectation.new(:mock => @mock, :method => 'each_bean', :arguments => [:side_slot])
    
    exp = se.yields :bean1, :bean2
    assert_same se, exp, "'yields' needs to return a reference to the expectation"
    things = []
    a_block = lambda { |thinger| 
      things << thinger 
      raise "nasty"
    } 
    err = assert_raise RuntimeError do
      se.apply_method_call(@mock,'each_bean',[:side_slot],a_block)
    end
    assert_match(/nasty/i, err.message) 
    assert_equal [:bean1], things, "Wrong things"
  end

  def test_yields_with_several_arrays
    se = Expectation.new(:mock => @mock, :method => 'each_bean', :arguments => [:side_slot] )
    se.yields ['a','b'], ['c','d']

    things = []
    a_block = lambda { |thinger| things << thinger } 

    se.apply_method_call(@mock,'each_bean',[:side_slot],a_block)
    assert_equal [ ['a','b'], ['c','d'] ], things, "Wrong things"
  end

  def test_yields_tuples
    se = Expectation.new(:mock => @mock, :method => 'each_bean', :arguments => [:side_slot] )
    se.yields ['a','b','c'], ['d','e','f']

    things = []
    a_block = lambda { |left,mid,right| 
      things << { :left => left, :mid => mid, :right => right }
    } 

    se.apply_method_call(@mock,'each_bean',[:side_slot],a_block)
    assert_equal [ 
      {:left => 'a', :mid => 'b', :right => 'c' }, 
      {:left => 'd', :mid => 'e', :right => 'f' },
      ], things, "Wrong things"
  end

  def test_yields_tuples_size_mismatch
    se = Expectation.new(:mock => @mock, :method => 'each_bean', :arguments => [:side_slot] )
    se.yields ['a','b','c'], ['d','e','f']

    things = []
    a_block = lambda { |left,mid| 
      things << { :left => left, :mid => mid }
    } 

    err = assert_raise ExpectationError do
      se.apply_method_call(@mock,'each_bean',[:side_slot],a_block)
    end
    assert_match(/arity/i, err.message) 
    assert_match(/the_mock.each_bean/i, err.message) 
    assert_match(/"a", "b", "c"/i, err.message) 
    assert_equal [], things, "Wrong things"
  end

  def test_yields_bad_block_arity
    se = Expectation.new(:mock => @mock, :method => 'do_later', :arguments => [] )
    se.yields

    assert_error Hardmock::ExpectationError, /block/i, /expected/i, /no param/i, /got 2/i do
      se.apply_method_call(@mock,'do_later',[],lambda { |doesnt,match| raise "Surprise!" } )
    end
  end
  
  def test_that_arguments_can_be_added_to_expectation
    expectation = Expectation.new(:mock => @mock, :method => "each_bean")
    assert_same expectation, expectation.with("jello", "for", "cosby"), "should have returned the same expectation"
    
    err = assert_raise ExpectationError do
      expectation.apply_method_call(@mock, 'each_bean', [], nil)
    end
    assert_match(/wrong arguments/i, err.message)
    
    assert_nothing_raised(ExpectationError) do  
      expectation.apply_method_call(@mock, 'each_bean', ["jello", "for", "cosby"], nil)
    end
  end

end
