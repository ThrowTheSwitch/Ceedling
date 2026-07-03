# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/parsing_parcels'

describe ParsingParcels do
  before(:each) do

    @parsing_parcels = described_class.new()
  end

  context "#code_lines" do
    it "should clean code of encoding problems and comments" do
      file_contents = <<~CONTENTS
      /* TEST_SOURCE_FILE("foo.c") */    // Eliminate single line comment block
      // TEST_SOURCE_FILE("bar.c")       // Eliminate single line comment
      Some text⛔️
      /* // /*                           // Eliminate tricky comment block enclosing comments
        TEST_SOURCE_FILE("boom.c")
        */   //                          // Eliminate trailing single line comment following block comment
      More text
      #define STR1 "/* comment  "        // Strip out (single line) C string containing block comment
      #define STR2 "  /* comment  "      // Strip out (single line) C string containing block comment
      CONTENTS

      got = []

      @parsing_parcels.code_lines( StringIO.new( file_contents ) ) do |line|
        line.strip!
        got << line if !line.empty?
      end

      expected = [
        'Some text', # ⛔️ removed with encoding sanitizing
        'More text',
        "#define STR1",
        "#define STR2"
      ]

      expect( got ).to eq expected
    end

    it "removes a single inline block comment, preserving surrounding code" do
      file_contents = "int x = /* init */ 0;\n"
      got = []

      @parsing_parcels.code_lines( StringIO.new( file_contents ) ) do |line|
        line.strip!
        got << line if !line.empty?
      end

      expect( got ).to eq( ['int x =  0;'] )
    end

    it "removes adjacent inline block comments independently, preserving the code between them" do
      # Greedy /\/\*.*\*\// collapses both comments plus the code between them.
      # Non-greedy /\/\*.*?\*\// removes each comment individually, preserving the expression.
      file_contents = "int x = /* foo */ 1 + /* bar */ 2;\n"
      got = []

      @parsing_parcels.code_lines( StringIO.new( file_contents ) ) do |line|
        line.strip!
        got << line if !line.empty?
      end

      # Greedy (current bug): 'int x =  2;'  — the '1 + ' between the two comments is eaten
      expect( got ).to eq( ['int x =  1 +  2;'] )
    end

    it "strips only the string that contains a block comment opener, leaving other strings intact" do
      # Greedy /"\s*\/\*.*"/ extends from the opening-comment string all the way to the
      # last double-quote on the line, removing the variable declaration between them.
      # The corrected pattern uses [^"] to stay within string boundaries.
      file_contents = "char *a = \"/* \", *b = \"end_\";\n"
      got = []

      @parsing_parcels.code_lines( StringIO.new( file_contents ) ) do |line|
        line.strip!
        got << line if !line.empty?
      end

      # Greedy (current bug): 'char *a = ;'  — '*b = "end_"' is swallowed by the greedy match
      expect( got ).to eq( ['char *a = , *b = "end_";'] )
    end

    it "should treat continuations as a single line" do
      file_contents = "// TEST_SOURCE_FILE(\"foo.c\") \\  \nTEST_SOURCE_FILE(\"bar.c\")\nSome text⛔️ \\\nMore text\n"
      got = []

      @parsing_parcels.code_lines( StringIO.new( file_contents ) ) do |line|
        line.strip!
        got << line if !line.empty?
      end

      expected = [
        'Some text More text'
      ]

      expect( got ).to eq expected
    end
  end

  context "#code_lines_with_num" do
    it "should clean code of encoding problems and comments" do
      file_contents = <<~CONTENTS
      /* TEST_SOURCE_FILE("foo.c") */    // Eliminate single line comment block
      // TEST_SOURCE_FILE("bar.c")       // Eliminate single line comment
      Some text⛔️
      /* // /*                           // Eliminate tricky comment block enclosing comments
        TEST_SOURCE_FILE("boom.c")
        */   //                          // Eliminate trailing single line comment following block comment
      More text
      #define STR1 "/* comment  "        // Strip out (single line) C string containing block comment
      #define STR2 "  /* comment  "      // Strip out (single line) C string containing block comment
      CONTENTS

      got = []

      @parsing_parcels.code_lines_with_num( StringIO.new( file_contents ) ) do |line, num|
        line.strip!
        got << {:text => line, :num => num} if !line.empty?
      end

      expected = [
        {:text => 'Some text', :num => 3}, # ⛔️ removed with encoding sanitizing
        {:text => 'More text', :num => 7},
        {:text => "#define STR1", :num => 8},
        {:text => "#define STR2", :num => 9}
      ]

      expect( got ).to eq expected
    end
  end
end
