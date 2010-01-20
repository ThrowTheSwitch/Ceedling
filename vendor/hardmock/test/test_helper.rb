here = File.expand_path(File.dirname(__FILE__))
$: << here

require "#{here}/../config/environment"
require 'test/unit'
require 'fileutils'
require 'logger'
require 'find'
require 'yaml'
require 'set'
require 'ostruct'

class Test::Unit::TestCase
  include FileUtils

  def poll(time_limit) 
    (time_limit * 10).to_i.times do 
      return true if yield
      sleep 0.1
    end
    return false
  end

  def self.it(str, &block)
    make_test_case "it", str, &block
  end

  def self.should(str, &block)
    make_test_case "should", str, &block
  end

  def self.make_test_case(prefix, str, &block)
    tname = self.name.sub(/Test$/,'')
    if block
      define_method "test #{prefix} #{str}" do
        instance_eval &block
      end
    else
      puts ">>> UNIMPLEMENTED CASE: #{tname}: #{str}"
    end
  end

end
