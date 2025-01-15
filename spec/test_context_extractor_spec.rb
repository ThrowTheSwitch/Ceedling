# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/test_context_extractor'
require 'ceedling/parsing_parcels'
require 'ceedling/exceptions'

describe TestContextExtractor do
  before(:each) do
    # Mock injected dependencies
    @parsing_parcels = ParsingParcels.new()
    @configurator = double( "Configurator" ) # Use double() so we can mock needed methods that are added dynamically at startup
    @file_wrapper = double( "FileWrapper" ) # Not actually exercised in these test cases
    loginator = instance_double( "Loginator" )
    
    # Ignore all logging calls
    allow(loginator).to receive(:log)

    # Provide configurations
    mock_prefix = 'mock_'

    # Rely on defaults in Unity's test runner generator
    test_runner_config = {
      :cmdline_args => false,
      :mock_prefix => mock_prefix,
      :mock_suffix => '',
      :enforce_strict_ordering => false,
      :defines => [],
      :use_param_tests => false
    }

    allow(@configurator).to receive(:cmock_mock_prefix).and_return( mock_prefix )
    allow(@configurator).to receive(:extension_header).and_return( '.h' )
    allow(@configurator).to receive(:extension_source).and_return( '.c' )
    allow(@configurator).to receive(:get_runner_config).and_return( test_runner_config )

    @extractor = described_class.new(
      {
        :configurator => @configurator,
        :file_wrapper => @file_wrapper,
        :parsing_parcels => @parsing_parcels,
        :loginator => loginator
      }
    )
  end

  context "#lookup_full_header_includes_list" do
    it "should provide empty list when no context extraction has occurred" do
      expect( @extractor.lookup_full_header_includes_list( "path" ) ).to eq []
    end
  end

  context "#lookup_header_includes_list" do
    it "should provide empty list when no context extraction has occurred" do
      expect( @extractor.lookup_header_includes_list( "path" ) ).to eq []
    end
  end

  context "#lookup_include_paths_list" do
    it "should provide empty list when no context extraction has occurred" do
      expect( @extractor.lookup_include_paths_list( "path" ) ).to eq []
    end
  end

  context "#lookup_source_includes_list" do
    it "should provide empty list when no context extraction has occurred" do
      expect( @extractor.lookup_source_includes_list( "path" ) ).to eq []
    end
  end

  context "#lookup_build_directive_sources_list" do
    it "should provide empty list when no context extraction has occurred" do
      expect( @extractor.lookup_build_directive_sources_list( "path" ) ).to eq []
    end
  end

  context "#lookup_test_cases" do
    it "should provide empty list when no context extraction has occurred" do
      expect( @extractor.lookup_test_cases( "path" ) ).to eq []
    end
  end

  context "#lookup_test_runner_generator" do
    it "should provide no generator when no context extraction has occurred" do
      expect( @extractor.lookup_test_runner_generator( "path" ) ).to eq nil
    end
  end

  context "#lookup_raw_mock_list" do
    it "should provide empty list when no context extraction has occurred" do
      expect( @extractor.lookup_raw_mock_list( "path" ) ).to eq []
    end
  end

  context "#extract_includes" do
    it "should extract #include directives from code" do
      # Complex comments tested in `clean_code_line()` test case
      file_contents = <<~CONTENTS
      #include "some_source.h"
      #include "more_source.h"

      #include  "some_source.h"          // Duplicate to be ignored

        #include "unity.h"

      #include "mock_File.h"
        #include "mock_another_file.h"
      #include  " mock_another_file.h "  // Duplicate to be ignored
      CONTENTS

      input = StringIO.new( file_contents )

      expected = [
        'some_source.h',
        'more_source.h',
        'unity.h',
        'mock_File.h',
        'mock_another_file.h'
      ]

      expect( @extractor.extract_includes( input ) ).to eq expected
    end
  end

  context "#collect_simple_context" do
    it "should raise an execption for unknown symbol argument" do
      expect{ @extractor.collect_simple_context( "path", StringIO.new(), :bad ) }.to raise_error( CeedlingException )
    end

    # collect_simple_context() + lookup_full_header_includes_list() + lookup_header_includes_list() + lookup_raw_mock_list()
    it "should extract contents of #include directives" do
      filepath = "path/tests/test_file.c"
      
      # Complex comments tested in `clean_code_line()` test case
      file_contents = <<~CONTENTS
      #include "some_source.h"
      #include "more_source.h"

      #include  "some_source.h"          // Duplicate to be ignored

        #include "unity.h"

      #include "mock_File.h"
        #include "mock_another_file.h"
      #include  " mock_another_file.h "  // Duplicate to be ignored
      CONTENTS

      input = StringIO.new( file_contents )

      @extractor.collect_simple_context( filepath, input, :includes )

      expected_full = [
        'some_source.h',
        'more_source.h',
        'unity.h',
        'mock_File.h',
        'mock_another_file.h'
      ]

      expected_trim = [
        'some_source.h',
        'more_source.h'
      ]

      expected_mocks = [
        'mock_File',
        'mock_another_file'
      ]

      expect( @extractor.lookup_full_header_includes_list( filepath ) ).to eq expected_full

      expect( @extractor.lookup_header_includes_list( filepath ) ).to eq expected_trim

      expect( @extractor.lookup_raw_mock_list( filepath ) ).to eq expected_mocks
    end

    # collect_simple_context() + lookup_build_directive_sources_list()
    it "should extract extra source files by build directive macros" do
      filepath = "path/tests/testfile.c"
      
      # Complex comments tested in `clean_code_line()` test case
      file_contents = <<~CONTENTS
      TEST_SOURE_FILE("bad_directive.c")              // Typo in macro name that blocks recognition

      TEST_SOURCE_FILE("a.c") TEST_SOURCE_FILE("b.c") // Repeated calls on same line

        TEST_SOURCE_FILE("path/baz.c")                // Leading whitespace to ignore
      TEST_SOURCE_FILE( "some\\path\\boo.c"  )        // Spaces in macro call + path separators to fix

      TEST_SOURCE_FILE()                              // Incomplete macro call that should be ignored
      CONTENTS

      input = StringIO.new( file_contents )

      @extractor.collect_simple_context( filepath, input, :build_directive_source_files )

      expected = [
        'a.c',
        'b.c',
        'path/baz.c',
        'some/path/boo.c'
      ]

      expect( @extractor.lookup_build_directive_sources_list( filepath ) ).to eq expected
    end

    # collect_simple_context() + lookup_include_paths_list()
    it "should extract extra header search paths by build directive macros" do
      filepath = "path/tests/testfile.c"
      
      # Complex comments tested in `clean_code_line()` test case
      file_contents = <<~CONTENTS
      TEST_INCLUE_PATH("bad_directive/")            // Typo in macro name that blocks recognition

      TEST_INCLUDE_PATH("a") TEST_INCLUDE_PATH("b") // Repeated calls on same line

        TEST_INCLUDE_PATH("this/path")              // Leading whitespace to ignore
      TEST_INCLUDE_PATH( "some\\dir\\path/"  )      // Spaces in macro call + path separators to fix

      TEST_INCLUDE_PATH()                           // Incomplete macro call that should be ignored
      CONTENTS

      input = StringIO.new( file_contents )

      @extractor.collect_simple_context( filepath, input, :build_directive_include_paths )

      expected = [
        'a',
        'b',
        'this/path',
        'some/dir/path'
      ]

      expect( @extractor.lookup_include_paths_list( filepath ) ).to eq expected
    end

    # collect_simple_context() + lookup_all_include_paths()
    it "should extract extra header search paths for multiple files" do
      # First File
      filepath = "path/tests/testfile.c"
      
      # Complex comments tested in `clean_code_line()` test case
      file_contents = <<~CONTENTS
      TEST_INCLUDE_PATH("this/path")
      TEST_INCLUDE_PATH("some/other/path")
      CONTENTS

      input = StringIO.new( file_contents )

      @extractor.collect_simple_context( filepath, input, :build_directive_include_paths )

      # Second File
      filepath = "anotherfile.c"
      
      # Complex comments tested in `clean_code_line()` test case
      file_contents = <<~CONTENTS
      TEST_INCLUDE_PATH("more/paths")
      TEST_INCLUDE_PATH("yet/more/paths")
      TEST_INCLUDE_PATH("this/path")       // Duplicated from first file
      CONTENTS

      input = StringIO.new( file_contents )

      @extractor.collect_simple_context( filepath, input, :build_directive_include_paths )

      expected = [
        'this/path',
        'some/other/path',
        'more/paths',
        'yet/more/paths'
      ]

      expect( @extractor.lookup_all_include_paths() ).to eq expected
    end

    # collect_simple_context() + lookup_test_cases()
    it "should extract test case names with line numbers" do
      filepath = "path/tests/testfile.c"
      
      # Comments exercised because test case extraction relies on Unity's generate_test_runner.rb.
      # Unity's Ruby code has its own handling of comments
      file_contents = <<~CONTENTS

      void test_this_function() {
        // TEST_ASSERT_TRUE( 1 == 1);
      }

      /*
        void test_this_other_function() {   // Ignored due to comment block
          TEST_ASSERT_FALSE( 0 == 1 );
        }
      */

       void   test_another_function( void )
      {
        // TEST_ASSERT_TRUE( 1 == 1);
      }

      void TestME() {                       // Ignored because of naming mismatch
        TEST_ASSERT_TRUE( 1 == 1);
      }

      // void test_somestuff(void) {        // Ignored due to comment lines
      //  // TEST_ASSERT_TRUE( 1 == 1);
      // }

      CONTENTS

      input = StringIO.new( file_contents )

      @extractor.collect_simple_context( filepath, input, :test_runner_details )

      expected = [
        {:line_number =>  2, :test => 'test_this_function'},
        {:line_number => 12, :test => 'test_another_function'},
      ]

      expect( @extractor.lookup_test_cases( filepath ) ).to eq expected
    end

  end

end
