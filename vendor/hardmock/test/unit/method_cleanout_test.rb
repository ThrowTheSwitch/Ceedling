require File.expand_path(File.dirname(__FILE__) + "/../test_helper")
require 'hardmock/method_cleanout'

class MethodCleanoutTest < Test::Unit::TestCase
  class Victim
    OriginalMethods = instance_methods
    include Hardmock::MethodCleanout
  end
  
  def setup
    @victim = Victim.new
  end

  def test_should_remove_most_methods_from_a_class
    expect_removed = Victim::OriginalMethods.reject { |m| 
      Hardmock::MethodCleanout::SACRED_METHODS.include?(m)
    }
    expect_removed.each do |m|
      assert !@victim.respond_to?(m), "should not have method #{m}"
    end
  end

  def test_should_leave_the_sacred_methods_defined
    Hardmock::MethodCleanout::SACRED_METHODS.each do |m|
      next if m =~ /^hm_/
      assert @victim.respond_to?(m), "Sacred method '#{m}' was removed unexpectedly"
    end
  end

  def test_should_include_certain_important_methods_in_the_sacred_methods_list
    %w|__id__ __send__ equal? object_id send nil? class kind_of? respond_to? inspect method to_s instance_variables instance_eval|.each do |m|
      assert Hardmock::MethodCleanout::SACRED_METHODS.include?(m), "important method #{m} is not included in SACRED_METHODS"
    end
  end

end
