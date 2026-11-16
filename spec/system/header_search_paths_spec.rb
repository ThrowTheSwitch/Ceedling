# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

##
## Headers Found Through Search Paths as the Compiler Finds Them
## =============================================================
##
## A test's #include names a header by its path below a search path, and the compiler
## joins each search path with that path in turn. Ceedling finds a mock's header, and
## checks a test's plain #includes, the same way, so a search path need not list every
## directory below it.
##

HEADER_SEARCH_PREAMBLE = "#include \"unity.h\"\nvoid setUp(void) {}\nvoid tearDown(void) {}\n"

ceedling_system_tests do
  include_context "a fresh ceedling gem project", "header_search"

  def write(path, content)
    FileUtils.mkdir_p( File.dirname( path ) )
    File.write( path, content )
  end

  # Merging adds to a list, so the new project's own include paths are removed first
  def configure(include_paths, preprocessor, extra = {})
    @c.remove_project_yml_option_for_test( :paths, :include )
    @c.merge_project_yml_for_test( { :project => { :use_test_preprocessor => preprocessor }, :paths => { :include => include_paths } }.merge( extra ) )
  end

  def build_passes
    output = @c.ceedling_build_exec( "test:all" )

    expect(@c.last_exit_status).to eq(0), output
    expect(output).to match(/PASSED:\s+1/)
    return output
  end

  [:none, :mocks, :all].each do |preprocessor|
    context "with :use_test_preprocessor #{preprocessor}" do
      it "mocks a header named by its directory below a search path that doesn't list that directory" do
        in_project do
          write( 'src/drivers/foo.h', "int foo_read(void);\n" )
          write( 'test/test_c.c', HEADER_SEARCH_PREAMBLE + "#include \"drivers/mock_foo.h\"\n" \
                                  "void test_reads(void) { foo_read_ExpectAndReturn(5); TEST_ASSERT_EQUAL_INT(5, foo_read()); }\n" )

          configure( ['src'], preprocessor )
          build_passes
        end
      end

      it "includes a header named by its directory below a search path that doesn't list that directory" do
        in_project do
          write( 'src/drivers/foo.h', "#define FOO_MAGIC 7\n" )
          write( 'test/test_c.c', HEADER_SEARCH_PREAMBLE + "#include \"drivers/foo.h\"\n" \
                                  "void test_magic(void) { TEST_ASSERT_EQUAL_INT(7, FOO_MAGIC); }\n" )

          configure( ['src'], preprocessor )
          build_passes
        end
      end

      it "includes the header below the first search path holding the path, as the compiler does" do
        in_project do
          write( 'a/drivers/foo.h', "#define FOO_MAGIC 1\n" )
          write( 'b/drivers/foo.h', "#define FOO_MAGIC 2\n" )
          write( 'test/test_c.c', HEADER_SEARCH_PREAMBLE + "#include \"drivers/foo.h\"\n" \
                                  "void test_magic(void) { TEST_ASSERT_EQUAL_INT(1, FOO_MAGIC); }\n" )

          configure( ['a', 'b'], preprocessor )
          output = build_passes

          # A preprocessed test file's #include names the header GCC already chose
          expect(output).to include( "Multiple files matched 'drivers/foo.h' but chose 'a/drivers/foo.h'" ) unless preprocessor == :all
        end
      end

      it "mocks the header below the search path TEST_INCLUDE_PATH() puts first" do
        in_project do
          write( 'a/drivers/foo.h', "int a_read(void);\n" )
          write( 'b/drivers/foo.h', "int b_read(void);\n" )
          write( 'test/test_c.c', HEADER_SEARCH_PREAMBLE + "TEST_INCLUDE_PATH(\"b\")\n#include \"drivers/mock_foo.h\"\n" \
                                  "void test_reads(void) { b_read_ExpectAndReturn(5); TEST_ASSERT_EQUAL_INT(5, b_read()); }\n" )

          configure( ['a', 'b'], preprocessor )
          build_passes
        end
      end
    end
  end

  # CMock writes its copy of a header beside the mock with :treat_inlines :include. The mock
  # directory is a search path, but never one a real header is found through.
  it "mocks a header from the project, never from CMock's copy of it, on later builds" do
    in_project do
      write( 'src/foo.h', "int foo_read(void);\n" )
      write( 'test/test_c.c', HEADER_SEARCH_PREAMBLE + "#include \"mock_foo.h\"\n" \
                              "void test_reads(void) { foo_read_ExpectAndReturn(5); TEST_ASSERT_EQUAL_INT(5, foo_read()); }\n" )

      configure( ['src'], :none, { :cmock => { :treat_inlines => :include } } )
      build_passes
      expect(build_passes).to_not include( 'Multiple files matched' )

      write( 'src/foo.h', "int foo_read(void);\nint foo_more(void);\n" )
      write( 'test/test_c.c', HEADER_SEARCH_PREAMBLE + "#include \"mock_foo.h\"\n" \
                              "void test_reads(void) { foo_more_ExpectAndReturn(6); TEST_ASSERT_EQUAL_INT(6, foo_more()); }\n" )
      build_passes
    end
  end
end
