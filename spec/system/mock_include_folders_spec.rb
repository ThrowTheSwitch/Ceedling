# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

##
## Mocks Named by the Folders Their #includes Spell
## ================================================
##
## CMock names a mock by the folder its #include names, and the compiler reaches the mock
## through that #include as written. Mock generation, stand-ins, compiled sources and search
## paths must all agree on where each mock lives (the path handling audit around GH #1370).
##

MOCK_FOLDER_PREAMBLE = "#include \"unity.h\"\nvoid setUp(void) {}\nvoid tearDown(void) {}\n"

ceedling_system_tests do
  include_context "a fresh ceedling gem project", "mock_folders"

  def write(path, content)
    FileUtils.mkdir_p( File.dirname( path ) )
    File.write( path, content )
  end

  def build(include_paths, preprocessor: :none)
    @c.merge_project_yml_for_test( { :project => { :use_test_preprocessor => preprocessor }, :paths => { :include => include_paths } } )
    output = @c.ceedling_build_exec( "test:all" )

    expect(@c.last_exit_status).to eq(0), output
    expect(output).to match(/PASSED:\s+1/)
  end

  it "builds two same-named mocks whose #include folders alone tell them apart" do
    in_project do
      write( 'inc/a/foo.h', "int a_read(void);\n" )
      write( 'inc/b/foo.h', "int b_read(void);\n" )
      write( 'test/test_c.c', MOCK_FOLDER_PREAMBLE + "#include \"a/mock_foo.h\"\n#include \"b/mock_foo.h\"\n" \
                              "void test_reads(void) { a_read_ExpectAndReturn(5); b_read_ExpectAndReturn(6); TEST_ASSERT_EQUAL_INT(11, a_read() + b_read()); }\n" )

      build( ['inc', 'inc/a', 'inc/b'] )
    end
  end

  it "builds two same-named mocks through a search path that lists only their parent" do
    in_project do
      write( 'inc/a/foo.h', "int a_read(void);\n" )
      write( 'inc/b/foo.h', "int b_read(void);\n" )
      write( 'test/test_c.c', MOCK_FOLDER_PREAMBLE + "#include \"a/mock_foo.h\"\n#include \"b/mock_foo.h\"\n" \
                              "void test_reads(void) { a_read_ExpectAndReturn(5); b_read_ExpectAndReturn(6); TEST_ASSERT_EQUAL_INT(11, a_read() + b_read()); }\n" )

      build( ['inc'] )
    end
  end

  # The mocks root carries the test's name, which the #include's folder happens to share
  it "builds a mock whose #include folder shares the test's own name" do
    in_project do
      write( 'inc/test_c/foo.h', "int foo_read(void);\n" )
      write( 'test/test_c.c', MOCK_FOLDER_PREAMBLE + "#include \"test_c/mock_foo.h\"\nvoid test_reads(void) { foo_read_ExpectAndReturn(5); TEST_ASSERT_EQUAL_INT(5, foo_read()); }\n" )

      build( ['inc', 'inc/test_c'] )
    end
  end

  it "builds a mock whose #include spells more path than its header's mirror without naming it by folder" do
    in_project do
      @c.merge_project_yml_for_test( { :cmock => { :mock_name_include_folder => false } } )
      write( 'inc/a/foo.h', "int foo_read(void);\n" )
      write( 'test/test_c.c', MOCK_FOLDER_PREAMBLE + "#include \"inc/a/mock_foo.h\"\nvoid test_reads(void) { foo_read_ExpectAndReturn(5); TEST_ASSERT_EQUAL_INT(5, foo_read()); }\n" )

      build( ['inc/**'] )
    end
  end

  # Each stand-in opens as its real mock will, through its own folder, so a macro one header
  # defines selects a mock only where that header is the one included
  it "reconciles #includes through the header each same-named mock's folder names" do
    in_project do
      write( 'inc/a/foo.h', "int a_read(void);\n" )
      write( 'inc/b/foo.h', "#define USE_B_EXTRA 1\nint b_read(void);\n" )
      write( 'inc/extra.h', "int extra(void);\n" )
      write( 'test/test_c.c', MOCK_FOLDER_PREAMBLE + "#include \"a/mock_foo.h\"\n#include \"b/mock_foo.h\"\n#if USE_B_EXTRA\n#include \"mock_extra.h\"\n#endif\n" \
                              "void test_reads(void) { a_read_ExpectAndReturn(5); b_read_ExpectAndReturn(6); extra_ExpectAndReturn(1); TEST_ASSERT_EQUAL_INT(12, a_read() + b_read() + extra()); }\n" )

      build( ['inc/**'], preprocessor: :all )
    end
  end

  it "leaves a mock #include in a branch that is off out of a preprocessed build" do
    in_project do
      write( 'inc/x/foo.h', "int foo_read(void);\n" )
      write( 'test/test_c.c', MOCK_FOLDER_PREAMBLE + "#include \"x/mock_foo.h\"\n#if 0\n#include \"../legacy/mock_old.h\"\n#endif\n" \
                              "void test_reads(void) { foo_read_ExpectAndReturn(5); TEST_ASSERT_EQUAL_INT(5, foo_read()); }\n" )

      build( ['inc/**'], preprocessor: :all )
    end
  end

  # Test preprocessing finds each mock at its place below its mirror root, which can carry
  # folders the test's #include never wrote. A mock keeps the name its #include gives it, so a
  # test calling a mock's own functions calls them by that name in every preprocessing mode.
  context "named by its #include in every preprocessing mode" do
    [:mocks, :tests, :all].product( [false, true] ).each do |preprocessor, fallback|
      mode = fallback ? ' with fallback preprocessing' : ''

      it "names a mock of a header below its glob root by its #include under :use_test_preprocessor #{preprocessor}#{mode}" do
        in_project do
          @c.merge_project_yml_for_test( { :test_build => { :preprocess_force_fallback => true } } ) if fallback
          write( 'rtos/include/task.h', "int task_run(int x);\n" )
          write( 'test/test_c.c', MOCK_FOLDER_PREAMBLE + "#include \"mock_task.h\"\n" \
                                  "void test_run(void) { task_run_ExpectAndReturn(1, 2); TEST_ASSERT_EQUAL_INT(2, task_run(1)); mock_task_Verify(); }\n" )

          build( ['rtos/**'], preprocessor: preprocessor )
        end
      end
    end

    # A pathless mock and one naming a folder can mock two headers of one name, and two
    # #includes of one header's mock give it one mock, named by the one with more path
    [:none, :mocks, :tests, :all].each do |preprocessor|
      it "keeps a pathless mock beside a same-named mock its folder names under :use_test_preprocessor #{preprocessor}" do
        in_project do
          write( 'rtos/include/task.h', "int task_run(int x);\n" )
          write( 'rtos/other/task.h', "int other_run(int x);\n" )
          write( 'test/test_c.c', MOCK_FOLDER_PREAMBLE + "#include \"mock_task.h\"\n#include \"other/mock_task.h\"\n" \
                                  "void test_run(void) { task_run_ExpectAndReturn(1, 2); other_run_ExpectAndReturn(3, 4); " \
                                  "TEST_ASSERT_EQUAL_INT(6, task_run(1) + other_run(3)); mock_task_Verify(); other_mock_task_Verify(); }\n" )

          build( ['rtos/**'], preprocessor: preprocessor )
        end
      end

      # The pathless mock's source sits in the test's mock root, which the other's name ends too
      it "keeps a pathless mock of a header at a search path's root beside a same-named mock under :use_test_preprocessor #{preprocessor}" do
        in_project do
          write( 'inc/task.h', "int r_run(int x);\n" )
          write( 'inc/b/task.h', "int b_run(int x);\n" )
          write( 'test/test_c.c', MOCK_FOLDER_PREAMBLE + "#include \"mock_task.h\"\n#include \"b/mock_task.h\"\n" \
                                  "void test_run(void) { r_run_ExpectAndReturn(0, 1); b_run_ExpectAndReturn(3, 4); TEST_ASSERT_EQUAL_INT(5, r_run(0) + b_run(3)); }\n" )

          build( ['inc/**'], preprocessor: preprocessor )
        end
      end

      it "gives one header one mock when two #includes name it under :use_test_preprocessor #{preprocessor}" do
        in_project do
          write( 'rtos/include/task.h', "int task_run(int x);\n" )
          write( 'test/test_c.c', MOCK_FOLDER_PREAMBLE + "#include \"mock_task.h\"\n#include \"include/mock_task.h\"\n" \
                                  "void test_run(void) { task_run_ExpectAndReturn(1, 2); TEST_ASSERT_EQUAL_INT(2, task_run(1)); include_mock_task_Verify(); }\n" )

          build( ['rtos/**'], preprocessor: preprocessor )
        end
      end
    end

    # Neither folder reaches the other's mock, so each spelling keeps a file to reach
    [:tests, :all].each do |preprocessor|
      it "builds a test that names one header's mock by two folders under :use_test_preprocessor #{preprocessor}" do
        in_project do
          write( 'src/drivers/task.h', "int task_run(int x);\n" )
          write( 'test/test_c.c', MOCK_FOLDER_PREAMBLE + "#include \"drivers/mock_task.h\"\n#include \"src/drivers/mock_task.h\"\n" \
                                  "void test_run(void) { task_run_ExpectAndReturn(1, 2); TEST_ASSERT_EQUAL_INT(2, task_run(1)); }\n" )

          build( ['src/**'], preprocessor: preprocessor )
        end
      end
    end

    it "names two same-named mocks by the folders their #includes write under :use_test_preprocessor all" do
      in_project do
        write( 'inc/x/a/foo.h', "int a_read(void);\n" )
        write( 'inc/y/b/foo.h', "int b_read(void);\n" )
        write( 'test/test_c.c', MOCK_FOLDER_PREAMBLE + "#include \"a/mock_foo.h\"\n#include \"b/mock_foo.h\"\n" \
                                "void test_reads(void) { a_read_ExpectAndReturn(5); b_read_ExpectAndReturn(6); " \
                                "TEST_ASSERT_EQUAL_INT(11, a_read() + b_read()); a_mock_foo_Verify(); b_mock_foo_Verify(); }\n" )

        build( ['inc/**'], preprocessor: :all )
      end
    end

    # The mock stays in its header's mirrored directory either way, so only its names change
    [:none, :all].each do |preprocessor|
      it "regenerates a mock whose #include drops its folder under :use_test_preprocessor #{preprocessor}" do
        in_project do
          write( 'rtos/include/task.h', "int task_run(int x);\n" )
          body = "void test_run(void) { task_run_ExpectAndReturn(1, 2); TEST_ASSERT_EQUAL_INT(2, task_run(1)); }\n"
          write( 'test/test_c.c', MOCK_FOLDER_PREAMBLE + "#include \"include/mock_task.h\"\n" + body )
          build( ['rtos/**'], preprocessor: preprocessor )

          write( 'test/test_c.c', MOCK_FOLDER_PREAMBLE + "#include \"mock_task.h\"\n" + body )
          output = @c.ceedling_build_exec( "test:all" )
          expect(@c.last_exit_status).to eq(0), output
          expect(output).to match(/PASSED:\s+1/)
        end
      end
    end

    it "names a mock a macro in the test file names by that #include under :use_test_preprocessor all" do
      in_project do
        write( 'rtos/include/task.h', "int task_run(int x);\n" )
        write( 'test/test_c.c', MOCK_FOLDER_PREAMBLE + "#define TASK_MOCK \"mock_task.h\"\n#include TASK_MOCK\n" \
                                "void test_run(void) { task_run_ExpectAndReturn(1, 2); TEST_ASSERT_EQUAL_INT(2, task_run(1)); mock_task_Verify(); }\n" )

        build( ['rtos/**'], preprocessor: :all )
      end
    end
  end
end
