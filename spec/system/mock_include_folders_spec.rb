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
end
