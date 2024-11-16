# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/preprocessinator_extractor'

describe PreprocessinatorExtractor do
  context "#extract_file_as_array_from_expansion" do
    it "should simply extract text of original file from preprocessed expansion" do
      filepath = "path/to/WANT.c"
      
      file_contents = [
        '# 1 "some/file/we/do/not/care/about.c" 5',
        'some_text_we_do_not_want();',
        '# 11 "some/file/we/DO/WANT.c" 99999',       # Beginning of block to extract
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

      expect( subject.extract_file_as_array_from_expansion( input, filepath ) ).to eq expected
    end

    it "should extract text of original file from preprocessed expansion preserving #directives and cleaning up whitespace)" do
      filepath = "this/path/MY_FILE.C"
      
      file_contents = [
        '# 1 "MY_FILE.C" 99999',                     # Beginning of block to extract
        '       ',                                   #  Whitespace to clean up & preserve
        '#pragma yo sup',                            #  Line to extract -- #pragma is not end-of-block preprocessor directive
        '#define FOO(...)',                          #  Line to extract -- #define is not end-of-block preprocessor directive
        'void some_function(void) {',                #  Line to extract
        '  do_something();',                         #  Line to extract with leading whitespace that should remain
        '}',                                         #  Line to extract
        "\t",                                        #  Whitespace to clean up & preserve
        '# 1 "some/useless/file.c"'                  # End of block to extract
      ]

      expected = [
        '',
        '#pragma yo sup',
        '#define FOO(...)',
        'void some_function(void) {',
        '  do_something();',         
        '}',                         
        ''
      ]

      input = StringIO.new( file_contents.join( "\n" ) )

      expect( subject.extract_file_as_array_from_expansion( input, filepath ) ).to eq expected
    end

    it "should extract text of original file from preprocessed expansion with complex preprocessor directive sequence" do
      filepath = "dir/our_file.c"
      
      file_contents = [
        '# 1 "dir/our_file.c" 123',                  # Beginning of file / block to extract
        'some_text_we_do_want();',                   #  Line to extract
        'some_awesome_text_we_want_so_hard();',      #  Line to extract
        '# 987 "some preprocessor directive"',       # End of block to extract (faux preprocessor directive)
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

      expect( subject.extract_file_as_array_from_expansion(input, filepath) ).to eq expected
    end
  end

  context "#extract_file_as_string_from_expansion" do
    it "should simply extract text of original file from preprocessed expansion" do
      filepath = "path/to/WANT.c"
      
      file_contents = [
        '# 1 "some/file/we/do/not/care/about.c" 5',
        'some_text_we_do_not_want();',
        '# 11 "some/file/we/DO/WANT.c" 99999',       # Beginning of block to extract
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

      expect( subject.extract_file_as_string_from_expansion( input, filepath ) ).to eq expected
    end
  end

  context "#extract_test_directive_macros" do
    it "should extract any and all test directive macros from test file text" do
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

      expect( subject.extract_test_directive_macros( file_text ) ).to eq expected
    end
  end

  context "#extract_macros_defs_and_pragmas" do
    it "should extract any and all macro defintions and pragmas from header file text" do
      file_text = <<~FILE_TEXT
        SOME_MACRO("yo")

          #define PI 3.14159

        #pragma pack(1)

        extern void func_sig(int, byte);
        #define SQUARE(x) ((x) * (x))

        #define MAX(a, b) ((a) > (b) ? (a) : (b))

        #pragma warning(disable : 4996)
        #pragma GCC optimize("O3")

        #define MACRO(num, str) {\ 
                    printf("%d", num);\ 
                    printf(" is");\ 
                    printf(" %s number", str);\ 
                    printf("\n");\ 
                   }  

        SOME_OTHER_MACRO("more")
      FILE_TEXT

      expected = [
        '#define PI 3.14159',
        '#define SQUARE(x) ((x) * (x))',
        '#define MAX(a, b) ((a) > (b) ? (a) : (b))',
        '#pragma warning(disable : 4996)',
        '#pragma GCC optimize("O3")',
      ]

      expect( subject.extract_macros_defs_and_pragmas( file_text ) ).to eq expected
    end
  end






end
