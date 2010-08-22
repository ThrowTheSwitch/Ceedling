require File.dirname(__FILE__) + '/../unit_test_helper'
require 'preprocessinator_helper'


class PreprocessinatorHelperTest < Test::Unit::TestCase

  def setup
    objects = create_mocks(:configurator, :test_includes_extractor, :task_invoker, :file_finder, :file_path_utils)
    @preprocessinator_helper = PreprocessinatorHelper.new(objects)
    create_mocks(:preprocess_file_proc)
  end

  def teardown
  end
  
  
  ########## assemble test list ###########
  
  should "assemble non-preprocessed test list" do
    test_list = ['tests/tweedle_test.c', 'tests/dumb_test.c']

    @configurator.expects.project_use_preprocessor.returns(false)

    assert_equal(test_list, @preprocessinator_helper.assemble_test_list(test_list))
  end

  should "assemble preprocessed test list" do
    test_list = ['tests/tweedle_test.c', 'tests/dee_test.c']
    preprocessed_test_list = ['project/build/preprocess/tweedle_test.c', 'project/build/preprocess/dee_test.c']

    @configurator.expects.project_use_preprocessor.returns(true)
    @file_path_utils.expects.form_preprocessed_files_filelist(test_list).returns(preprocessed_test_list)

    assert_equal(preprocessed_test_list, @preprocessinator_helper.assemble_test_list(test_list))
  end

  ########## preprocess includes ###########

  should "extract non-preprocessed includes" do
    test_list = ['tests/tweedle_test.c', 'tests/dumb_test.c']
    includes = ['unity.h', 'types.h']

    @configurator.expects.project_use_preprocessor.returns(false)
    @test_includes_extractor.expects.parse_test_files(test_list).returns(includes)

    assert_equal(includes, @preprocessinator_helper.preprocess_includes(test_list))
  end

  should "extract preprocessed includes" do
    test_list = ['tests/tweedle_test.c', 'tests/dumb_test.c']
    includes_lists = ['project/build/preprocess/includes/tweedle_test.c', 'project/build/preprocess/includes/dumb_test.c']
    includes = ['unity.h', 'types.h']

    @configurator.expects.project_use_preprocessor.returns(true)
    @file_path_utils.expects.form_preprocessed_includes_list_filelist(test_list).returns(includes_lists)
    @task_invoker.expects.invoke_shallow_include_lists(includes_lists)
    @test_includes_extractor.expects.parse_includes_lists(includes_lists).returns(includes)

    assert_equal(includes, @preprocessinator_helper.preprocess_includes(test_list))
  end

  ########## assemble mocks list ###########
  
  should "assemble mocks list" do
    mocks_list = ['mock_and_roll.h', 'mock_em_sock_em.h']
    mocks_filelist = ['project/build/mocks/mock_and_roll.c', 'project/build/mocks/mock_em_sock_em.c']

    @test_includes_extractor.expects.lookup_all_mocks.returns(mocks_list)
    @file_path_utils.expects.form_mocks_filelist(mocks_list).returns(mocks_filelist)

    assert_equal(mocks_filelist, @preprocessinator_helper.assemble_mocks_list)
  end

  ########## preprocess mockable headers ###########
  
  should "preprocess no mockable headers" do
    mocks_list = ['project/build/mocks/mock_and_roll.c', 'project/build/mocks/mock_em_sock_em.c']

    @configurator.expects.project_use_preprocessor.returns(false)

    @preprocessinator_helper.preprocess_mockable_headers(mocks_list, @preprocess_file_proc)
  end

  should "preprocess mockable headers invoked from auxiliary dependencies" do
    mocks_list = ['project/build/mocks/mock_and_roll.c', 'project/build/mocks/mock_em_sock_em.c']
    mocks_filelist = ['project/build/preprocessed/and_roll.h', 'project/build/preprocessed/em_sock_em.h']

    @configurator.expects.project_use_preprocessor.returns(true)

    @file_path_utils.expects.form_preprocessed_mockable_headers_filelist(mocks_list).returns(mocks_filelist)

    @configurator.expects.project_use_auxiliary_dependencies.returns(true)

    @task_invoker.expects.invoke_preprocessed_files(mocks_filelist)

    @preprocessinator_helper.preprocess_mockable_headers(mocks_list, @preprocess_file_proc)
  end

  should "force preprocessing of mockable headers" do
    mocks_list = ['project/build/mocks/mock_and_roll.c', 'project/build/mocks/mock_em_sock_em.c']
    mocks_filelist = ['project/build/preprocessed/and_roll.h', 'project/build/preprocessed/em_sock_em.h']
    headers_list = ['source/lib/and_roll.h', 'source/em_sock_em.h']

    @configurator.expects.project_use_preprocessor.returns(true)

    @file_path_utils.expects.form_preprocessed_mockable_headers_filelist(mocks_list).returns(mocks_filelist)

    @configurator.expects.project_use_auxiliary_dependencies.returns(false)

    @file_finder.expects.find_mockable_header(mocks_filelist[0]).returns(headers_list[0])
    @preprocess_file_proc.expects.call(headers_list[0])
    @file_finder.expects.find_mockable_header(mocks_filelist[1]).returns(headers_list[1])
    @preprocess_file_proc.expects.call(headers_list[1])

    @preprocessinator_helper.preprocess_mockable_headers(mocks_list, @preprocess_file_proc)
  end

  ########## preprocess test files ###########
  
  should "preprocess no test files" do
    preprocessed_test_list = ['project/build/preprocess/tweedle_test.c', 'project/build/preprocess/dee_test.c']

    @configurator.expects.project_use_preprocessor.returns(false)

    @preprocessinator_helper.preprocess_test_files(preprocessed_test_list, @preprocess_file_proc)
  end

  should "preprocess test files invoked from auxiliary dependencies" do
    preprocessed_test_list = ['project/build/preprocess/tweedle_test.c', 'project/build/preprocess/dee_test.c']

    @configurator.expects.project_use_preprocessor.returns(true)

    @configurator.expects.project_use_auxiliary_dependencies.returns(true)

    @task_invoker.expects.invoke_preprocessed_files(preprocessed_test_list)

    @preprocessinator_helper.preprocess_test_files(preprocessed_test_list, @preprocess_file_proc)
  end

  should "force preprocessing of test files" do
    preprocessed_test_list = ['project/build/preprocess/tweedle_test.c', 'project/build/preprocess/dee_test.c']
    test_list = ['tests/tweedle_test.c', 'tests/dee_test.c']
  
    @configurator.expects.project_use_preprocessor.returns(true)
  
    @configurator.expects.project_use_auxiliary_dependencies.returns(false)
  
    @file_finder.expects.find_test_from_file_path(preprocessed_test_list[0]).returns(test_list[0])
    @preprocess_file_proc.expects.call(test_list[0])
    @file_finder.expects.find_test_from_file_path(preprocessed_test_list[1]).returns(test_list[1])
    @preprocess_file_proc.expects.call(test_list[1])
  
    @preprocessinator_helper.preprocess_test_files(preprocessed_test_list, @preprocess_file_proc)
  end
  
end
