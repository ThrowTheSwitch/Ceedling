require File.dirname(__FILE__) + '/../unit_test_helper'
require 'preprocessinator'


class PreprocessinatorTest < Test::Unit::TestCase

  def setup
    objects = create_mocks(:configurator, :preprocessinator_helper, :preprocessinator_includes_handler, :preprocessinator_file_handler, :task_invoker, :file_path_utils, :yaml_wrapper)
    @preprocessinator = Preprocessinator.new(objects)
  end

  def teardown
  end
  
  
  should "preprocess tests and invoke mocks" do
    create_mocks(:tests_list, :mocks_list)

    @preprocessinator_helper.expects.assemble_test_list(['tests/tweedle_test.c', 'tests/dumb_test.c']).returns(@tests_list)
    @preprocessinator_helper.expects.preprocess_includes(@tests_list)
    @preprocessinator_helper.expects.assemble_mocks_list.returns(@mocks_list)
    @preprocessinator_helper.expects.preprocess_mockable_headers(@mocks_list, @preprocessinator.preprocess_file_proc)
    @task_invoker.expects.invoke_mocks(@mocks_list)
    @preprocessinator_helper.expects.preprocess_test_files(@tests_list, @preprocessinator.preprocess_file_proc)

    assert_equal(@mocks_list, @preprocessinator.preprocess_tests_and_invoke_mocks(['tests/tweedle_test.c', 'tests/dumb_test.c']))
  end
  
  should "preprocess shallow includes for a given file and write them to disk" do
    @preprocessinator_includes_handler.expects.form_shallow_dependencies_rule('project/source/software.c').returns('project/build/output/thing.o: header.h')
    @preprocessinator_includes_handler.expects.extract_shallow_includes('project/build/output/thing.o: header.h').returns(['header.h'])
    @file_path_utils.expects.form_preprocessed_includes_list_path('project/source/software.c').returns('project/build/preprocessed/includes/software.c')    
    @preprocessinator_includes_handler.expects.write_shallow_includes_list('project/build/preprocessed/includes/software.c', ['header.h'])

    @preprocessinator.preprocess_shallow_includes('project/source/software.c')
  end
  
  should "preprocess a file" do
    includes = ['types.h', 'a_widdle_file.h']
    mocks_filelist = ['project/build/mocks/mock_and_roll.c', 'project/build/mocks/mock_em_sock_em.c']

    @preprocessinator_includes_handler.expects.invoke_shallow_includes_list('source/a_widdle_file.c')
    @file_path_utils.expects.form_preprocessed_includes_list_path('source/a_widdle_file.c').returns('project/build/preprocess/includes/a_widdle_file.c')
    @yaml_wrapper.expects.load('project/build/preprocess/includes/a_widdle_file.c').returns(includes)
    @preprocessinator_file_handler.expects.preprocess_file('source/a_widdle_file.c', includes)

    @preprocessinator.preprocess_file('source/a_widdle_file.c')
  end

  should "form preprocessed file path if preprocessing is enabled" do
    @configurator.expects.project_use_preprocessor.returns(true)
    @file_path_utils.expects.form_preprocessed_file_path('project/files/a_file.c').returns('project/build/preprocessed/files/a_file.c')
    
    assert_equal('project/build/preprocessed/files/a_file.c', @preprocessinator.form_file_path('project/files/a_file.c'))
  end
  
end
