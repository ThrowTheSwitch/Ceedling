require File.dirname(__FILE__) + '/../lib/constructor_struct'

describe ConstructorStruct, "#new" do
  def struct(*accessors)
    ConstructorStruct.new(*accessors)
  end
  
  def instance_of(clazz, args=nil)
    args = [args] || []
    clazz.new(*args)
  end
  
  before do
    AClass = struct(:hello, :world) unless defined?(AClass)
  end
  
  it "creates a new class with accessors given a set of symbols or strings" do
    instance_of(AClass, {:hello => "foo", :world => "bar"}).hello.should == "foo"
    instance_of(AClass, {:hello => "foo", :world => "bar"}).world.should == "bar"
  end
  
  it "creates a real class" do
    instance_of(AClass).class.should == AClass
  end
  
  it "has the option of creating a strict accessors" do
    lambda { instance_of(struct(:foo, :strict => true)) }.should raise_error
  end
  
  it "does not have the option of not creating accessors" do
    instance_of(struct(:foo, :accessors => false), :foo => "bar").foo.should == "bar"
  end

  describe "equivalence" do
    before do
      @hello = "Hello"
      @world = "World"
      @args = { :hello => @hello, :world => @world }
      @target = AClass.new(@args)
    end

    it "uses all accessors" do
      [ nil, :hello, :world ].each do |field_to_alter|
        alt = AClass.new(:hello => @hello, :world => @world)

        unless field_to_alter
          # Base case: they should be equal
          @target.should == alt
          @target.eql?(alt).should be_true #should eql(alt)
        else
          # Change 1 field and see not equal
          alt.send("#{field_to_alter}=", "other data")
          @target.should_not == alt
          @target.should_not eql(alt)
        end
      end
    end

    it "will not compare to another class with same fields" do
      BClass = ConstructorStruct.new(:hello, :world)
      alt = BClass.new(:hello => @hello, :world => @world)
      @target.should_not == alt
      @target.should_not eql(alt)
    end
  end

  describe "extra method definitions" do
    NightTrain = ConstructorStruct.new(:beer, :conductor) do
      def setup
        @conductor ||= "Bill"
      end
    end

    it "lets you declare instance methods within a block" do
      night_train = NightTrain.new(:beer => "Founders")
      night_train.beer.should == "Founders"
      night_train.conductor.should == "Bill"

      other_train = NightTrain.new(:beer => "Bells", :conductor => "Dave")
      other_train.conductor.should == "Dave"
    end
  end

end
