# derived from test_graveyard/unit/preprocessinator_extractor_test.rb

require 'spec_helper'

describe PreprocessinatorExtractor do
  describe "#extract_base_file_from_preprocessed_expansion" do
    xit "should keep #pragma statements"
    xit "should strip other preprocessor directives"

    it "should only extract text from the original file" do
      input_str = <<-EOS
        # 1 "some/file/we/do/not/care/about.c" 5
        some_text_we_do_not_want();
        # 1 "some/file/we/DO/WANT.c" 99999
        some_awesome_text_we_want_so_hard();
        holy_crepes_more_awesome_text();
      EOS
      input_str = input_str.left_margin

      expect_str = <<-EOS
        some_awesome_text_we_want_so_hard();
        holy_crepes_more_awesome_text();
      EOS
      expect_str = expect_str.left_margin

      subject.extract_base_file_from_preprocessed_expansion(input_str).should == expect_str
    end

    # These were originally hinted at by the old test, but we don't see anything
    # in the implementation that does this. They are here as reminders in the future.
    # # xit "should ignore formatting"
    # # xit "should ignore whitespace"
  end
end
