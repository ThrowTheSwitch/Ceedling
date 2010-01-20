require File.expand_path(File.dirname(__FILE__) + "/../test_helper")
require 'hardmock/expector'

class ExpectorTest < Test::Unit::TestCase
  include Hardmock

  class MyControl
    attr_reader :added
    def add_expectation(expectation)
      @added ||= []
      @added << expectation
    end
  end

  class ExpBuilder
    attr_reader :options
    def build_expectation(options)
      @options = options
      "dummy expectation"
    end
  end

  def try_it_with(method_name)
    mock = Object.new
    mock_control = MyControl.new
    builder = ExpBuilder.new

    exp = Expector.new(mock, mock_control, builder)
    output = exp.send(method_name,:with, 1, 'sauce')

    assert_same mock, builder.options[:mock]
    assert_equal method_name, builder.options[:method].to_s
    assert_equal [:with,1,'sauce'], builder.options[:arguments]
    assert_nil builder.options[:block]
    assert_equal [ "dummy expectation" ], mock_control.added,
      "Wrong expectation added to control"

    assert_equal "dummy expectation", output, "Expectation should have been returned"
  end

  #
  # TESTS
  #
  def test_method_missing
    try_it_with 'wonder_bread'
    try_it_with 'whatever'
  end

  def test_methods_that_wont_trigger_method_missing
    mock = Object.new
    mock_control = MyControl.new
    builder = ExpBuilder.new

    exp = Expector.new(mock, mock_control, builder)
    assert_equal mock, exp.instance_eval("@mock")
  end
end
