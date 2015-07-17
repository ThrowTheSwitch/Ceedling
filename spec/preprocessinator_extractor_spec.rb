# derived from test_graveyard/unit/preprocessinator_extractor_test.rb

require 'spec_helper'
require 'ceedling/preprocessinator_extractor'

describe PreprocessinatorExtractor do
  context "#extract_base_file_from_preprocessed_expansion" do
    it "should extract text from the original file and keep #pragma statements" do
      file_path = "path/to/WANT.c"
      input_str = [
        '# 1 "some/file/we/do/not/care/about.c" 5',
        '#pragma shit',
        'some_text_we_do_not_want();',
        '# 1 "some/file/we/DO/WANT.c" 99999',
        'some_text_we_do_not_want();',
        '#pragma want',
        'some_awesome_text_we_want_so_hard();',
        'holy_crepes_more_awesome_text();',
        '# oh darn',
        '# 1 "some/useless/file.c" 9',
        'a set of junk',
        'more junk',
        '# 1 "holy/shoot/yes/WANT.c" 10',
        'some_additional_awesome_want_text();',
      ]

      expect_str = [
        'some_text_we_do_not_want();',
        '#pragma want',
        'some_awesome_text_we_want_so_hard();',
        'holy_crepes_more_awesome_text();',
        'some_additional_awesome_want_text();',
      ]

      expect(File).to receive(:readlines).with(file_path).and_return( input_str )

      expect(subject.extract_base_file_from_preprocessed_expansion(file_path)).to eq expect_str
    end

    # These were originally hinted at by the old test, but we don't see anything
    # in the implementation that does this. They are here as reminders in the future.
    # # xit "should ignore formatting"
    # # xit "should ignore whitespace"
  end
end
