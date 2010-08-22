require File.dirname(__FILE__) + '/../unit_test_helper'
require 'preprocessinator_includes_handler'


class PreprocessinatorIncludesHandlerTest < Test::Unit::TestCase

  def setup
    objects = create_mocks(:configurator, :tool_executor, :task_invoker, :file_path_utils, :yaml_wrapper, :file_wrapper)
    @preprocessinator_includes_handler = PreprocessinatorIncludesHandler.new(objects)
  end

  def teardown
  end
  
  
  should "invoke a shallow includes list" do
    @file_path_utils.expects.form_preprocessed_includes_list_path('tests/test_me_please.c').returns('project/build/preprocess/includes/test_me_please.c')
    @task_invoker.expects.invoke_shallow_include_lists('project/build/preprocess/includes/test_me_please.c')

    @preprocessinator_includes_handler.invoke_shallow_includes_list('tests/test_me_please.c')
  end
  
  
  should "form a make-style dependency rule that lists decorated names of only those headers included in a source file" do
    source_file = %Q[
      #include "unity.h"
      #include "CException.h"
      #include "extra_thing2.h"
      #include <setjmp.h>
      #include <stdio.h>
      #include "mock_abc.h"

      int Stuff;

      void foo(void);
      ].left_margin(0)

    decorated_temp_file = %Q[
      #include "@@@@unity.h"
      #include "@@@@CException.h"
      #include "@@@@extra_thing2.h"
      #include <setjmp.h>
      #include <stdio.h>
      #include "@@@@mock_abc.h"

      int Stuff;

      void foo(void);
      ].left_margin(0)

    includes_preprocessor_tool = {:name => 'includes preprocessor', :executable => 'gcc'}

    @file_path_utils.expects.form_temp_path('tests/test_me_please.c').returns('build/temp/test_me_please.c')
    
    @file_wrapper.expects.read('tests/test_me_please.c').returns(source_file)
    @file_wrapper.expects.write('build/temp/test_me_please.c', decorated_temp_file)
    
    @configurator.expects.tools_includes_preprocessor.returns(includes_preprocessor_tool)
    @tool_executor.expects.build_command_line(includes_preprocessor_tool, 'build/temp/test_me_please.c').returns("gcc -MG preprocessor args")
    @tool_executor.expects.exec("gcc -MG preprocessor args").returns("fake make-style dependency rule")
    @file_wrapper.expects.rm_f('build/temp/test_me_please.c')
    
    assert_equal("fake make-style dependency rule", @preprocessinator_includes_handler.form_shallow_dependencies_rule('tests/test_me_please.c'))
  end
  
  
  should "extract immediately included header files from source file's decorated dependencies scan" do
    dependency_rule = %Q[
      project/build/out/a_file.o:  \
       project/source/a_file.c \
        @@@@a_file.h \
        @@@@api.h \
        @@@@types.h \
        @@@@ignore.c
      ].left_margin(0)

    @configurator.expects.extension_header.returns('.h')

    assert_equal(
      ['a_file.h', 'api.h', 'types.h'],
      @preprocessinator_includes_handler.extract_shallow_includes(dependency_rule))
  end  
  
  
  should "write shallow includes list to yaml file" do
    includes = ['unity.h', 'a_file.h']
    
    @yaml_wrapper.expects.dump('project/build/preprocess/includes/test_me_please.c', includes)

    @preprocessinator_includes_handler.write_shallow_includes_list('project/build/preprocess/includes/test_me_please.c', includes)
  end
  
end
