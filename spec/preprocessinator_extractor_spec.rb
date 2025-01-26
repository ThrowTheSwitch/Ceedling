# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/preprocessinator_extractor'
require 'ceedling/parsing_parcels'

describe PreprocessinatorExtractor do
  before(:each) do
    @parsing_parcels = ParsingParcels.new()
    @extractor = described_class.new(
      {
        :parsing_parcels => @parsing_parcels
      }
    )
  end

  context "#extract_file_as_array_from_expansion" do
    it "should simply extract text of original file from preprocessed expansion" do
      filepath = "path/do/WANT.c"
      
      file_contents = [
        '# 1 "some/file/we/do/not/care/about.c" 5',
        'some_text_we_do_not_want();',
        '# 11 "path/do/WANT.c" 99999',               # Beginning of block to extract
        'some_text_we_do_want();',                   #  Line to extract
        '',                                          #  Blank line to extract
        'some_awesome_text_we_want_so_hard();',      #  Line to extract
        'holy_crepes_more_awesome_text();',          #  Line to extract
        '# 3 "some/other/file/we/ignore.c" 5',       # End of block to extract
      ]

      expected = [
        'some_text_we_do_want();',
        '',
        'some_awesome_text_we_want_so_hard();',
        'holy_crepes_more_awesome_text();'
      ]

      input = StringIO.new( file_contents.join( "\n" ) )

      expect( @extractor.extract_file_as_array_from_expansion( input, filepath ) ).to eq expected
    end

    it "should extract text of original file from preprocessed expansion preserving #directives and cleaning up whitespace)" do
      filepath = "this/path/MY_FILE.C"
      
      file_contents = [
        '# 1 "./this/path/MY_FILE.C" 99999',         # Beginning of block to extract
        '       ',                                   #  Whitespace collapse & preserve as blank line
        '#pragma yo sup',                            #  Line to extract -- #pragma is not end-of-block preprocessor line marker
        '#define FOO(...)',                          #  Line to extract -- #define is not end-of-block preprocessor line marker
        'void some_function(void) {',                #  Line to extract
        '  do_something();   ',                      #  Line to extract with leading whitespace that should remain
        '  }',                                       #  Line to extract with leading whitespace that should remain
        "\t",                                        #  Whitespace collapse & preserve as blank line
        '# 1 "some/useless/file.c"'                  # End of block to extract
      ]

      expected = [
        '',
        '#pragma yo sup',
        '#define FOO(...)',
        'void some_function(void) {',
        '  do_something();',         
        '  }',                         
        ''
      ]

      input = StringIO.new( file_contents.join( "\n" ) )

      expect( @extractor.extract_file_as_array_from_expansion( input, filepath ) ).to eq expected
    end

    it "should extract text of original file from preprocessed expansion with complex preprocessor line marker sequence" do
      filepath = "dir/our_file.c"
      
      file_contents = [
        '# 1 "dir/our_file.c" 123',                  # Beginning of file / block to extract
        'some_text_we_do_want();',                   #  Line to extract
        'some_awesome_text_we_want_so_hard();',      #  Line to extract
        '# 3 "some preprocessor directive"',         # End of block to extract (a directive that is a faux preprocessor line marker)
        '',
        'some_text_we_do_not_want();',
        '# 15 "dir/our_file.c" 9',                   # Beginning of block to extract
        'more_text_we_want();',                      #  Line to extract
        'void some_function(void) { func(); }',      #  Line to extract
        '# 9 "dir/our_file.c" 77',                   # Continuation of block to extract
        'some code',                                 #  Line to extract
        'test statements',                           #  Line to extract
        '# 6 "dir/our_file.c" 19',                   # Continuation of block to extract
        'some_additional_awesomely_wanted_text();'   #  Line to extract
      ]                                              # End of file / end of block to extract

      expected = [
        'some_text_we_do_want();',
        'some_awesome_text_we_want_so_hard();',
        'more_text_we_want();',
        'void some_function(void) { func(); }',
        'some code',      
        'test statements',
        'some_additional_awesomely_wanted_text();'
      ]

      input = StringIO.new( file_contents.join( "\n" ) )

      expect( @extractor.extract_file_as_array_from_expansion(input, filepath) ).to eq expected
    end
  
    it "should extract text of original file from preprocessed expansion ignoring embedded expansions having similar names" do
      filepath = "dir1/dir2/our_file.c"
      
      file_contents = [
        '# 1 "dir1/dir2/our_file.c" 123',            # Beginning of file / block to extract
        'some_text_we_do_want();',                   #  Line to extract
        'some_awesome_text_we_want_so_hard();',      #  Line to extract
        '# 987 "some preprocessor directive"',       # End of block to extract (a directive that is a faux preprocessor line marker)
        '',
        'some_text_we_do_not_want();',
        '# 15 "dir1/dir2/not_our_file.c" 9',         # Beginning of block we should ignore despite similar filename
        'more_text_we_want();',                      #  Line to ignore
        'void some_function(void) { func(); }',      #  Line to ignore
        '# 9 "dir1/dir2/not_our_file.c" 77',         # Continuation of block to ignore
        'some code',                                 #  Line to ignore
        'test statements',                           #  Line to ignore
        '# 6 "dir1/dir2/not_our_file.c" 19',         # Continuation of block to ignore
        'some_additional_unwanted_text();',          #  Line to ignore
        '',
        'some_more_text_we_do_not_want();',
        '# 11 "dir11/dir2/our_file.c" 9',            # Beginning of block we should ignore despite similar filepath
        'more_text_we_want();',                      #  Line to ignore
        'void some_function(void) { func(); }',      #  Line to ignore
        '# 9 "dir11/dir2/our_file.c" 2 3',           # Continuation of block to ignore
        'some code',                                 #  Line to ignore
        'test statements',                           #  Line to ignore
        '# 6 "dir11/dir2/our_file.c" 1',             # Continuation of block to ignore
        'some_further_unwanted_text();',             #  Line to ignore
        '',
        'even_more_text_we_do_not_want();',
        '# 11 "dir2/our_file.c" 9',                  # Beginning of block we should ignore despite similar sub-filepath
        'more_text_we_want();',                      #  Line to ignore
        'void some_function(void) { func(); }',      #  Line to ignore
        '# 9 "dir2/our_file.c" 2 3',                 # Continuation of block to ignore
        'some code',                                 #  Line to ignore
        'test statements',                           #  Line to ignore
        '# 6 "dir2/our_file.c" 1',                   # Continuation of block to ignore
        'some_further_unwanted_text();'              #  Line to ignore
      ]                                              # End of file / end of block to extract

      expected = [
        'some_text_we_do_want();',
        'some_awesome_text_we_want_so_hard();',
      ]

      input = StringIO.new( file_contents.join( "\n" ) )

      expect( @extractor.extract_file_as_array_from_expansion(input, filepath) ).to eq expected
    end
  end

  context "#extract_file_as_string_from_expansion" do
    it "should simply extract text of original file from preprocessed expansion" do
      filepath = "path/do/WANT.c"
      
      file_contents = [
        '# 1 "some/file/we/do/not/care/about.c" 5',
        'some_text_we_do_not_want();',
        '# 11 "./path/do/WANT.c" 99999',             # Beginning of block to extract
        'some_text_we_do_want();',                   #  Line to extract
        '',                                          #  Blank line to extract
        'some_awesome_text_we_want_so_hard();',      #  Line to extract
        'holy_crepes_more_awesome_text();',          #  Line to extract
        '# 3 "some/other/file/we/ignore.c" 5',       # End of block to extract
      ]

      expected = [
        'some_text_we_do_want();',
        '',
        'some_awesome_text_we_want_so_hard();',
        'holy_crepes_more_awesome_text();'
      ].join( "\n" )

      input = StringIO.new( file_contents.join( "\n" ) )

      expect( @extractor.extract_file_as_string_from_expansion( input, filepath ) ).to eq expected
    end
  end

  context "#extract_test_directive_macro_calls" do
    it "should extract any and all test directive macro calls from test file text" do
      file_text = <<~FILE_TEXT
        TEST_SOURCE_FILE("foo/bar/file.c")TEST_SOURCE_FILE("yo/data.c")

            TEST_INCLUDE_PATH("some/inc/dir")
        SOME_MACRO(TEST_INCLUDE_PATH("another/dir")) TEST_INCLUDE_PATH("hello/there")
      FILE_TEXT

      expected = [
        'TEST_SOURCE_FILE("foo/bar/file.c")',
        'TEST_SOURCE_FILE("yo/data.c")',
        'TEST_INCLUDE_PATH("some/inc/dir")',
        'TEST_INCLUDE_PATH("another/dir")',
        'TEST_INCLUDE_PATH("hello/there")'
      ]

      expect( @extractor.extract_test_directive_macro_calls( file_text ) ).to eq expected
    end
  end

  context "#extract_test_directive_macro_calls" do
    it "should extract only uncommented calls" do
      file_text = <<~FILE_TEXT
        TEST_SOURCE_FILE("foo/bar/file.c")//TEST_SOURCE_FILE("yo/data.c")

            TEST_INCLUDE_PATH("some/inc/dir")
        SOME_MACRO(TEST_INCLUDE_PATH("another/dir")) TEST_INCLUDE_PATH("hello/there")
      FILE_TEXT

      expected = [
        'TEST_SOURCE_FILE("foo/bar/file.c")',
        'TEST_INCLUDE_PATH("some/inc/dir")',
        'TEST_INCLUDE_PATH("another/dir")',
        'TEST_INCLUDE_PATH("hello/there")'
      ]

      expect( @extractor.extract_test_directive_macro_calls( file_text ) ).to eq expected
    end
  end

  context "#extract_pragmas" do
    it "should extract any and all pragmas from file text" do
      file_text = <<~FILE_TEXT
        SOME_MACRO("yo")

          #define  PI  3.14159

        #pragma pack(1)    

        extern void func_sig(int, byte);
        #define SQUARE(x) ((x) * (x))

          #pragma TOOL command \\ 
                  with_some_args  \\
                  that wrap

        #define MAX(a, b) ((a) > (b) ? (a) : (b))

        #pragma warning(disable : 4996)  
        #pragma GCC optimize("O3")

        SOME_OTHER_MACRO("more")
      FILE_TEXT

      expected = [
        "#pragma pack(1)",
        [
          "#pragma TOOL command ",
          "          with_some_args  ",
          "          that wrap"
        ].join,
        "#pragma warning(disable : 4996)",
        "#pragma GCC optimize(\"O3\")"
      ]

      expect( @extractor.extract_pragmas( file_text ) ).to eq expected
    end
  end

  context "#extract_include_guard" do
    it "should extract a simple include guard from among file text" do
      file_text = <<~FILE_TEXT
        #ifndef _HEADER_INCLUDE_GUARD_
        #define  _HEADER_INCLUDE_GUARD_

        ...

        #endif // _HEADER_INCLUDE_GUARD_
      FILE_TEXT

      expect( @extractor.extract_include_guard( file_text ) ).to eq '_HEADER_INCLUDE_GUARD_'
    end

    it "should extract the first text that looks like an include guard from among file text" do
      file_text = <<~FILE_TEXT

        #ifndef HEADER_INCLUDE_GUARD

         #define  HEADER_INCLUDE_GUARD

        #ifndef DUMMY_INCLUDE_GUARD
        #define DUMMY_INCLUDE_GUARD

        #endif // HEADER_INCLUDE_GUARD
      FILE_TEXT

      expect( @extractor.extract_include_guard( file_text ) ).to eq 'HEADER_INCLUDE_GUARD'
    end

    it "should not extract an include guard from among file text" do
      file_text = <<~FILE_TEXT
        #ifndef SOME_GUARD_NAME
        #define  OME_GUARD_NAME

        #define SOME_GUARD_NAME

        #endif // SOME_GUARD_NAME
      FILE_TEXT

      expect( @extractor.extract_include_guard( file_text ) ).to eq nil
    end
  end

  context "#extract_macro_defs" do
    it "should extract any and all macro defintions from file text" do

      # Note aspects of this heredoc text block under test:
      #  - Macros beginning indented
      #  - Repeated whitespace characters
      #  - Single line and multiline macro definitions
      #  - Whitespace after continuation slashes (eliminated in extraction)
      #  - No empty lines between macro definitions

      file_text = <<~FILE_TEXT
        SOME_MACRO("yo")

          #define  PI  3.14159

        #pragma GCC something

        extern void func_sig(int, byte);
        #define SQUARE(x) ((x) * (x))  

        #define MAX(a, b) ((a) > (b) ? (a) : (b))

        extern void function(void);

        #define MACRO(num, str) {\\  
                    printf("%d", num);\\
                    printf(" is");            \\ 
                    printf(" %s number", str);\\ 
                    printf("\\n");\\ 
                   }  

        #define LONG_STRING "This is a very long string that \\
                              continues on the next line"
        #define MULTILINE_MACRO do { \\ 
              something(); \\
              something_else(); \\ 
            } while(0)

        SOME_OTHER_MACRO("more")
      FILE_TEXT

      expected = [
        "#define  PI  3.14159",
        "#define SQUARE(x) ((x) * (x))",
        "#define MAX(a, b) ((a) > (b) ? (a) : (b))",
        [
          "#define MACRO(num, str) {",
          "            printf(\"%d\", num);",
          "            printf(\" is\");            ",
          "            printf(\" %s number\", str);",
          "            printf(\"\\n\");",
          "           }"
        ].join,
        [
          "#define LONG_STRING \"This is a very long string that ",
          "                      continues on the next line\""
        ].join,
        [
          "#define MULTILINE_MACRO do { ",
          "      something(); ",
          "      something_else(); ",
          "    } while(0)"
        ].join
      ]

      expect( @extractor.extract_macro_defs( file_text, nil ) ).to eq expected
    end

    it "should ignore include guard among macro defintions in file text" do
      file_text = <<~FILE_TEXT
        #ifndef _INCLUDE_GUARD_
        #define _INCLUDE_GUARD_

        #define PI 3.14159

        #define LONG_STRING "This is a very long string that \\
                              continues on the next line"

        SOME_OTHER_MACRO("more")
      FILE_TEXT

      expected = [
        "#define PI 3.14159",
        "#define LONG_STRING \"This is a very long string that                       continues on the next line\""
      ]

      expect( @extractor.extract_macro_defs( file_text, '_INCLUDE_GUARD_' ) ).to eq expected
    end

  end

end
