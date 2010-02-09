require File.dirname(__FILE__) + '/../unit_test_helper'
require 'file_finder'


class FileFinderTest < Test::Unit::TestCase

  def setup
    objects = create_mocks(:configurator, :file_finder_helper)
    @file_finder = FileFinder.new(objects)
  end

  def teardown
  end

  
  ############ find mockable header #############
  
  should "by convention find source header file from which mock is generated" do

    @configurator.expects.cmock_mock_prefix.returns('mock_')
    @configurator.expects.extension_header.returns('.h')
    @configurator.expects.collection_all_headers.returns(['files/include', 'files/source'])    
    @file_finder_helper.expects.find_file_in_collection('goldilocks.h', ['files/include', 'files/source']).returns('files/include/goldilocks.h')

    @configurator.expects.cmock_mock_prefix.returns('Mock')
    @configurator.expects.extension_header.returns('.H')
    @configurator.expects.collection_all_headers.returns(['include', 'source/headers'])    
    @file_finder_helper.expects.find_file_in_collection('Rapunzel.H', ['include', 'source/headers']).returns('include/Rapunzel.H')
    
    assert_equal('files/include/goldilocks.h', @file_finder.find_mockable_header('build/mocks/mock_goldilocks.c'))
    assert_equal('include/Rapunzel.H', @file_finder.find_mockable_header('files/build/mocks/MockRapunzel.C'))
  end

  ############ find test from runner #############

  should "by convention find test file from which test runner is generated" do

    @configurator.expects.extension_source.returns('.c')
    @configurator.expects.test_runner_file_suffix.returns('_runner')
    @configurator.expects.collection_all_tests.returns(['tests/a/test_larry.c', 'tests/b/test_curly.c', 'tests/a/test_moe.c'])
    @file_finder_helper.expects.find_file_in_collection('test_curly.c', ['tests/a/test_larry.c', 'tests/b/test_curly.c', 'tests/a/test_moe.c']).returns('tests/b/test_curly.c')

    assert_equal('tests/b/test_curly.c', @file_finder.find_test_from_runner_path('files/build/runners/test_curly_runner.c'))
  end

  should "raise if test file from which test runner is generated is not found" do

    @configurator.expects.extension_source.returns('.c')
    @configurator.expects.test_runner_file_suffix.returns('_runner')
    @configurator.expects.collection_all_tests.returns(['tests/a/test_larry.c', 'tests/b/test_curly.c', 'tests/a/test_moe.c'])

    @file_finder_helper.expects.complain('test_shemp.c').raises('')

    begin
      @file_finder.find_test_from_runner_path('files/build/runners/test_shemp_runner.c')
      flunk 'should have raised'
    rescue
    end
  end

  ############ find test from file path #############

  should "by convention find test file from given file path" do

    @configurator.expects.extension_source.returns('.c')
    @configurator.expects.collection_all_tests.returns(['tests/a/test_larry.c', 'tests/b/test_curly.c', 'tests/a/test_moe.c'])
    @file_finder_helper.expects.find_file_in_collection('test_moe.c', ['tests/a/test_larry.c', 'tests/b/test_curly.c', 'tests/a/test_moe.c']).returns('tests/a/test_moe.c')

    assert_equal('tests/a/test_moe.c', @file_finder.find_test_from_file_path('files/build/runners/test_moe.out'))
  end

  should "raise if test file cannot be found from given file path" do

    @configurator.expects.extension_source.returns('.c')
    @configurator.expects.collection_all_tests.returns(['tests/a/test_larry.c', 'tests/b/test_curly.c', 'tests/a/test_moe.c'])

    @file_finder_helper.expects.complain('test_shemp.o').raises('')

    begin
      @file_finder.find_test_from_file_path('files/build/out/test_shemp.o')
      flunk 'should have raised'
    rescue
    end
  end

  ############ find test or source from file path #############

  should "by convention find test or source file from file path" do
    collection = ['files/tests/test_whatever.c', 'files/modules/flight.c']
    
    @configurator.expects.extension_source.returns('.c')
    @configurator.expects.collection_all_compilation_input.returns(collection)
    @file_finder_helper.expects.find_file_in_collection('flight.c', collection).returns('files/modules/flight.c')
    
    assert_equal('files/modules/flight.c', @file_finder.find_compilation_input_file('flight.out'))
  end
  
  ############ find all source files that correspond to given header files #############

  should "by convention find all source files that correspond to the given header files" do
    collection = ['files/tests/test_stuff.c', 'files/modules/flight.c']
    
    @configurator.expects.extension_source.returns('.c')
    @configurator.expects.collection_all_compilation_input.returns(collection)
    
    @file_finder_helper.expects.find_file_in_collection('flight.c', collection, {:should_complain => false}).returns('files/modules/flight.c')
    @file_finder_helper.expects.find_file_in_collection('types.c', collection, {:should_complain => false}).returns('')
    
    assert_equal(['files/modules/flight.c'], @file_finder.find_source_files_from_headers(['flight.h', 'types.h']))
  end


end

