require File.dirname(__FILE__) + '/../unit_test_helper'
require 'test_includes_extractor'


class TestIncludesExtractorTest < Test::Unit::TestCase

  # dummy file contents
  DUMMY_BERT_C = %Q[
    #include "unity.h"
    #include "Bert.h"
    #include "MockBigBird.h"

    void test_ernie(void)
    {
      TEST_ASSERT_EQUAL_STRING("rubber ducky", ernie());
    }
    ].left_margin(0)

  DUMMY_OSCAR_C = %Q[
    #include "unity.h"
    #include "Oscar.h"
    #include "MockBigBird.h"
    #include  " MockSnuffleupagus.h "

    void test_elmo(void)
    {
      TEST_ASSERT_EQUAL(5, elmo()); // elmo is 5
    }
    ].left_margin(0)

  DUMMY_KERMIT_C = %Q[
    #include "unity.h"
    #include "Kermit.h"
    #include "MockBigBird.h"
    #include "MockTheCount.h"
    #include "MockCookieMonster.h"

    void test_MockTestRegex(void)
    {
      TEST_ASSERT_IGNORE("Throwing a random 'Mock' in the file...");
    }
    ].left_margin(0)


  def setup
    objects = create_mocks(:yaml_wrapper, :file_wrapper)

    @test_includes_extractor = TestIncludesExtractor.new(objects)

    @test_includes_extractor.cmock_mock_prefix = 'Mock'
    @test_includes_extractor.extension_header  = '.h'
    
    # verify all is blank before processing
    assert_equal([], @test_includes_extractor.lookup_all_mocks)
  end

  def teardown
  end


  def parse_test_helper
    @file_wrapper.expects.readlines('tests/a/test_bert.c').returns(DUMMY_BERT_C.split(/\n/))
    @file_wrapper.expects.readlines('tests/b/test_oscar.c').returns(DUMMY_OSCAR_C.split(/\n/))
    @file_wrapper.expects.readlines('tests/c/test_kermit.c').returns(DUMMY_KERMIT_C.split(/\n/))

    # process dummy files
    @test_includes_extractor.parse_test_files(['tests/a/test_bert.c', 'tests/b/test_oscar.c', 'tests/c/test_kermit.c'])
  end

  
  should "verify all mocks extracted from multiple test files" do
    parse_test_helper
    assert_equal(
      ['MockBigBird.h',
       'MockSnuffleupagus.h',
       'MockTheCount.h',
       'MockCookieMonster.h'],
      @test_includes_extractor.lookup_all_mocks)
  end
  
  should "verify raw mocks list extracted from multiple test files" do
    parse_test_helper
    assert_equal(['MockBigBird'], @test_includes_extractor.lookup_raw_mock_list('tests/a/test_bert.c'))
    assert_equal(['MockBigBird', 'MockSnuffleupagus'], @test_includes_extractor.lookup_raw_mock_list('tests/b/test_oscar.c'))
    assert_equal(['MockBigBird', 'MockTheCount', 'MockCookieMonster'], @test_includes_extractor.lookup_raw_mock_list('tests/c/test_kermit.c'))
    assert_equal([], @test_includes_extractor.lookup_raw_mock_list('test_grover.c')) # no such file, get back empty list
  end
    
  should "verify includes list extracted from multiple test files" do
    parse_test_helper
    assert_equal(['unity.h', 'Bert.h', 'MockBigBird.h'], @test_includes_extractor.lookup_includes_list('tests/a/test_bert.c'))
    assert_equal(['unity.h', 'Oscar.h', 'MockBigBird.h', 'MockSnuffleupagus.h'], @test_includes_extractor.lookup_includes_list('tests/b/test_oscar.c'))
    assert_equal(['unity.h', 'Kermit.h', 'MockBigBird.h', 'MockTheCount.h', 'MockCookieMonster.h'], @test_includes_extractor.lookup_includes_list('tests/c/test_kermit.c'))
    assert_equal([], @test_includes_extractor.lookup_includes_list('test_grover.c')) # no such file, get back empty list
  end

  should "verify includes stored in yaml files created during preprocessing" do
    @yaml_wrapper.expects.load('preprocess/a_file.h').returns(['common.h', 'types.h'])
    @yaml_wrapper.expects.load('preprocess/another_file.c').returns(['another_file.h', 'types.h'])
    @yaml_wrapper.expects.load('preprocess/test_last_file.c').returns(['unity.h', 'mock_a_file.h', 'last_file.h'])
    
    @test_includes_extractor.parse_includes_lists(['preprocess/a_file.h', 'preprocess/another_file.c', 'preprocess/test_last_file.c'])

    assert_equal(['common.h', 'types.h'], @test_includes_extractor.lookup_includes_list('preprocess/a_file.h'))
    assert_equal(['another_file.h', 'types.h'], @test_includes_extractor.lookup_includes_list('preprocess/another_file.c'))
    assert_equal(['unity.h', 'mock_a_file.h', 'last_file.h'], @test_includes_extractor.lookup_includes_list('preprocess/test_last_file.c'))
    assert_equal([], @test_includes_extractor.lookup_includes_list('junk.c')) # no such file, get back empty list
  end

end

