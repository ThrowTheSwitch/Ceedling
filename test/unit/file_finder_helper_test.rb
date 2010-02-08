require File.dirname(__FILE__) + '/../unit_test_helper'
require 'file_finder_helper'


class FileFinderHelperTest < Test::Unit::TestCase

  def setup
    objects = create_mocks(:streaminator)
    @file_finder_helper = FileFinderHelper.new(objects)
  end

  def teardown
  end
  
  
  should "return file path when sought file is found in search collection" do
    search_collection = ['files/source/yadda.h', 'files/tests/test_thing.c', 'lib/headers/wheres_waldo.h']

    assert_equal('lib/headers/wheres_waldo.h', @file_finder_helper.find_file_in_collection('wheres_waldo.h', search_collection))
  end

  should "raise if the file is not found" do
    search_collection = ['files/source/yadda.h', 'files/tests/test_thing.c', 'lib/headers/no_waldo.h']
  
    @streaminator.expects.stderr_puts("ERROR: Could not find 'waldo.h'.", Verbosity::ERRORS)
  
    assert_raise(RuntimeError){ @file_finder_helper.find_file_in_collection('waldo.h', search_collection) }
  end

  should "raise if the file is found but with wrong capitalization" do
    search_collection = ['files/source/yadda.h', 'files/tests/test_thing.c', 'lib/headers/no_waldo.h']
  
    @streaminator.expects.stderr_puts("ERROR: Could not find 'Yadda.h' but did find filename having different capitalization: 'files/source/yadda.h'.", Verbosity::ERRORS)
  
    assert_raise(RuntimeError){ @file_finder_helper.find_file_in_collection('Yadda.h', search_collection) }
  end
  
  should "not raise but just return empty string if the file is not found" do
    search_collection = ['files/source/yadda.h', 'files/tests/test_thing.c', 'lib/headers/no_waldo.h']
    
    assert_equal('', @file_finder_helper.find_file_in_collection('waldo.h', search_collection, {:should_complain => false}))
  end

end

