require File.dirname(__FILE__) + '/../unit_test_helper'
require 'preprocessinator_file_handler'


class PreprocessinatorFileHandlerTest < Test::Unit::TestCase

  def setup
    objects = create_mocks(:preprocessinator_extractor, :configurator, :tool_executor, :file_path_utils, :file_wrapper)
    @preprocessinator_file_handler = PreprocessinatorFileHandler.new(objects)
  end

  def teardown
  end
  
  
  should "preprocess a file" do
    create_mock(:tool_config)

    expected_file = %Q[
      #include "other_file.h"
      #include "file.h"
      
      void foo(void)
      {
      }
      ].left_margin(0)

    @file_path_utils.expects.form_preprocessed_file_path('project/source/file.c').returns('project/build/preprocessed/files/file.c')
    @configurator.expects.tools_file_preprocessor.returns(@tool_config)
    @tool_executor.expects.build_command_line(@tool_config, 'project/source/file.c', 'project/build/preprocessed/files/file.c').returns('boring command line')
    @tool_executor.expects.exec('boring command line').returns('')
    @preprocessinator_extractor.expects.extract_base_file_from_preprocessed_expansion('project/build/preprocessed/files/file.c').returns(['', 'void foo(void)', '{', '}'])
    @file_wrapper.expects.write('project/build/preprocessed/files/file.c', expected_file.strip)

    @preprocessinator_file_handler.preprocess_file('project/source/file.c', ['file.h', 'other_file.h'])
  end
  
end
