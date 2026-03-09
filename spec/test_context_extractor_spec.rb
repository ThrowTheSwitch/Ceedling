# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/test_context_extractor'
require 'ceedling/includes/includes'
require 'ceedling/includes/include_factory'
require 'ceedling/parsing_parcels'
require 'ceedling/exceptions'


describe TestContextExtractor do
  before(:each) do

    ## Mock injected dependencies

    # Use double() so we can mock needed methods that are added dynamically at startup
    @configurator = double( "Configurator" )
    # Not actually exercised in these test cases
    @file_wrapper = double( "FileWrapper" )
    
    # Ignore all logging calls
    loginator = instance_double( "Loginator" )
    allow(loginator).to receive(:log)
    allow(loginator).to receive(:log_list)

    ## Concrete injected dependencies
    @parsing_parcels = ParsingParcels.new()
    @include_factory = IncludeFactory.new( {:configurator => @configurator} )
    @file_path_utils = FilePathUtils.new( {:configurator => @configurator, :file_wrapper => @file_wrapper } ) 

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
    allow(@configurator).to receive(:cmock_mock_path).and_return( 'build/mocks' )
    allow(@configurator).to receive(:extension_header).and_return( '.h' )
    allow(@configurator).to receive(:extension_source).and_return( '.c' )
    allow(@configurator).to receive(:get_runner_config).and_return( test_runner_config )

    @extractor = described_class.new(
      {
        :configurator => @configurator,
        :parsing_parcels => @parsing_parcels,
        :include_factory => @include_factory,
        :file_path_utils => @file_path_utils,
        :file_wrapper => @file_wrapper,
        :loginator => loginator
      }
    )
  end

  context "#lookup_all_header_includes_list" do
    it "should provide empty list when no context extraction has occurred" do
      expect( @extractor.lookup_all_header_includes_list( "path" ) ).to eq []
    end
  end

  context "#lookup_all_header_includes_list" do
    it "should provide empty list when no context extraction has occurred" do
      expect( @extractor.lookup_all_header_includes_list( "path" ) ).to eq []
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

  context "#lookup_mock_header_includes_list" do
    it "should provide empty list when no context extraction has occurred" do
      expect( @extractor.lookup_mock_header_includes_list( "path" ) ).to eq []
    end
  end

  context "#collect_simple_context" do
    it "should raise an execption for unknown symbol argument" do
      expect{ @extractor.collect_simple_context( "path", StringIO.new(), :bad ) }.to raise_error( CeedlingException )
    end

    # collect_simple_context() + lookup_all_header_includes_list() + lookup_mock_header_includes_list()
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

      @extractor.collect_simple_context( filepath, input, TestContextExtractor::Context::INCLUDES )

      result = @extractor.lookup_all_header_includes_list( filepath )
      expect( result.length ).to eq 3
      expect( result[0] ).to be_an_instance_of(UserInclude)
      expect( result[1] ).to be_an_instance_of(UserInclude)
      expect( result[2] ).to be_an_instance_of(UserInclude)

      result = @extractor.lookup_mock_header_includes_list( filepath )
      expect( result.length ).to eq 2
      expect( result[0] ).to be_an_instance_of(MockInclude)
      expect( result[1] ).to be_an_instance_of(MockInclude)
    end

    # collect_simple_context() + lookup_all_header_includes_list() + lookup_mock_header_includes_list()
    it "should extract contents of partials configurations as #include directives" do
      filepath = "path/tests/test_file_with_partials.c"
      
      # Complex comments tested in `clean_code_line()` test case
      file_contents = <<~CONTENTS
      #include "some_source.h"
      // Partial confgurations
      #include TEST_PARTIAL_PUBLIC_MODULE(foo)
      #include TEST_PARTIAL_PRIVATE_MODULE(bar)
      #include MOCK_PARTIAL_PRIVATE_MODULE(noo)
      #include MOCK_PARTIAL_PUBLIC_MODULE(doo)

      CONTENTS

      input = StringIO.new( file_contents )

      @extractor.collect_simple_context( filepath, input, TestContextExtractor::Context::PARTIALS_CONFIGURATION )

      expected_full = [
        UserInclude.new('ceedling_partial_foo_impl.h'),
        UserInclude.new('ceedling_partial_bar_impl.h'),
        MockInclude.new('mock_ceedling_partial_noo_interface.h'),
        MockInclude.new('mock_ceedling_partial_doo_interface.h')
      ]

      expected_mocks = [
        MockInclude.new('mock_ceedling_partial_noo_interface.h'),
        MockInclude.new('mock_ceedling_partial_doo_interface.h')
      ]

      result = @extractor.lookup_all_header_includes_list( filepath )
      expect( result ).to match_array( expected_full )

      result = @extractor.lookup_mock_header_includes_list( filepath )
      expect( result ).to match_array( expected_mocks )
    end

    # collect_simple_context() + lookup_partials_config()
    it "should extract contents of partials configurations" do
      filepath = "path/tests/test_file_with_partials.c"
      
      # Complex comments tested in `clean_code_line()` test case
      file_contents = <<~CONTENTS
      // Partial confgurations
      #include TEST_PARTIAL_PUBLIC_MODULE(foo)
      #include TEST_PARTIAL_PUBLIC_MODULE(foobar)
      #include TEST_PARTIAL_PRIVATE_MODULE(baz)
      #include TEST_PARTIAL_PRIVATE_MODULE(razmataz)
      #include MOCK_PARTIAL_PRIVATE_MODULE(foobar)
      #include MOCK_PARTIAL_PRIVATE_MODULE(hardyharhar)
      #include MOCK_PARTIAL_PUBLIC_MODULE(abc)
      #include MOCK_PARTIAL_PUBLIC_MODULE(abc_xyz)

      CONTENTS

      input = StringIO.new( file_contents )

      @extractor.collect_simple_context( filepath, input, TestContextExtractor::Context::PARTIALS_CONFIGURATION )

      expected = [
        {Partials::TEST_PUBLIC => 'foo'},
        {Partials::TEST_PUBLIC => 'foobar'},
        {Partials::TEST_PRIVATE => 'baz'},
        {Partials::TEST_PRIVATE => 'razmataz'},
        {Partials::MOCK_PRIVATE => 'foobar'},
        {Partials::MOCK_PRIVATE => 'hardyharhar'},
        {Partials::MOCK_PUBLIC => 'abc'},
        {Partials::MOCK_PUBLIC => 'abc_xyz'},
      ]

      expect( @extractor.lookup_partials_config( filepath ) ).to eq expected
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

      @extractor.collect_simple_context( filepath, input, TestContextExtractor::Context::BUILD_DIRECTIVE_SOURCE_FILES )

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

      @extractor.collect_simple_context( filepath, input, TestContextExtractor::Context::BUILD_DIRECTIVE_INCLUDE_PATHS )

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

      @extractor.collect_simple_context( filepath, input, TestContextExtractor::Context::BUILD_DIRECTIVE_INCLUDE_PATHS )

      # Second File
      filepath = "anotherfile.c"
      
      # Complex comments tested in `clean_code_line()` test case
      file_contents = <<~CONTENTS
      TEST_INCLUDE_PATH("more/paths")
      TEST_INCLUDE_PATH("yet/more/paths")
      TEST_INCLUDE_PATH("this/path")       // Duplicated from first file
      CONTENTS

      input = StringIO.new( file_contents )

      @extractor.collect_simple_context( filepath, input, TestContextExtractor::Context::BUILD_DIRECTIVE_INCLUDE_PATHS )

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

      @extractor.collect_simple_context( filepath, input, TestContextExtractor::Context::TEST_RUNNER_DETAILS )

      expected = [
        {:line_number =>  2, :test => 'test_this_function'},
        {:line_number => 12, :test => 'test_another_function'},
      ]

      expect( @extractor.lookup_test_cases( filepath ) ).to eq expected
    end

  end

end
