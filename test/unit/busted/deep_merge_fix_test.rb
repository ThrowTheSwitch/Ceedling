require File.dirname(__FILE__) + '/../unit_test_helper'
require 'deep_merge'


class DeepMergeFixTest < Test::Unit::TestCase

  def setup
  end

  def teardown
  end
  
  should "overwrite destination hash elements of type TrueClass and FalseClass with source elements" do
    # note: The deep_merge present in vendor is an altered version of that which is available online.
    #       The original relies on true/false checks to detect presence in hashes instead of .nil? checks.
    #       Thus, it does not properly merge hash elements of TrueClass and FalseClass; the corrected 
    #        version does.

    source = {
      :array => [1, 2, 3],
      :int => 9,
      :string => 'hello',
      :boolean1 => false,
      :boolean2 => true,
      :boolean3 => false,
      :boolean4 => true,
    }
    
    destination = {
      :array => [3, 4, 5],
      :int => 1,
      :string => 'world',
      :boolean1 => true,
      :boolean2 => false,
      :boolean3 => false,
      :boolean4 => true,
    }

    merged  = {
      :array => [1, 2, 3, 4, 5],
      :int => 9,
      :string => 'hello',
      :boolean1 => false,
      :boolean2 => true,
      :boolean3 => false,
      :boolean4 => true,
    }

    destination.deep_merge!(source)
    destination[:array].sort!

    assert_equal(merged, destination)
  end

end
