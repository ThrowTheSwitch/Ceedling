require File.expand_path(File.dirname(__FILE__) + "/../test_helper")
require 'assert_error'

class AssertErrorTest < Test::Unit::TestCase

  it "specfies an error type and message that should be raised" do
    assert_error RuntimeError, "Too funky" do
      raise RuntimeError.new("Too funky")
    end
  end

  it "flunks if the error message is wrong" do
    err = assert_raise Test::Unit::AssertionFailedError do
      assert_error RuntimeError, "not good" do
        raise RuntimeError.new("Too funky")
      end
    end
    assert_match(/not good/i, err.message) 
    assert_match(/too funky/i, err.message) 
  end

  it "flunks if the error type is wrong" do
    err = assert_raise Test::Unit::AssertionFailedError do
      assert_error StandardError, "Too funky" do
        raise RuntimeError.new("Too funky")
      end
    end
    assert_match(/StandardError/i, err.message) 
    assert_match(/RuntimeError/i, err.message) 
  end

  it "can match error message text using a series of Regexps" do 
    assert_error StandardError, /too/i, /funky/i do
      raise StandardError.new("Too funky")
    end
  end

  it "flunks if the error message doesn't match all the Regexps" do
    err = assert_raise Test::Unit::AssertionFailedError do
      assert_error StandardError, /way/i, /too/i, /funky/i do
        raise StandardError.new("Too funky")
      end
    end
    assert_match(/way/i, err.message) 
  end

  it "can operate without any message specification" do
    assert_error StandardError do 
      raise StandardError.new("ooof")
    end
  end
end
