class Car
  attr_reader :engine, :chassis
  def initialize(arg_hash)
    @engine = arg_hash[:engine]
    @chassis = arg_hash[:chassis]
  end
end
