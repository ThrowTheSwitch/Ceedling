require File.dirname(__FILE__) + '/../unit_test_helper'
require 'preprocessinator'


class PreprocessinatorTest < Test::Unit::TestCase

  def setup
    objects = create_mocks(:configurator, :preprocessinator_helper, :preprocessinator_includes_handler, :task_invoker, :file_path_utils)
    @preprocessinator = Preprocessinator.new(objects)
  end

  def teardown
  end
  
  
  should "preprocess tests and invoke mocks" do
    create_mocks(:tests_list, :mocks_list)

    @preprocessinator_helper.expects.assemble_test_list(['tests/tweedle_test.c', 'tests/dumb_test.c']).returns(@tests_list)
    @preprocessinator_helper.expects.preprocess_includes(@tests_list)
    @preprocessinator_helper.expects.assemble_mocks_list.returns(@mocks_list)
    @preprocessinator_helper.expects.preprocess_mockable_headers(@mocks_list)
    @task_invoker.expects.invoke_mocks(@mocks_list)
    @preprocessinator_helper.expects.preprocess_test_files(@tests_list)

    assert_equal(@mocks_list, @preprocessinator.preprocess_tests_and_invoke_mocks(['tests/tweedle_test.c', 'tests/dumb_test.c']))
  end
  
  should "preprocess shallow includes for a given file and write them to disk" do
    @preprocessinator_includes_handler.expects.form_shallow_dependencies_rule('project/source/software.c').returns('project/build/output/thing.o: header.h')
    @preprocessinator_includes_handler.expects.extract_shallow_includes('project/build/output/thing.o: header.h').returns(['header.h'])
    @file_path_utils.expects.form_preprocessed_includes_list_path('project/source/software.c').returns('project/build/preprocessed/includes/software.c')    
    @preprocessinator_includes_handler.expects.write_shallow_includes_list('project/build/preprocessed/includes/software.c', ['header.h'])

    @preprocessinator.preprocess_shallow_includes('project/source/software.c')
  end

  should "pass thru preprocess call to helper" do
    @preprocessinator_helper.expects.preprocess_file('project/source/material.c')

    @preprocessinator.preprocess_file('project/source/material.c')
  end

  should "form preprocessed file path if preprocessing is enabled" do
    @configurator.expects.project_use_preprocessor.returns(true)
    @file_path_utils.expects.form_preprocessed_file_path('project/files/a_file.c').returns('project/build/preprocessed/files/a_file.c')
    
    assert_equal('project/build/preprocessed/files/a_file.c', @preprocessinator.form_file_path('project/files/a_file.c'))
  end
  
end
