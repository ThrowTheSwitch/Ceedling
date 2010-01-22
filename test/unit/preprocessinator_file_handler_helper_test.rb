require File.dirname(__FILE__) + '/../unit_test_helper'
require 'preprocessinator_file_handler_helper'


class PreprocessinatorFileHandlerHelperTest < Test::Unit::TestCase

  def setup
    objects = create_mocks(:file_wrapper)
    @preprocessinator_file_handler_helper = PreprocessinatorFileHandlerHelper.new(objects)
  end

  def teardown
  end
  
  
  should "test something" do

  end
  
end
