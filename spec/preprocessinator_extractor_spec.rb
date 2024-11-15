# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/preprocessinator_extractor'

describe PreprocessinatorExtractor do
  context "#extract_file_from_full_expansion" do
    it "should extract text of the original file from preprocessed expansion (and preserve #pragma statements)" do
      filepath = "path/to/WANT.c"
      
      file_contents = [
        '# 1 "some/file/we/do/not/care/about.c" 5',
        '',
        '#pragma shit',
        'some_text_we_do_not_want();',
        '',
        '# 1 "some/file/we/DO/WANT.c" 99999',        # Beginning of block to extract
        'some_text_we_do_want();',                   #  Line to extract
        '#pragma want',                              #  Line to extract (do not recognize #pragma as preprocessor directive)
        'some_awesome_text_we_want_so_hard();',      #  Line to extract
        '',                                          #  Blank line
        'holy_crepes_more_awesome_text();',          #  Line to extract
        '  ',                                        #  Blank line
        '# oh darn',                                 # End of block to extract (faux preprocessor directive)
        '',
        '# 1 "some/useless/file.c" 9',
        'a set of junk',
        'more junk',
        '',
        '# 1 "holy/shoot/yes/WANT.c" 10',            # Beginning of block to extract
        'some_additional_awesomely_wanted_text();',  #  Line to extract
      ]                                              # End of block to extract

      expected = [
        'some_text_we_do_want();',
        '#pragma want',
        'some_awesome_text_we_want_so_hard();',
        '',
        'holy_crepes_more_awesome_text();',
        '',
        'some_additional_awesomely_wanted_text();',
      ]

      input = StringIO.new( file_contents.join( "\n" ) )

      expect( subject.extract_file_from_full_expansion(input, filepath) ).to eq expected
    end

  end

  context "#extract_file_from_directives_only_expansion" do
    it "should extract last chunk of text after last '#' line containing file name of our filepath" do
      filepath = "path/to/WANT.c"

      file_contents = [
        '# 1 "some/file/we/do/not/care/about.c" 5',
        '#pragma trash',
        'some_text_we_do_not_want();',
        '# 1 "some/file/we/DO/WANT.c" 99999',
        'some_text_we_do_not_want();',
        '#pragma want',
        'some_creepy_text_we_not_want();',
        '# 1 "some/useless/file.c" 9',
        'a set of junk',
        'more junk',
        '# 1 "holy/shoot/yes/WANT.c" 10',            # Beginning of block to extract
        '#pragma want',
        '',
        '#define INCREDIBLE_DEFINE 911',
        '  ',
        'some_additional_awesome_want_text();',
        '  ',
        'holy_crepes_more_awesome_text();'
      ]

      # Note spaces in empty lines of heredoc
      expected = <<~EXTRACTED
        #pragma want
        
        #define INCREDIBLE_DEFINE 911
          
        some_additional_awesome_want_text();
          
        holy_crepes_more_awesome_text();
      EXTRACTED

      expected.strip!()

      input = StringIO.new( file_contents.join( "\n" ) )

      expect( subject.extract_file_from_directives_only_expansion( input, filepath) ).to eq expected
    end
  end
end
