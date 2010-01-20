require File.dirname(__FILE__) + '/../unit_test_helper'
require 'file_finder_helper'


class FileFinderHelperTest < Test::Unit::TestCase

  def setup
    objects = create_mocks(:streaminator, :file_wrapper)
    @file_finder_helper = FileFinderHelper.new(objects)
  end

  def teardown
  end
  
  
  should "return the file path when found in search paths" do
    search_paths = ['.', 'files/source', 'files/tests', 'lib/headers']

    @file_wrapper.expects.exists?('./waldo.h').returns(false)
    @file_wrapper.expects.exists?('files/source/waldo.h').returns(false)
    @file_wrapper.expects.exists?('files/tests/waldo.h').returns(true)

    assert_equal('files/tests/waldo.h', @file_finder_helper.find_file_on_disk('waldo.h', search_paths))
  end

  should "raise if the file is not found" do
    search_paths = ['source', 'tests/source', 'include']

    @file_wrapper.expects.exists?('source/waldo.h').returns(false)
    @file_wrapper.expects.exists?('tests/source/waldo.h').returns(false)
    @file_wrapper.expects.exists?('include/waldo.h').returns(false)

    @streaminator.expects.puts_stderr("ERROR: Could not find 'waldo.h'.", Verbosity::ERRORS)

    assert_raise(RuntimeError){ @file_finder_helper.find_file_on_disk('waldo.h', search_paths) }
  end

  should "not raise but just return empty string if the file is not found" do
    search_paths = ['source', 'tests/source', 'include']

    @file_wrapper.expects.exists?('source/waldo.h').returns(false)
    @file_wrapper.expects.exists?('tests/source/waldo.h').returns(false)
    @file_wrapper.expects.exists?('include/waldo.h').returns(false)

    assert_equal('', @file_finder_helper.find_file_on_disk('waldo.h', search_paths, {:should_complain => false}))
  end

end

