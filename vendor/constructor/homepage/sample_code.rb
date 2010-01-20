require 'rubygems'
require 'constructor'

class Horse
  constructor :name, :breed, :weight, :accessors => true
end

ed = Horse.new(:name => 'Ed', :breed => 'Mustang', :weight => 342)
puts ed.name
puts ed.breed
puts ed.weight

