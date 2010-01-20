require File.expand_path(File.dirname(__FILE__) + "/../test_helper")
require 'hardmock/method_cleanout'
require 'hardmock/trapper'

class TrapperTest < Test::Unit::TestCase
  include Hardmock

  def setup
    @mock = Object.new
    @mock_control = MyControl.new
    @builder = ExpBuilder.new
    @trapper = Trapper.new(@mock, @mock_control, @builder)
  end

  #
  # HELPERS
  #
   
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

  #
  # TESTS
  #

  def test_method_missing

    output = @trapper.change(:less)

    assert_same @mock, @builder.options[:mock]
    assert_equal :change, @builder.options[:method]
    assert_equal [:less], @builder.options[:arguments]
    assert_not_nil @builder.options[:block]
    assert @builder.options[:suppress_arguments_to_block], ":suppress_arguments_to_block should be set"
    assert_equal [ "dummy expectation" ], @mock_control.added,
      "Wrong expectation added to control"

    assert_equal "dummy expectation", output, "Expectation should have been returned"

    # Examine the block.  It should take one argument and simply return
    # that argument.  because of the 'suppress arguments to block' 
    # setting, the argument can only end up being a block, in practice.
    trapper_block = @builder.options[:block]
    assert_equal "the argument", trapper_block.call("the argument"),
      "The block should merely return the passed argument"
  end


end
