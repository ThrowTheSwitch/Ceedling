require File.expand_path(File.dirname(__FILE__) + "/../test_helper")
require 'hardmock'
require 'assert_error'

class StubbingTest < Test::Unit::TestCase

  #
  # TESTS
  # 

  it "stubs a class method (and un-stubs after reset_stubs)" do
    assert_equal "stones and gravel", Concrete.pour
    assert_equal "glug glug", Jug.pour

    Concrete.stubs!(:pour).returns("dust and plaster")

    3.times do
      assert_equal "dust and plaster", Concrete.pour
    end

    assert_equal "glug glug", Jug.pour, "Jug's 'pour' method broken"
    assert_equal "stones and gravel", Concrete._hardmock_original_pour, "Original 'pour' method not aliased"

    assert_equal "For roads", Concrete.describe, "'describe' method broken"

    reset_stubs

    assert_equal "stones and gravel", Concrete.pour, "'pour' method not restored"
    assert_equal "For roads", Concrete.describe, "'describe' method broken after verify"

  end

  it "stubs several class methods" do
    Concrete.stubs!(:pour).returns("sludge")
    Concrete.stubs!(:describe).returns("awful")
    Jug.stubs!(:pour).returns("milk")

    assert_equal "sludge", Concrete.pour
    assert_equal "awful", Concrete.describe
    assert_equal "milk", Jug.pour

    reset_stubs

    assert_equal "stones and gravel", Concrete.pour
    assert_equal "For roads", Concrete.describe
    assert_equal "glug glug", Jug.pour
  end

  it "stubs instance methods" do
    slab = Concrete.new
    assert_equal "bonk", slab.hit

    slab.stubs!(:hit).returns("slap")
    assert_equal "slap", slab.hit, "'hit' not stubbed"

    reset_stubs

    assert_equal "bonk", slab.hit, "'hit' not restored"
  end

  it "stubs instance methods without breaking class methods or other instances" do
    slab = Concrete.new
    scrape = Concrete.new
    assert_equal "an instance", slab.describe
    assert_equal "an instance", scrape.describe
    assert_equal "For roads", Concrete.describe

    slab.stubs!(:describe).returns("new instance describe")
    assert_equal "new instance describe", slab.describe, "'describe' on instance not stubbed"
    assert_equal "an instance", scrape.describe, "'describe' on 'scrape' instance broken"
    assert_equal "For roads", Concrete.describe, "'describe' class method broken"

    reset_stubs

    assert_equal "an instance", slab.describe, "'describe' instance method not restored"
    assert_equal "an instance", scrape.describe, "'describe' on 'scrape' instance broken after restore"
    assert_equal "For roads", Concrete.describe, "'describe' class method broken after restore"
  end

  should "allow stubbing of nonexistant class methods" do
    Concrete.stubs!(:funky).returns('juice')
    assert_equal 'juice', Concrete.funky
  end

  should "allow stubbing of nonexistant instance methods" do
    chunk = Concrete.new
    chunk.stubs!(:shark).returns('bite')
    assert_equal 'bite', chunk.shark
  end

  should "allow re-stubbing" do
    Concrete.stubs!(:pour).returns("one")
    assert_equal "one", Concrete.pour

    Concrete.stubs!(:pour).raises("hell")
    assert_error RuntimeError, /hell/ do
      Concrete.pour
    end

    Concrete.stubs!(:pour).returns("two")
    assert_equal "two", Concrete.pour

    reset_stubs

    assert_equal "stones and gravel", Concrete.pour
  end

  it "does nothing with a runtime block when simply stubbing" do
    slab = Concrete.new
    slab.stubs!(:hit) do |nothing|
      raise "BOOOMM!"
    end
    slab.hit
    reset_stubs
  end

  it "can raise errors from a stubbed method" do
    Concrete.stubs!(:pour).raises(StandardError.new("no!"))
    assert_error StandardError, /no!/ do
      Concrete.pour
    end
  end

  it "provides string syntax for convenient raising of RuntimeErrors" do
    Concrete.stubs!(:pour).raises("never!")
    assert_error RuntimeError, /never!/ do
      Concrete.pour
    end
  end


  #
  # Per-method mocking on classes or instances
  #

  it "mocks specific methods on existing classes, and returns the class method to normal after verification" do
    
    assert_equal "stones and gravel", Concrete.pour, "Concrete.pour is already messed up"

    Concrete.expects!(:pour).returns("ALIGATORS")
    assert_equal "ALIGATORS", Concrete.pour

    verify_mocks
    assert_equal "stones and gravel", Concrete.pour, "Concrete.pour not restored"
  end
   
  it "flunks if expected class method is not invoked" do
    
    Concrete.expects!(:pour).returns("ALIGATORS")
    assert_error(Hardmock::VerifyError, /Concrete.pour/, /unmet expectations/i) do
      verify_mocks
    end
    clear_expectations
  end

  it "supports all normal mock functionality for class methods" do
    
    Concrete.expects!(:pour, "two tons").returns("mice")
    Concrete.expects!(:pour, "three tons").returns("cats")
    Concrete.expects!(:pour, "four tons").raises("Can't do it")
    Concrete.expects!(:pour) do |some, args|
      "==#{some}+#{args}=="
    end

    assert_equal "mice", Concrete.pour("two tons")
    assert_equal "cats", Concrete.pour("three tons")
    assert_error(RuntimeError, /Can't do it/) do 
      Concrete.pour("four tons")
    end
    assert_equal "==first+second==", Concrete.pour("first","second")
  end


  it "enforces inter-mock ordering when mocking class methods" do
    create_mocks :truck, :foreman
    
    @truck.expects.backup
    Concrete.expects!(:pour, "something")
    @foreman.expects.shout

    @truck.backup
    assert_error Hardmock::ExpectationError, /wrong/i, /expected call/i, /Concrete.pour/ do
      @foreman.shout
    end
    assert_error Hardmock::VerifyError, /unmet expectations/i, /foreman.shout/ do
      verify_mocks
    end
    clear_expectations
  end

  should "allow mocking non-existant class methods" do
    Concrete.expects!(:something).returns("else")
    assert_equal "else", Concrete.something
  end

  it "mocks specific methods on existing instances, then restore them after verify" do
    
    slab = Concrete.new
    assert_equal "bonk", slab.hit

    slab.expects!(:hit).returns("slap")
    assert_equal "slap", slab.hit, "'hit' not stubbed"

    verify_mocks
    assert_equal "bonk", slab.hit, "'hit' not restored"
  end

  it "flunks if expected instance method is not invoked" do
    
    slab = Concrete.new
    slab.expects!(:hit)

    assert_error Hardmock::VerifyError, /unmet expectations/i, /Concrete.hit/ do
      verify_mocks
    end
    clear_expectations
  end

  it "supports all normal mock functionality for instance methods" do
    
    slab = Concrete.new

    slab.expects!(:hit, "soft").returns("hey")
    slab.expects!(:hit, "hard").returns("OOF")
    slab.expects!(:hit).raises("stoppit")
    slab.expects!(:hit) do |some, args|
      "==#{some}+#{args}=="
    end

    assert_equal "hey", slab.hit("soft")
    assert_equal "OOF", slab.hit("hard")
    assert_error(RuntimeError, /stoppit/) do 
      slab.hit
    end
    assert_equal "==first+second==", slab.hit("first","second")
    
  end

  it "enforces inter-mock ordering when mocking instance methods" do
    create_mocks :truck, :foreman
    slab1 = Concrete.new
    slab2 = Concrete.new

    @truck.expects.backup
    slab1.expects!(:hit)
    @foreman.expects.shout
    slab2.expects!(:hit)
    @foreman.expects.whatever

    @truck.backup
    slab1.hit
    @foreman.shout
    assert_error Hardmock::ExpectationError, /wrong/i, /expected call/i, /Concrete.hit/ do
      @foreman.whatever
    end
    assert_error Hardmock::VerifyError, /unmet expectations/i, /foreman.whatever/ do
      verify_mocks
    end
    clear_expectations
  end

  should "allow mocking non-existant instance methods" do
    slab = Concrete.new
    slab.expects!(:wholly).returns('happy')
    assert_equal 'happy', slab.wholly
  end

  should "support concrete expectations that deal with runtime blocks" do

    Concrete.expects!(:pour, "a lot") do |how_much, block|
      assert_equal "a lot", how_much, "Wrong how_much arg"
      assert_not_nil block, "nil runtime block"
      assert_equal "the block value", block.call, "Wrong runtime block value"
    end

    Concrete.pour("a lot") do
      "the block value"
    end

  end

  it "can stub methods on mock objects" do
    create_mock :horse
    @horse.stubs!(:speak).returns("silence")
    @horse.stubs!(:hello).returns("nothing")
    @horse.expects(:canter).returns("clip clop")

    assert_equal "silence", @horse.speak
    assert_equal "clip clop", @horse.canter
    assert_equal "silence", @horse.speak
    assert_equal "silence", @horse.speak
    assert_equal "nothing", @horse.hello
    assert_equal "nothing", @horse.hello

    verify_mocks
    reset_stubs
  end
  
  it "can stub the new method and return values" do
    Concrete.stubs!(:new).returns("this value")
    assert_equal "this value", Concrete.new, "did not properly stub new class method"
    reset_stubs
  end
  
  it "can mock the new method and return values" do
    Concrete.expects!(:new).with("foo").returns("hello")
    Concrete.expects!(:new).with("bar").returns("world")
    
    assert_equal "hello", Concrete.new("foo"), "did not properly mock out new class method"
    assert_equal "world", Concrete.new("bar"), "did not properly mock out new class method"
    
    verify_mocks
    reset_stubs
  end

  it "can mock several different class methods at once" do
    sim_code = lambda do |input|
      record = Multitool.find_record(input)
      report = Multitool.generate_report(record)
      Multitool.format_output(report)
    end

    @identifier = "the id"
    @record = "the record"
    @report = "the report"
    @output = "the output"

    Multitool.expects!(:find_record).with(@identifier).returns(@record)
    Multitool.expects!(:generate_report).with(@record).returns(@report)
    Multitool.expects!(:format_output).with(@report).returns(@output)

    result = sim_code.call(@identifier)
    assert_equal @output, result, "Wrong output"
  end

  it "can handle a mix of different and repeat class method mock calls" do
    prep = lambda {
      Multitool.expects!(:find_record).with("A").returns("1")
      Multitool.expects!(:generate_report).with("1")
      Multitool.expects!(:find_record).with("B").returns("2")
      Multitool.expects!(:generate_report).with("2")
    }

    prep[]
    Multitool.generate_report(Multitool.find_record("A"))
    Multitool.generate_report(Multitool.find_record("B"))

    prep[]
    Multitool.generate_report(Multitool.find_record("A"))
    assert_error Hardmock::ExpectationError, /Wrong arguments/, /find_record\("B"\)/, /find_record\("C"\)/ do
      Multitool.generate_report(Multitool.find_record("C"))
    end
    clear_expectations
  end

  it "can mock several concrete instance methods at once" do
    inst = OtherMultitool.new
    sim_code = lambda do |input|
      record = inst.find_record(input)
      report = inst.generate_report(record)
      inst.format_output(report)
    end

    @identifier = "the id"
    @record = "the record"
    @report = "the report"
    @output = "the output"

    inst.expects!(:find_record).with(@identifier).returns(@record)
    inst.expects!(:generate_report).with(@record).returns(@report)
    inst.expects!(:format_output).with(@report).returns(@output)

    result = sim_code.call(@identifier)
    assert_equal @output, result, "Wrong output"
  end

  it "verifies all concrete expects! from several different expectations" do
    Multitool.expects!(:find_record)
    Multitool.expects!(:generate_report)
    Multitool.expects!(:format_output)

    Multitool.find_record
    Multitool.generate_report

    assert_error Hardmock::VerifyError, /unmet expectations/i, /format_output/i do
      verify_mocks
    end
  end

  it "will not allow expects! to be used on a mock object" do
    create_mock :cow
    assert_error Hardmock::StubbingError, /expects!/, /mock/i, /something/ do
      @cow.expects!(:something)
    end
  end

  it "does not allow stubbing on nil objects" do
    [ nil, @this_is_nil ].each do |nil_obj|
      assert_error Hardmock::StubbingError, /cannot/i, /nil/i, /intentionally/ do
        nil_obj.stubs!(:wont_work)
      end
    end
  end

  it "does not allow concrete method mocking on nil objects" do
    [ nil, @this_is_nil ].each do |nil_obj|
      assert_error Hardmock::StubbingError, /cannot/i, /nil/i, /intentionally/ do
        nil_obj.expects!(:wont_work)
      end
    end
  end

  it "provides an alternate method for stubbing on nil objects" do
    @this_is_nil.intentionally_stubs!(:bogus).returns('output')
    assert_equal 'output', @this_is_nil.bogus
  end

  it "provides an alternate method for mocking concreate methods on nil objects" do
    @this_is_nil.intentionally_expects!(:bogus).returns('output')
    assert_error Hardmock::VerifyError, /unmet expectations/i, /NilClass.bogus/ do
      verify_mocks
    end
  end

  #
  # HELPERS
  #

  class Concrete
    def initialize; end
    def self.pour
      "stones and gravel"
    end

    def self.describe
      "For roads"
    end

    def hit
      "bonk"
    end

    def describe
      "an instance"
    end
  end

  class Jug
    def self.pour
      "glug glug"
    end
  end

  class Multitool
    def self.find_record(*a)
      raise "The real Multitool.find_record was called with #{a.inspect}"
    end
    def self.generate_report(*a)
      raise "The real Multitool.generate_report was called with #{a.inspect}"
    end
    def self.format_output(*a)
      raise "The real Multitool.format_output was called with #{a.inspect}"
    end
  end

  class OtherMultitool
    def find_record(*a)
      raise "The real OtherMultitool#find_record was called with #{a.inspect}"
    end
    def generate_report(*a)
      raise "The real OtherMultitool#generate_report was called with #{a.inspect}"
    end
    def format_output(*a)
      raise "The real OtherMultitool#format_output was called with #{a.inspect}"
    end
  end

end

