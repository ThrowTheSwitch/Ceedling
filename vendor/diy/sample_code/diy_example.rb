# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================


require "rubygems"
require "diy"

class Car
  attr_reader :engine, :chassis
  def initialize(arg_hash)
    @engine = arg_hash[:engine]
    @chassis = arg_hash[:chassis]
  end
end

class Chassis
  def to_s
    "Chassis"
  end
end

class Engine
  def to_s
    "Engine"
  end
end

context = DIY::Context.from_file("objects.yml")
car = context['car']
puts "Car is made of: #{car.engine} and #{car.chassis}"
