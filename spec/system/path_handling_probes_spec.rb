# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'
require 'tmpdir'

##
## Path Handling Through Real Builds (GH #1370 and the audit around it)
## ======================================================================
##
## Each example builds a project whose configuration names paths in a way the path
## handling audit found unsafe, and names the gap it probes. The project sits at `app/`
## within its own directory, so a `..` root reaches only that directory, never a
## neighboring project.
##

PROBE_TEST_PREAMBLE = "#include \"unity.h\"\nvoid setUp(void) {}\nvoid tearDown(void) {}\n"

ceedling_system_tests do
  include_context "a fresh ceedling gem project", "path_probe"

  # Moves the fresh project into `app/` and runs the block from there
  def in_app
    in_project do
      FileUtils.mkdir_p( 'app' )
      FileUtils.mv( Dir.children( '.' ) - ['app'], 'app' )
      Dir.chdir( 'app' ) { yield File.expand_path( '..' ) }
    end
  end

  def write(path, content)
    FileUtils.mkdir_p( File.dirname( path ) )
    File.write( path, content )
  end

  # The report's setup: a vendor SDK far above the project, beside a `..` root
  it "G1 (#1370): mocks a header far outside the project beside a `..` root" do
    Dir.mktmpdir do |far|
      sdk = File.join( File.realpath( far ), 'deep', 'sdk', 'inc' )
      write( File.join( sdk, 'sdk.h' ), "int sdk_read(void);\n" )

      in_app do |parent|
        write( 'test/test_m.c', PROBE_TEST_PREAMBLE + "#include \"mock_sdk.h\"\nvoid test_reads(void) { sdk_read_ExpectAndReturn(3); TEST_ASSERT_EQUAL_INT(3, sdk_read()); }\n" )
        # The exclusion must name an existing directory, which the build root is not before a first build
        FileUtils.mkdir_p( 'build' )
        @c.merge_project_yml_for_test( { :paths => { :include => ['../**', '-:../app/build/**', sdk] } } )

        output = @c.ceedling_build_exec( "test:all" )

        expect(@c.last_exit_status).to eq(0), output
        expect(output).to match(/PASSED:\s+1/)
        expect(Dir.children( parent ) - ['app']).to be_empty
      end
    end
  end

  it "G4: links the source beside a header below a `./` include root" do
    in_app do
      write( 'include/drv/x.h', "int x_value(void);\n" )
      write( 'src/drv/x.c', "#include \"x.h\"\nint x_value(void) { return 7; }\n" )
      write( 'test/test_x.c', PROBE_TEST_PREAMBLE + "#include \"x.h\"\nvoid test_value(void) { TEST_ASSERT_EQUAL_INT(7, x_value()); }\n" )
      @c.merge_project_yml_for_test( { :project => { :use_test_preprocessor => :all }, :paths => { :include => ['./include/**'] } } )

      output = @c.ceedling_build_exec( "test:all" )

      expect(@c.last_exit_status).to eq(0), output
      expect(output).to match(/PASSED:\s+1/)
    end
  end

  it "G5: compiles both of two same-named sources below two roots into a release" do
    in_app do
      write( 'src/foo.c', "int foo_a(void) { return 1; }\n" )
      write( 'lib/foo.c', "int foo_b(void) { return 2; }\n" )
      write( 'src/main.c', "int foo_a(void);\nint foo_b(void);\nint main(void) { return foo_a() + foo_b() - 3; }\n" )
      @c.merge_project_yml_for_test( { :project => { :release_build => true }, :paths => { :source => ['src/**', 'lib/**'] } } )

      output = @c.ceedling_build_exec( "release" )

      expect(@c.last_exit_status).to eq(0), output
    end
  end

  # The compiler resolves a mock's #include as written, from the test's own directory,
  # where no generated mock can be
  it "G14: refuses a mock #include that climbs with `..`, naming the test file and a fix" do
    in_app do
      write( 'inc/x/foo.h', "int foo_read(void);\n" )
      write( 'test/test_c.c', PROBE_TEST_PREAMBLE + "#include \"../inc/x/mock_foo.h\"\nvoid test_reads(void) { foo_read_ExpectAndReturn(5); TEST_ASSERT_EQUAL_INT(5, foo_read()); }\n" )
      @c.merge_project_yml_for_test( { :paths => { :include => ['inc/**'] } } )

      output = @c.ceedling_build_exec( "test:all" )

      expect(@c.last_exit_status).to_not eq(0)
      expect(output).to match(%r{test/test_c\.c includes the mock `\.\./inc/x/mock_foo\.h`})
      expect(output).to include( '#include "mock_foo.h"' )
    end
  end

  # Assumes Ceedling refuses a build root holding the project's own directories
  it "G16: never lets clobber empty the project's own test directory", pending: "G16: clobber deletes the test directory" do
    in_app do
      write( 'test/test_keep.c', PROBE_TEST_PREAMBLE + "void test_it(void) {}\n" )
      @c.merge_project_yml_for_test( { :project => { :build_root => '.' } } )

      @c.ceedling_build_exec( "clobber" )

      expect(File.exist?( 'test/test_keep.c' )).to be( true )
    end
  end

  it "reports coverage of a source in a sibling directory outside the project" do
    in_app do |parent|
      write( File.join( parent, 'shared', 'src', 'calc.c' ), "#include \"calc.h\"\nint calc(int a) { return a + 1; }\n" )
      write( File.join( parent, 'shared', 'src', 'calc.h' ), "int calc(int a);\n" )
      write( 'test/test_calc.c', PROBE_TEST_PREAMBLE + "#include \"calc.h\"\nvoid test_calc(void) { TEST_ASSERT_EQUAL_INT(2, calc(1)); }\n" )
      @c.merge_project_yml_for_test( {
        :plugins => { :enabled => ['gcov'] },
        :paths   => { :source => ['../shared/src/**'], :include => ['../shared/src/**'] }
      } )

      output = @c.ceedling_build_exec( "gcov:all" )

      expect(@c.last_exit_status).to eq(0), output
      expect(output).to match(/calc\.c/)
    end
  end
end
