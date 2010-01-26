require File.expand_path(File.dirname(__FILE__)) + "/../config/test_environment"
require 'test_helper'
require 'constructor'
require 'hardmock'


class Test::Unit::TestCase
  extend Behaviors
  
  def redefine_global_constant(constant, value)
    $config_options[constant.downcase.to_sym].replace(value)
  end
  
end


