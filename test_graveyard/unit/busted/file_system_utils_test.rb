require File.dirname(__FILE__) + '/../unit_test_helper'
require 'file_system_utils'


class FileSystemUtilsTest < Test::Unit::TestCase

  def setup
    objects = create_mocks(:file_wrapper)
    utils = FileSystemUtils.new(objects)
  end

  def teardown
  end


  should "" do    
    # dummy placeholder test; all tests are system tests (system/paths_test) for this guy
  end

end

