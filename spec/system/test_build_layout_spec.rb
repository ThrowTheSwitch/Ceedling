# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'
require 'json'

##
## Each Test's Own Build Directories (GH #1439)
## ============================================
##
## A test is named by its path, so one test's name can continue another's, as
## test/test_c/test_x continues test/test_c. A test's mock or Partial may also lie in a
## folder named like the nested test. Each per-test directory closes the test's name with
## `_t_`, so the two never share one.
##

LAYOUT_TEST_PREAMBLE = "#include \"unity.h\"\nvoid setUp(void) {}\nvoid tearDown(void) {}\n"

# The directories below which each test's own files lie, one directory per test
LAYOUT_PER_TEST_BASES = %w[
  build/test/mocks build/test/partials build/test/preprocess/includes build/test/preprocess/files
  build/test/preprocess/build_directives build/test/out build/test/dependencies
].freeze

ceedling_system_tests do
  include_context "a fresh ceedling gem project", "test_layout"

  def write(path, content)
    FileUtils.mkdir_p( File.dirname( path ) )
    File.write( path, content )
  end

  def build(task)
    output = @c.ceedling_build_exec( task )

    expect(@c.last_exit_status).to eq(0), output
    return output
  end

  def header(path, guard, declaration)
    write( path, "#ifndef #{guard}\n#define #{guard}\n#{declaration}\n#endif\n" )
  end

  # The test whose name continues test/test_c, beside test_c's own folder test_x
  def write_nested_test(body = "void test_b(void) {}\n")
    write( 'test/test_c/test_x.c', LAYOUT_TEST_PREAMBLE + body )
  end

  # test/test_c mocks a header in folder test_x
  def write_test_mocking_in_folder
    header( 'src/test_x/qux.h', 'QUX_H', 'int qux_read(void);' )
    write( 'test/test_c.c', LAYOUT_TEST_PREAMBLE + "#include \"test_x/mock_qux.h\"\n" \
                            "void test_a(void) { qux_read_ExpectAndReturn( 5 ); TEST_ASSERT_EQUAL_INT( 5, qux_read() ); }\n" )
  end

  it "builds a test's mock in a folder named like a nested test once that test exists" do
    in_project do
      write_test_mocking_in_folder
      build( 'test:test_c' )

      write_nested_test
      expect(build( 'test:test_c' )).to match(/PASSED:\s+1/)
      expect(build( 'test:test_x' )).to match(/PASSED:\s+1/)
      expect(build( 'test:all' )).to match(/PASSED:\s+2/)
    end
  end

  it "builds a test's Partial of a module in a folder named like a nested test once that test exists" do
    in_project do
      @c.merge_project_yml_for_test( { :project => { :use_partials => true } } )
      header( 'src/test_x/qux.h', 'QUX_H', 'int qux_read(void);' )
      write( 'src/test_x/qux.c', "#include \"qux.h\"\nstatic int helper(void) { return 7; }\nint qux_read(void) { return helper(); }\n" )
      write( 'test/test_c.c', LAYOUT_TEST_PREAMBLE + "#include \"ceedling.h\"\n#include TEST_PARTIAL_PRIVATE_MODULE_AT(test_x, qux)\n" \
                              "void test_a(void) { TEST_ASSERT_EQUAL_INT( 7, helper() ); }\n" )
      build( 'test:test_c' )

      write_nested_test
      expect(build( 'test:test_c' )).to match(/PASSED:\s+1/)
      expect(build( 'test:all' )).to match(/PASSED:\s+2/)
    end
  end

  # Two same-named headers: test_c mocks one by folder test_x, and the nested test the other bare
  it "keeps a nested test's mock apart from a same-named mock its parent places in a folder of that test's name" do
    in_project do
      @c.remove_project_yml_option_for_test( :paths, :include )
      @c.merge_project_yml_for_test( { :paths => { :include => ['src/'] } } )
      write_test_mocking_in_folder
      header( 'src/qux.h', 'ROOT_QUX_H', 'int qux_other(void);' )
      write_nested_test( "#include \"mock_qux.h\"\n" \
                         "void test_b(void) { qux_other_ExpectAndReturn( 6 ); TEST_ASSERT_EQUAL_INT( 6, qux_other() ); }\n" )

      2.times { expect(build( 'test:all' )).to match(/PASSED:\s+2/) }

      expect(File.read( 'build/test/mocks/test/test_c/_t_/test_x/mock_qux.h' )).to include( 'qux_read_ExpectAndReturn' )
      expect(File.read( 'build/test/mocks/test/test_c/test_x/_t_/mock_qux.h' )).to include( 'qux_other_ExpectAndReturn' )
    end
  end

  it "builds coverage of a test whose mock lies in a folder named like a nested test" do
    in_project do
      # Coverage reports would need a report utility this example doesn't exercise
      @c.merge_project_yml_for_test( { :plugins => { :enabled => ['gcov'] }, :gcov => { :report_task => true } } )
      write_test_mocking_in_folder
      write_nested_test

      expect(build( 'gcov:all' )).to match(/PASSED:\s+2/)
    end
  end

  # An earlier release placed each test's files at its name alone, and its cache holds that
  # layout's paths. Setting that cache aside rebuilds every test.
  it "rebuilds a build directory of the earlier layout without a clobber" do
    in_project do
      write_test_mocking_in_folder
      write_nested_test
      build( 'test:all' )

      write( 'build/test/mocks/test/test_c/test_x/mock_qux.h', "#error a mock of the earlier layout\n" )
      write( 'build/test/mocks/test/test_c/mock_qux.h', "#error a mock of the earlier layout\n" )
      Dir.glob( 'build/cache/.*.dep_cache.json' ).each do |path|
        File.write( path, JSON.generate( JSON.parse( File.read( path ) ).merge( 'schema_version' => 3 ) ) )
      end

      output = build( 'test:all' )

      expect(output).to match(/PASSED:\s+2/)
      expect(output).to match(/comes from an earlier Ceedling build layout -- rebuilding everything once/)
    end
  end

  # Gives each cache in build/cache a schema version an earlier release wrote
  def set_cache_schema(version, pattern = '.*.dep_cache.json')
    Dir.glob( File.join( 'build/cache', pattern ) ).each do |path|
      File.write( path, JSON.generate( JSON.parse( File.read( path ) ).merge( 'schema_version' => version ) ) )
    end
  end

  # A release build has no per-test directories, so the test layout leaves it as it was
  describe "a release build" do
    before do
      in_project do
        @c.merge_project_yml_for_test( { :project => { :release_build => true } } )
        header( 'src/_t_/foo.h', 'FOO_H', 'int foo(void);' )
        write( 'src/_t_/foo.c', "#include \"foo.h\"\nint foo(void) { return 0; }\n" )
        write( 'src/main.c', "#include \"foo.h\"\nint main(void) { return foo(); }\n" )
      end
    end

    it "places a source in a directory named `_t_` at its own path" do
      in_project do
        build( 'release' )

        expect(File.exist?( 'build/release/out/src/_t_/foo.o' )).to be( true )
        expect(File.exist?( 'build/release/dependencies/src/_t_/foo.d' )).to be( true )
      end
    end

    it "keeps its cache from an earlier release, compiling nothing" do
      in_project do
        build( 'release' )
        set_cache_schema( 3, '.release.dep_cache.json' )

        output = build( 'release' )

        expect(output).to_not match(/earlier Ceedling build layout/)
        expect(output).to_not match(/^Compiling /)
      end
    end
  end

  it "places every file below a per-test directory under its own test's `_t_` root" do
    in_project do
      @c.merge_project_yml_for_test( { :project => { :use_partials => true, :use_test_preprocessor => :all } } )
      header( 'src/test_x/qux.h', 'QUX_H', 'int qux_read(void);' )
      write( 'src/test_x/qux.c', "#include \"qux.h\"\nstatic int helper(void) { return 7; }\nint qux_read(void) { return helper(); }\n" )
      header( 'src/test_x/bar.h', 'BAR_H', 'int bar_read(void);' )
      header( 'src/baz.h', 'BAZ_H', 'int baz_read(void);' )
      write( 'test/test_c.c', LAYOUT_TEST_PREAMBLE + "#include \"ceedling.h\"\n#include \"test_x/mock_bar.h\"\n" \
                              "#include TEST_PARTIAL_PRIVATE_MODULE_AT(test_x, qux)\n" \
                              "void test_a(void) { bar_read_ExpectAndReturn( 3 ); TEST_ASSERT_EQUAL_INT( 10, helper() + bar_read() ); }\n" )
      write_nested_test( "#include \"mock_baz.h\"\n" \
                         "void test_b(void) { baz_read_ExpectAndReturn( 4 ); TEST_ASSERT_EQUAL_INT( 4, baz_read() ); }\n" )

      expect(build( 'test:all' )).to match(/PASSED:\s+2/)

      names = ['test/test_c', 'test/test_c/test_x']
      LAYOUT_PER_TEST_BASES.each do |base|
        files = Dir.glob( "#{base}/**/*", File::FNM_DOTMATCH ).select { |path| File.file?( path ) }
        expect(files).to_not be_empty, "#{base} holds no file"

        files.each do |file|
          name = file.delete_prefix( "#{base}/" ).split( '/_t_/', 2 ).first
          expect(names).to include( name ), "#{file} lies below no test's own root"
        end
      end

      # The nested test's own mock and objects, beside test_c's folder of the same name
      expect(File.exist?( 'build/test/mocks/test/test_c/test_x/_t_/mock_baz.c' )).to be( true )
      expect(File.exist?( 'build/test/mocks/test/test_c/_t_/test_x/mock_bar.c' )).to be( true )
      expect(File.exist?( 'build/test/out/test/test_c/test_x/_t_/test_x.out' )).to be( true )
      expect(File.exist?( 'build/test/out/test/test_c/_t_/test_c.out' )).to be( true )
    end
  end
end
