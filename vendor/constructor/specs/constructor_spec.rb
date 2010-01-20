require File.expand_path(File.dirname(__FILE__) + '/../lib/constructor') 

describe 'standard constructor usage' do
  it 'allows for object construction using a hash of named arguments' do
    fuh = TestingClass.new( 
      :foo => 'my foo',
      :bar => 'my bar',
      :qux => 'my qux',
      :why => 'lucky'
    )

    fuh.foo.should eql('my foo')
    fuh.bar.should eql('my bar') 
    fuh.qux.should eql('my qux')
    fuh.why.should eql('lucky')
    fuh.to_pretty_pretty.should eql('my foo my bar')
  end

  it 'calls setup method if defined' do
    ralph = Llamma.new :hair => 'red'
    ralph.hungry.should be_true
    ralph.hair.should eql('red')
  end
end

describe "constructor's accessor option" do
  it 'provides accessors for constructor arguments when accessor option is true' do
    fuh = TestingAutoAccessors.new( 
      :foo => 'my foo',
      :bar => 'my bar',
      :qux => 'my qux',
      :why => 'lucky'
    )
    fuh.foo.should eql('my foo')
    fuh.bar.should eql('my bar')
    fuh.qux.should eql('my qux')
    fuh.why.should eql('lucky')
    fuh.to_pretty_pretty.should eql('my foo my bar')
  end

  it 'does not provide accessors for constructor arguments when accessor option is false' do
    fuh = TestingBlockedAccessors.new :foo => 'my foo', :bar => 'my bar'
    lambda {fuh.foo}.should raise_error(NoMethodError)
    lambda {fuh.bar}.should raise_error(NoMethodError)
    fuh.to_pretty_pretty.should eql('my foo my bar')
  end
end

describe "constructor's reader option" do
  it 'provides readers for constructor arguments when reader option is true' do
    fuh = TestingAutoReaders.new( 
      :foo => 'my foo',
      :why => 'lucky'
    )
    fuh.foo.should eql('my foo')
    fuh.why.should eql('lucky')
    fuh.to_pretty_pretty.should eql('my foo lucky')

    lambda {fuh.why = 'no way'}.should raise_error(NoMethodError)
    lambda {fuh.foo = 'uh uh'}.should raise_error(NoMethodError)
  end

  it 'does not provide reader for constructor arguments when reader option is false' do
    fuh = TestingBlockedReaders.new :foo => 'my foo', :why => 'my why'
    lambda {fuh.foo}.should raise_error(NoMethodError)
    lambda {fuh.bar}.should raise_error(NoMethodError)
    fuh.to_pretty_pretty.should eql('my foo my why')

    lambda {fuh.why = 'no way'}.should raise_error(NoMethodError)
    lambda {fuh.foo = 'uh uh'}.should raise_error(NoMethodError)
  end
end

describe 'using constructor with inheritance' do
  it 'allows for inheritance of constructor arguments using a non-constructor defined subclass' do
    fuh = SubclassOfTestingClass.new :foo => 'whu?'
    fuh.foo.should eql('whu?')
    fuh.bar.should be_nil
    fuh.qux.should be_nil
    fuh.why.should be_nil
  end

  it 'allows for standard construction of a non-constructor subclass of a non-strict constuctor superclass' do
    fuh = SubclassOfTestingClass2.new 
    fuh.foo.should be_nil
  end

  it 'runs initialize method of a sublcass' do
    fuh = SubclassOfTestingClass3.new
    fuh.my_new_var.should eql('something')
    fuh.foo.should be_nil
    fuh.bar.should be_nil
    fuh.qux.should be_nil
    fuh.why.should be_nil
  end

  it 'passes named constructor args to superclass when subclass calls super' do
    fuh = SubclassOfTestingClass3.new :foo => 12
    fuh.my_new_var.should eql('something')
    fuh.foo.should eql(12)
    fuh.bar.should be_nil
    fuh.qux.should be_nil
    fuh.why.should be_nil
  end

  it 'allows for inheritance of constructor arguments using a constructor defined subclass' do
    s = Sonny.new :car => 'Nissan', :saw => 'Dewalt', :computer => 'Dell'
    s.computer.should eql('Dell')
    s.saw.should eql('Dewalt')
    s.car.should eql('Nissan')
  end
  
  it 'calls the setup method on superclass if subclass does not define a setup method' do
    baby = Baby.new :cuteness => 'little', :age => 1
    baby.fat.should eql('much')
  end 

  it 'calls parent class setup when super is called from subclass setup'  do
    m = Mama.new :age => 55
    m.age.should eql(55)
    m.fat.should eql('much')
    
    s = Sissy.new :age => 19, :beauty => 'medium', :fat => 'yeah'
    s.age.should eql(19)
    s.beauty.should eql('medium')
    s.fat.should eql('much')
    s.friends.should eql('many')
  end

  it 'passes arguments given in the super option to the initializer of a non-constructor defined superclass' do
    tsc = TestingSuperConstructor.new(:far => 'oo', :away => 'kk')
    tsc.far.should eql('oo')
    tsc.away.should eql('kk')
    tsc.a.should eql("once")
    tsc.b.should eql(:twice)
  end 

  it 'calls non-constructor defined superclass constructor when the super option is an empty array' do
    tsc = TestingSuperConstructor2.new(:some => 'thing')
    tsc.some.should eql('thing')
    tsc.c.should eql('what a')
    tsc.d.should eql('day for')
  end
  
  it "raises an error if subclass tries to build a constructor with the keys as its parents" do
    class1 = constructor_class(Object, :star, :wars)
    class2 = constructor_class(class1, :space, :balls)
    lambda { constructor_class(class2, :star, :space, :chewy) }.should raise_error("Base class already has keys [:space, :star]")
  end
  
  it 'does not create accessors for superclass constructor arguments' do
    tas = TestingAccessorSubclass.new(:far => 'thing')
    tas.respond_to?(:cuteness).should be_false
  end
  
  it 'does not create a reader for superclass constructor arguments' do
    t1 = TestingReaderSubclass.new(:foo => 'thing')
    t1.respond_to?(:foo).should be_false
  end
end

describe 'stict mode usage' do
  it 'allows omission of arguments when strict is off' do
    fuh = TestingClass.new :foo => 'my foo' 
    
    fuh.foo.should eql('my foo')
    fuh.bar.should be_nil
    fuh.qux.should be_nil
    fuh.why.should be_nil
  end

  it 'allows no arguments to a constructor when strict is off' do
    fuh = TestingClass.new
    fuh.foo.should be_nil
    fuh.bar.should be_nil
    fuh.qux.should be_nil
    fuh.why.should be_nil
  end

  it 'does not interfere with normal object construction' do
    require 'rexml/document'
    d = REXML::Document.new '<base/>'
    d.should_not be_nil
    d.root.name.should eql('base')
  end

  def see_strict_args_in_effect_for(clazz)
    fuh = clazz.new :foo => 'my foo', :bar => 'my bar'
    fuh.to_pretty_pretty.should eql('my foo my bar')

    # Omit foo
    lambda {
      TestingStrictArgsDefault.new :bar => 'ok,yeah'
    }.should raise_error(ConstructorArgumentError, /foo/)
    
    # Omit bar
    lambda {
      TestingStrictArgsDefault.new :foo => 'ok,yeah'
    }.should raise_error(ConstructorArgumentError, /bar/)
  end

  it 'defaults to strict argument enforcement' do
    see_strict_args_in_effect_for TestingStrictArgsDefault
  end

  it 'enforces strict arguments when strict option is true' do
    see_strict_args_in_effect_for TestingStrictArgs
  end

  it 'does not allow empty constructor arguments when strict option is true' do
    lambda {TestingStrictArgs.new {}}.should raise_error(ConstructorArgumentError,/foo,bar/)
    lambda {TestingStrictArgs.new}.should raise_error(ConstructorArgumentError,/foo,bar/)
    lambda {TestingStrictArgs.new nil}.should raise_error(ConstructorArgumentError,/foo,bar/)
  end

  it 'does not allow extraneous arguments when strict option is true' do
    [ /thing/, /other/ ].each do |rejected_arg|
      lambda {
        TestingStrictArgs.new(:foo => 1, :bar => 2, :other => 3, :thing => 4)
      }.should raise_error(ConstructorArgumentError, rejected_arg)
    end
  end

  it 'allows for setting accessors option while in strict mode' do
    t2 = TestingStrictArgs2.new :foo => 1, :bar => 2
    
    # See that accessors work
    t2.foo.should eql(1)
    t2.bar.should eql(2)

    # See that strictness still applies
    lambda {TestingStrictArgs2.new :no => 'good'}.should raise_error(ConstructorArgumentError)
  end
end

describe 'catching ConstructorArgumentError' do
  it 'allows for generic rescuing of constructor argument errors' do
    begin
      TestingStrictArgs.new :broken => 'yoobetcha'
    rescue => bad_news
      bad_news.should be_kind_of(ConstructorArgumentError)
    end
  end
end

describe 'block yielding' do
  it 'executes a specified block after instantiating' do
    TestingBlockYield.new(:a => false).a.should == true
  end
end

def constructor_class(base, *keys)
  Class.new(base) do
    constructor *keys
  end
end

class TestingClass
  attr_accessor :foo, :bar, :why, :qux
  constructor :foo, :bar, :why, :qux, :strict => false

  def to_pretty_pretty
    "#{@foo} #{@bar}"
  end

end

class Mama
  attr_accessor :fat, :age
  constructor :age, :strict => false
  def setup
    @fat = "much"
  end
end

class Baby < Mama
  constructor :cuteness
end

class Sissy < Mama
  attr_accessor :friends, :beauty
  constructor :beauty, :strict => false
  def setup
    super #IMPORTANT!
    @friends = "many"
  end
end

class TestingStrictArgsDefault
  constructor :foo, :bar
  def to_pretty_pretty
    "#{@foo} #{@bar}"
  end
end

class TestingStrictArgs
  constructor :foo, :bar, :strict => true
  def to_pretty_pretty
    "#{@foo} #{@bar}"
  end
end

class TestingStrictArgs2
  constructor :foo, :bar, :accessors => true
end

class SubclassOfTestingClass < TestingClass
end

class SubclassOfTestingClass2 < TestingClass
  def initialize; end
end

class SubclassOfTestingClass3 < TestingClass
  attr_reader :my_new_var
  def initialize(hash = nil)
    super
    @my_new_var = "something"
  end
end

class TestingAutoAccessors
  constructor :foo, :bar, :why, :qux, :accessors => true, :strict => false
  def to_pretty_pretty
    "#{@foo} #{@bar}"
  end
end

class TestingAutoReaders
  constructor :foo, :why, :readers => true, :strict => false
  def to_pretty_pretty
    "#{@foo} #{@why}"
  end
end

class TestingReaderSuperclass
  constructor :foo
end

class TestingReaderSubclass < TestingReaderSuperclass
  constructor :bar,  :readers => true, :strict => false
end  

class TestingSuperConstructorBase
  attr_reader :a, :b
  def initialize(a,b)
    @a = a
    @b = b
  end
end

class TestingSuperConstructor < TestingSuperConstructorBase
  constructor :far, :away, :accessors => true, :super => ["once", :twice], :strict => false
end

class TestingSuperConstructorBase2
  attr_reader :c, :d
  def initialize
    @c = 'what a'
    @d = 'day for'
  end
end

class TestingSuperConstructor2 < TestingSuperConstructorBase2
  constructor :some, :accessors => true, :super => [], :strict => false
end

class TestingAccessorSubclass < Baby
  constructor :foo, :accessors => true, :strict => false
end

class TestingBlockedAccessors
  constructor :foo, :bar, :accessors => false
  def to_pretty_pretty
    "#{@foo} #{@bar}"
  end
end

class TestingBlockedReaders
  constructor :foo, :why, :readers => false
  def to_pretty_pretty
    "#{@foo} #{@why}"
  end
end

class Papa
  constructor :car, :saw
end

class Sonny < Papa
  attr_accessor :car, :saw, :computer
  constructor :computer
end

class Llamma
  attr_accessor :hungry, :hair
  constructor :hair
  def setup
    @hungry = true
  end
end
  
class TestingBlockYield
  constructor :a, :accessors => true do
    @a = true
  end
end
