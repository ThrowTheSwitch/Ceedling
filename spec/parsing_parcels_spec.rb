# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
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

end
