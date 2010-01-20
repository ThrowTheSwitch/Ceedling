require File.expand_path(File.dirname(__FILE__) + "/../test_helper")
require 'hardmock'
require 'assert_error'

class HardmockTest < Test::Unit::TestCase

  #
  # TESTS
  # 

  it "conveniently creates mocks using create_mock and create_mocks" do

    h = create_mock :donkey
    assert_equal [ :donkey ], h.keys

    assert_mock_exists :donkey
    assert_same @donkey, h[:donkey]

    assert_equal [ :donkey ], @all_mocks.keys, "Wrong keyset for @all_mocks"

    h2 = create_mocks :cat, 'dog' # symbol/string indifference at this level
    assert_equal [:cat,:dog].to_set, h2.keys.to_set, "Wrong keyset for second hash"
    assert_equal [:cat,:dog,:donkey].to_set, @all_mocks.keys.to_set, "@all_mocks wrong"   

    assert_mock_exists :cat
    assert_same @cat, h2[:cat]
    assert_mock_exists :dog
    assert_same @dog, h2[:dog]

    assert_mock_exists :donkey
  end

  it "provides literal 'expects' syntax" do 
    assert_nil @order, "Should be no @order yet"
    create_mock :order
    assert_not_nil @order, "@order should be built"

    # Setup an expectation
    @order.expects.update_stuff :key1 => 'val1', :key2 => 'val2'

    # Use the mock
    @order.update_stuff :key1 => 'val1', :key2 => 'val2'

    # Verify
    verify_mocks

    # See that it's ok to do it again
    verify_mocks
  end

  it "supports 'with' for specifying argument expectations" do
    create_mocks :car
    @car.expects(:fill).with('gas','booze')
    @car.fill('gas', 'booze')
    verify_mocks
  end

  it "supports several mocks at once" do
    create_mocks :order_builder, :order, :customer

    @order_builder.expects.create_new_order.returns @order
    @customer.expects.account_number.returns(1234)
    @order.expects.account_no = 1234
    @order.expects.save!

    # Run "the code"
    o = @order_builder.create_new_order
    o.account_no = @customer.account_number
    o.save!

    verify_mocks
  end

  it "enforces inter-mock call ordering" do
    create_mocks :order_builder, :order, :customer

    @order_builder.expects.create_new_order.returns @order
    @customer.expects.account_number.returns(1234)
    @order.expects.account_no = 1234
    @order.expects.save!

    # Run "the code"
    o = @order_builder.create_new_order
    err = assert_raise ExpectationError do
      o.save!
    end
    assert_match(/wrong object/i, err.message) 
    assert_match(/order.save!/i, err.message) 
    assert_match(/customer.account_number/i, err.message) 

    assert_error VerifyError, /unmet expectations/i do
      verify_mocks
    end
  end

  class UserPresenter
    def initialize(args)
      view = args[:view]
      model = args[:model]
      model.when :data_changes do
        view.user_name = model.user_name
      end
      view.when :user_edited do
        model.user_name = view.user_name
      end
    end
  end

  it "makes MVP testing simple" do
    mox = create_mocks :model, :view

    data_change = @model.expects.when(:data_changes) { |evt,block| block }
    user_edit = @view.expects.when(:user_edited) { |evt,block| block }
    
    UserPresenter.new mox

    # Expect user name transfer from model to view
    @model.expects.user_name.returns 'Da Croz'
    @view.expects.user_name = 'Da Croz'
    # Trigger data change event in model
    data_change.block_value.call

    # Expect user name transfer from view to model
    @view.expects.user_name.returns '6:8'
    @model.expects.user_name = '6:8'
    # Trigger edit event in view
    user_edit.block_value.call

    verify_mocks 
  end

  it "continues to function after verify, if verification error is controlled" do
    mox = create_mocks :model, :view
    data_change = @model.expects.when(:data_changes) { |evt,block| block }
    user_edit = @view.expects.when(:user_edited) { |evt,block| block }
    UserPresenter.new mox

    # Expect user name transfer from model to view
    @model.expects.user_name.returns 'Da Croz'
    @view.expects.user_name = 'Da Croz'

    assert_error ExpectationError, /model.monkey_wrench/i do
      @model.monkey_wrench
    end

    # This should raise because of unmet expectations
    assert_error VerifyError, /unmet expectations/i, /user_name/i do
      verify_mocks
    end

    # See that the non-forced verification remains quiet
    assert_nothing_raised VerifyError do
      verify_mocks(false)
    end
    
    @model.expects.never_gonna_happen
    
    assert_error VerifyError, /unmet expectations/i, /never_gonna_happen/i do
      verify_mocks
    end
  end

  class UserPresenterBroken
    def initialize(args)
      view = args[:view]
      model = args[:model]
      model.when :data_changes do
        view.user_name = model.user_name
      end
      # no view stuff, will break appropriately
    end
  end

  it "flunks for typical Presenter constructor wiring failure" do
    mox = create_mocks :model, :view

    data_change = @model.expects.when(:data_changes) { |evt,block| block }
    user_edit = @view.expects.when(:user_edited) { |evt,block| block }
    
    UserPresenterBroken.new mox

    err = assert_raise VerifyError do
      verify_mocks
    end
    assert_match(/unmet expectations/i, err.message) 
    assert_match(/view.when\(:user_edited\)/i, err.message) 

  end

  it "provides convenient event-subscription trap syntax for MVP testing" do
    mox = create_mocks :model, :view

    data_change = @model.trap.when(:data_changes) 
    user_edit = @view.trap.when(:user_edited) 
    
    UserPresenter.new mox

    # Expect user name transfer from model to view
    @model.expects.user_name.returns 'Da Croz'
    @view.expects.user_name = 'Da Croz'
    # Trigger data change event in model
    data_change.trigger

    # Expect user name transfer from view to model
    @view.expects.user_name.returns '6:8'
    @model.expects.user_name = '6:8'
    # Trigger edit event in view
    user_edit.trigger

    verify_mocks 
  end

  it "raises if you try to pass an expectation block to 'trap'" do
    create_mock :model
    assert_error Hardmock::ExpectationError, /blocks/i, /trap/i do
      @model.trap.when(:some_event) do raise "huh?" end
    end
  end

  class Grinder
    def initialize(objects)
      @chute = objects[:chute]
      @bucket = objects[:bucket]
      @blade = objects[:blade]
    end

    def grind(slot)
      @chute.each_bean(slot) do |bean|
        @bucket << @blade.chop(bean)
      end
    end
  end

  it "lets you write clear iteration-oriented expectations" do
    grinder = Grinder.new create_mocks(:blade, :chute, :bucket)
    
    # Style 1: assertions on method args is done explicitly in block
    @chute.expects.each_bean { |slot,block| 
      assert_equal :side_slot, slot, "Wrong slot"
      block.call :bean1
      block.call :bean2
    }

    @blade.expects.chop(:bean1).returns(:grounds1)
    @bucket.expects('<<', :grounds1)

    @blade.expects.chop(:bean2).returns(:grounds2)
    @bucket.expects('<<', :grounds2)

    # Run "the code"
    grinder.grind(:side_slot)

    verify_mocks

    # Style 2: assertions on method arguments done implicitly in the expectation code
    @chute.expects.each_bean(:main_slot) { |slot,block| 
      block.call :bean3
    }
    @blade.expects.chop(:bean3).returns(:grounds3)
    @bucket.expects('<<', :grounds3)
    grinder.grind :main_slot
    verify_mocks
  end

  it "further supports iteration testing using 'yield'" do
    grinder = Grinder.new create_mocks(:blade, :chute, :bucket)
    
    @chute.expects.each_bean(:side_slot).yields :bean1, :bean2

    @blade.expects.chop(:bean1).returns(:grounds1)
    @bucket.expects('<<', :grounds1)

    @blade.expects.chop(:bean2).returns(:grounds2)
    @bucket.expects('<<', :grounds2)

    grinder.grind :side_slot

    verify_mocks
  end

  class HurtLocker
    attr_reader :caught
    def initialize(opts)
      @locker = opts[:locker]
      @store = opts[:store]
    end

    def do_the_thing(area,data)
      @locker.with_lock(area) do
        @store.eat(data)
      end
    rescue => oops
      @caught = oops
    end
  end

  it "makes mutex-style locking scenarios easy to test" do
    hurt = HurtLocker.new create_mocks(:locker, :store)

    @locker.expects.with_lock(:main).yields
    @store.expects.eat("some info")

    hurt.do_the_thing(:main, "some info")

    verify_mocks
  end

  it "makes it easy to simulate error in mutex-style locking scenarios" do 
    hurt = HurtLocker.new create_mocks(:locker, :store)
    err = StandardError.new('fmshooop')  
    @locker.expects.with_lock(:main).yields
    @store.expects.eat("some info").raises(err)

    hurt.do_the_thing(:main, "some info")

    assert_same err, hurt.caught, "Expected that error to be handled internally"
    verify_mocks
  end
	
  it "actually returns 'false' instead of nil when mocking boolean return values" do
		create_mock :car
		@car.expects.ignition_on?.returns(true)
		assert_equal true, @car.ignition_on?, "Should be true"
		@car.expects.ignition_on?.returns(false)
		assert_equal false, @car.ignition_on?, "Should be false"
	end

  it "can mock most methods inherited from object using literal syntax" do
    target_methods = %w|id clone display dup eql? ==|
    create_mock :foo
    target_methods.each do |m|
      eval %{@foo.expects(m, "some stuff")}
      eval %{@foo.#{m} "some stuff"}
    end
  end

  it "provides 'expect' as an alias for 'expects'" do
    create_mock :foo
    @foo.expect.boomboom
    @foo.boomboom
    verify_mocks 
  end

  it "provides 'should_receive' as an alias for 'expects'" do
    create_mock :foo
    @foo.should_receive.boomboom
    @foo.boomboom
    verify_mocks 
  end

  it "provides 'and_return' as an alias for 'returns'" do
    create_mock :foo
    @foo.expects(:boomboom).and_return :brick
    assert_equal :brick, @foo.boomboom
    verify_mocks 
  end

  it "does not interfere with a core subset of Object methods" do 
    create_mock :foo
    @foo.method(:inspect)
    @foo.inspect
    @foo.to_s
    @foo.instance_variables
    @foo.instance_eval("")
    verify_mocks 
  end

  it "can raise errors from within an expectation block" do
    create_mock :cat
    @cat.expects.meow do |arg|
      assert_equal "mix", arg
      raise 'HAIRBALL'
    end
    assert_error RuntimeError, 'HAIRBALL' do 
      @cat.meow("mix")
    end
  end

  it "can raise errors AFTER an expectation block" do
    create_mock :cat
    @cat.expects.meow do |arg|
      assert_equal "mix", arg
    end.raises('HAIRBALL')
    assert_error RuntimeError, 'HAIRBALL' do 
      @cat.meow("mix")
    end
  end

  it "raises an immediate error if a mock is created with a nil name (common mistake: create_mock @cat)" do
    # I make this mistake all the time: Typing in an instance var name instead of a symbol in create_mocks.
    # When you do that, you're effectively passing nil(s) in as mock names.
    assert_error ArgumentError, /'nil' is not a valid name for a mock/ do
      create_mocks @apples, @oranges
    end
  end

  it "overrides 'inspect' to make nice output" do
    create_mock :hay_bailer
    assert_equal "<Mock hay_bailer>", @hay_bailer.inspect, "Wrong output from 'inspect'"
  end

  it "raises if prepare_hardmock_control is invoked after create_mocks, or more than once" do
    create_mock :hi_there
    create_mocks :another, :one
    assert_error RuntimeError, /already setup/ do
      prepare_hardmock_control
    end
  end

  should "support alias verify_hardmocks" do
    create_mock :tree
    @tree.expects(:grow)
    assert_error VerifyError, /unmet/i do
      verify_hardmocks
    end
  end

  #
  # HELPERS
  #

  def assert_mock_exists(name)
    assert_not_nil @all_mocks, "@all_mocks not here yet"
    mo = @all_mocks[name]
    assert_not_nil mo, "Mock '#{name}' not in @all_mocks"
    assert_kind_of Mock, mo, "Wrong type of object, wanted a Mock"
    assert_equal name.to_s, mo._name, "Mock '#{name}' had wrong name"
    ivar = self.instance_variable_get("@#{name}")
    assert_not_nil ivar, "Mock '#{name}' not set as ivar"
    assert_same mo, ivar, "Mock '#{name}' ivar not same as instance in @all_mocks"
    assert_same @main_mock_control, mo._control, "Mock '#{name}' doesn't share the main mock control"
  end
end

