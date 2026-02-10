# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/c_extractor'
require 'stringio'

describe CExtractor do

  ###
  ### skip_c_string()
  ###
  describe "#skip_c_string (private method testing)" do
    # Helper to access private method
    let(:skip_c_string) do
      ->(content, quote) do
        extractor_obj = CExtractor.from_string(content: "", chunk_size: 10)
        scanner = StringScanner.new(content)
        bytes_skipped = extractor_obj.send(:skip_c_string, scanner, quote)
        return [bytes_skipped, scanner.pos, scanner.rest]
      end
    end

    context "double-quoted string handling" do
      it "skips simple double-quoted string" do
        content = '"hello"code'
        bytes_skipped, pos, rest = skip_c_string.call(content, '"')
        
        expect(bytes_skipped).to eq(7)
        expect(pos).to eq(7)
        expect(rest).to eq("code")
      end

      it "skips empty double-quoted string" do
        content = '""code'
        bytes_skipped, pos, rest = skip_c_string.call(content, '"')
        
        expect(bytes_skipped).to eq(2)
        expect(pos).to eq(2)
        expect(rest).to eq("code")
      end

      it "skips string with spaces" do
        content = '"hello   world"code'
        bytes_skipped, pos, rest = skip_c_string.call(content, '"')
        
        expect(bytes_skipped).to eq(15)
        expect(pos).to eq(15)
        expect(rest).to eq("code")
      end

      it "skips string with special characters" do
        content = '"hello!@#$%^&*()"code'
        bytes_skipped, pos, rest = skip_c_string.call(content, '"')
        
        expect(bytes_skipped).to eq(17)
        expect(pos).to eq(17)
        expect(rest).to eq("code")
      end

      it "skips string with newlines" do
        content = "\"hello\nworld\"code"
        bytes_skipped, pos, rest = skip_c_string.call(content, '"')
        
        expect(bytes_skipped).to eq(13)
        expect(pos).to eq(13)
        expect(rest).to eq("code")
      end

      it "skips string with tabs" do
        content = "\"hello\tworld\"code"
        bytes_skipped, pos, rest = skip_c_string.call(content, '"')
        
        expect(bytes_skipped).to eq(13)
        expect(pos).to eq(13)
        expect(rest).to eq("code")
      end
    end

    context "single-quoted character handling" do
      it "skips simple single-quoted character" do
        content = "'a'code"
        bytes_skipped, pos, rest = skip_c_string.call(content, "'")
        
        expect(bytes_skipped).to eq(3)
        expect(pos).to eq(3)
        expect(rest).to eq("code")
      end

      it "skips single-quoted digit" do
        content = "'5'code"
        bytes_skipped, pos, rest = skip_c_string.call(content, "'")
        
        expect(bytes_skipped).to eq(3)
        expect(pos).to eq(3)
        expect(rest).to eq("code")
      end

      it "skips single-quoted special character" do
        content = "'@'code"
        bytes_skipped, pos, rest = skip_c_string.call(content, "'")
        
        expect(bytes_skipped).to eq(3)
        expect(pos).to eq(3)
        expect(rest).to eq("code")
      end

      it "skips single-quoted space" do
        content = "' 'code"
        bytes_skipped, pos, rest = skip_c_string.call(content, "'")
        
        expect(bytes_skipped).to eq(3)
        expect(pos).to eq(3)
        expect(rest).to eq("code")
      end
    end

    context "escape sequence handling" do
      it "skips string with escaped double quote" do
        content = '"hello \\"world\\""code'
        bytes_skipped, pos, rest = skip_c_string.call(content, '"')
        
        expect(bytes_skipped).to eq(17)
        expect(pos).to eq(17)
        expect(rest).to eq("code")
      end

      it "skips string with escaped backslash" do
        content = '"path\\\\to\\\\file"code'
        bytes_skipped, pos, rest = skip_c_string.call(content, '"')
        
        expect(bytes_skipped).to eq(16)
        expect(pos).to eq(16)
        expect(rest).to eq("code")
      end

      it "skips string with escaped newline" do
        content = '"hello\\nworld"code'
        bytes_skipped, pos, rest = skip_c_string.call(content, '"')
        
        expect(bytes_skipped).to eq(14)
        expect(pos).to eq(14)
        expect(rest).to eq("code")
      end

      it "skips string with escaped tab" do
        content = '"hello\\tworld"code'
        bytes_skipped, pos, rest = skip_c_string.call(content, '"')
        
        expect(bytes_skipped).to eq(14)
        expect(pos).to eq(14)
        expect(rest).to eq("code")
      end

      it "skips string with escaped carriage return" do
        content = '"hello\\rworld"code'
        bytes_skipped, pos, rest = skip_c_string.call(content, '"')
        
        expect(bytes_skipped).to eq(14)
        expect(pos).to eq(14)
        expect(rest).to eq("code")
      end

      it "skips string with multiple escape sequences" do
        content = '"\\n\\t\\r\\\\\\"\\\'"code'
        bytes_skipped, pos, rest = skip_c_string.call(content, '"')
        
        expect(bytes_skipped).to eq(14)
        expect(pos).to eq(14)
        expect(rest).to eq("code")
      end

      it "skips character with escaped single quote" do
        content = "'\\\''code"
        bytes_skipped, pos, rest = skip_c_string.call(content, "'")
        
        expect(bytes_skipped).to eq(4)
        expect(pos).to eq(4)
        expect(rest).to eq("code")
      end

      it "skips character with escaped backslash" do
        content = "'\\\\'code"
        bytes_skipped, pos, rest = skip_c_string.call(content, "'")
        
        expect(bytes_skipped).to eq(4)
        expect(pos).to eq(4)
        expect(rest).to eq("code")
      end

      it "skips character with escaped newline" do
        content = "'\\n'code"
        bytes_skipped, pos, rest = skip_c_string.call(content, "'")
        
        expect(bytes_skipped).to eq(4)
        expect(pos).to eq(4)
        expect(rest).to eq("code")
      end

      it "skips string with octal escape sequence" do
        content = '"\\101\\102\\103"code'
        bytes_skipped, pos, rest = skip_c_string.call(content, '"')
        
        expect(bytes_skipped).to eq(14)
        expect(pos).to eq(14)
        expect(rest).to eq("code")
      end

      it "skips string with hexadecimal escape sequence" do
        content = '"\\x41\\x42\\x43"code'
        bytes_skipped, pos, rest = skip_c_string.call(content, '"')
        
        expect(bytes_skipped).to eq(14)
        expect(pos).to eq(14)
        expect(rest).to eq("code")
      end

      it "skips string with unicode escape sequence" do
        content = '"\\u0041\\u0042"code'
        bytes_skipped, pos, rest = skip_c_string.call(content, '"')
        
        expect(bytes_skipped).to eq(14)
        expect(pos).to eq(14)
        expect(rest).to eq("code")
      end
    end

    context "unterminated string handling" do
      it "handles unterminated double-quoted string" do
        content = '"hello world'
        bytes_skipped, pos, rest = skip_c_string.call(content, '"')
        
        expect(bytes_skipped).to eq(12)
        expect(pos).to eq(12)
        expect(rest).to eq("")
      end

      it "handles unterminated single-quoted character" do
        content = "'a"
        bytes_skipped, pos, rest = skip_c_string.call(content, "'")
        
        expect(bytes_skipped).to eq(2)
        expect(pos).to eq(2)
        expect(rest).to eq("")
      end

      it "handles unterminated string with escape at end" do
        content = '"hello\\'
        bytes_skipped, pos, rest = skip_c_string.call(content, '"')
        
        expect(bytes_skipped).to eq(7)
        expect(pos).to eq(7)
        expect(rest).to eq("")
      end

      it "handles unterminated string with newline" do
        content = "\"hello\nworld"
        bytes_skipped, pos, rest = skip_c_string.call(content, '"')
        
        expect(bytes_skipped).to eq(12)
        expect(pos).to eq(12)
        expect(rest).to eq("")
      end
    end

    context "edge cases" do
      it "handles string with only opening quote" do
        content = '"'
        bytes_skipped, pos, rest = skip_c_string.call(content, '"')
        
        expect(bytes_skipped).to eq(1)
        expect(pos).to eq(1)
        expect(rest).to eq("")
      end

      it "handles character with only opening quote" do
        content = "'"
        bytes_skipped, pos, rest = skip_c_string.call(content, "'")
        
        expect(bytes_skipped).to eq(1)
        expect(pos).to eq(1)
        expect(rest).to eq("")
      end

      it "handles string with consecutive escaped backslashes" do
        content = '"\\\\\\\\"code'
        bytes_skipped, pos, rest = skip_c_string.call(content, '"')
        
        expect(bytes_skipped).to eq(6)
        expect(pos).to eq(6)
        expect(rest).to eq("code")
      end

      it "handles string ending with backslash before quote" do
        content = '"test\\\\"code'
        bytes_skipped, pos, rest = skip_c_string.call(content, '"')
        
        expect(bytes_skipped).to eq(8)
        expect(pos).to eq(8)
        expect(rest).to eq("code")
      end

      it "does not confuse single quote inside double-quoted string" do
        content = '"don\'t"code'
        bytes_skipped, pos, rest = skip_c_string.call(content, '"')
        
        expect(bytes_skipped).to eq(7)
        expect(pos).to eq(7)
        expect(rest).to eq("code")
      end

      it "does not confuse double quote inside single-quoted character" do
        content = '\'"\'code'
        bytes_skipped, pos, rest = skip_c_string.call(content, "'")
        
        expect(bytes_skipped).to eq(3)
        expect(pos).to eq(3)
        expect(rest).to eq("code")
      end

      it "handles very long string" do
        long_string = '"' + ('x' * 1000) + '"code'
        bytes_skipped, pos, rest = skip_c_string.call(long_string, '"')
        
        expect(bytes_skipped).to eq(1002)
        expect(pos).to eq(1002)
        expect(rest).to eq("code")
      end

      it "handles string with null character" do
        content = "\"hello\\0world\"code"
        bytes_skipped, pos, rest = skip_c_string.call(content, '"')
        
        expect(bytes_skipped).to eq(14)
        expect(pos).to eq(14)
        expect(rest).to eq("code")
      end
    end

    context "real-world C code patterns" do
      it "skips string literal in printf statement" do
        content = '"Hello, World!")'
        bytes_skipped, pos, rest = skip_c_string.call(content, '"')
        
        expect(bytes_skipped).to eq(15)
        expect(pos).to eq(15)
        expect(rest).to eq(")")
      end

      it "skips format string with specifiers" do
        content = '"%d %s %f", x, y, z)'
        bytes_skipped, pos, rest = skip_c_string.call(content, '"')
        
        expect(bytes_skipped).to eq(10)
        expect(pos).to eq(10)
        expect(rest).to eq(', x, y, z)')
      end

      it "skips file path string" do
        content = '"C:\\\\Users\\\\file.txt"code'
        bytes_skipped, pos, rest = skip_c_string.call(content, '"')
        
        expect(bytes_skipped).to eq(21)
        expect(pos).to eq(21)
        expect(rest).to eq("code")
      end

      it "skips character constant in switch case" do
        content = "'a': return 1;"
        bytes_skipped, pos, rest = skip_c_string.call(content, "'")
        
        expect(bytes_skipped).to eq(3)
        expect(pos).to eq(3)
        expect(rest).to eq(": return 1;")
      end

      it "skips string with JSON-like content" do
        content = '"{\"key\": \"value\"}"code'
        bytes_skipped, pos, rest = skip_c_string.call(content, '"')
        
        expect(bytes_skipped).to eq(22)
        expect(pos).to eq(22)
        expect(rest).to eq("code")
      end

      it "skips multi-line string literal (C11 style)" do
        content = "\"line1\\\nline2\\\nline3\"code"
        bytes_skipped, pos, rest = skip_c_string.call(content, '"')
        
        expect(bytes_skipped).to eq(21)
        expect(pos).to eq(21)
        expect(rest).to eq("code")
      end

      it "skips string with SQL query" do
        content = '"SELECT * FROM users WHERE id = 1"code'
        bytes_skipped, pos, rest = skip_c_string.call(content, '"')
        
        expect(bytes_skipped).to eq(34)
        expect(pos).to eq(34)
        expect(rest).to eq("code")
      end
    end

    context "consecutive strings" do
      it "skips first string when followed by another string" do
        content = '"first" "second"'
        bytes_skipped, pos, rest = skip_c_string.call(content, '"')
        
        expect(bytes_skipped).to eq(7)
        expect(pos).to eq(7)
        expect(rest).to eq(' "second"')
      end

      it "skips string followed by character literal" do
        content = '"string" \'c\''
        bytes_skipped, pos, rest = skip_c_string.call(content, '"')
        
        expect(bytes_skipped).to eq(8)
        expect(pos).to eq(8)
        expect(rest).to eq(" 'c'")
      end

      it "skips character literal followed by string" do
        content = "'c' \"string\""
        bytes_skipped, pos, rest = skip_c_string.call(content, "'")
        
        expect(bytes_skipped).to eq(3)
        expect(pos).to eq(3)
        expect(rest).to eq(' "string"')
      end
    end

    context "strings in complex expressions" do
      it "skips string in array initialization" do
        content = '"element1", "element2"'
        bytes_skipped, pos, rest = skip_c_string.call(content, '"')
        
        expect(bytes_skipped).to eq(10)
        expect(pos).to eq(10)
        expect(rest).to eq(', "element2"')
      end

      it "skips string in function call" do
        content = '"argument", 42)'
        bytes_skipped, pos, rest = skip_c_string.call(content, '"')
        
        expect(bytes_skipped).to eq(10)
        expect(pos).to eq(10)
        expect(rest).to eq(", 42)")
      end

      it "skips string in ternary operator" do
        content = '"true" : "false"'
        bytes_skipped, pos, rest = skip_c_string.call(content, '"')
        
        expect(bytes_skipped).to eq(6)
        expect(pos).to eq(6)
        expect(rest).to eq(' : "false"')
      end
    end

    context "performance and boundary conditions" do
      it "handles string at end of input" do
        content = '"last"'
        bytes_skipped, pos, rest = skip_c_string.call(content, '"')
        
        expect(bytes_skipped).to eq(6)
        expect(pos).to eq(6)
        expect(rest).to eq("")
      end

      it "handles character at end of input" do
        content = "'x'"
        bytes_skipped, pos, rest = skip_c_string.call(content, "'")
        
        expect(bytes_skipped).to eq(3)
        expect(pos).to eq(3)
        expect(rest).to eq("")
      end

      it "handles alternating escaped and regular characters" do
        content = '"a\\nb\\tc\\rd\\\\e"code'
        bytes_skipped, pos, rest = skip_c_string.call(content, '"')
        
        expect(bytes_skipped).to eq(15)
        expect(pos).to eq(15)
        expect(rest).to eq("code")
      end
    end

    context "invalid but handled gracefully" do
      it "handles empty character literal" do
        content = "''code"
        bytes_skipped, pos, rest = skip_c_string.call(content, "'")
        
        expect(bytes_skipped).to eq(2)
        expect(pos).to eq(2)
        expect(rest).to eq("code")
      end

      it "handles string with unrecognized escape sequence" do
        # \q is not a valid escape, but should still consume it
        content = '"\\q"code'
        bytes_skipped, pos, rest = skip_c_string.call(content, '"')
        
        expect(bytes_skipped).to eq(4)
        expect(pos).to eq(4)
        expect(rest).to eq("code")
      end

      it "handles incomplete octal escape at end of string" do
        content = '"\\1"code'
        bytes_skipped, pos, rest = skip_c_string.call(content, '"')
        
        expect(bytes_skipped).to eq(4)
        expect(pos).to eq(4)
        expect(rest).to eq("code")
      end

      it "handles incomplete hex escape at end of string" do
        content = '"\\x"code'
        bytes_skipped, pos, rest = skip_c_string.call(content, '"')
        
        expect(bytes_skipped).to eq(4)
        expect(pos).to eq(4)
        expect(rest).to eq("code")
      end

      it "handles backslash at very end of unterminated string" do
        content = '"test\\'
        bytes_skipped, pos, rest = skip_c_string.call(content, '"')
        
        expect(bytes_skipped).to eq(6)
        expect(pos).to eq(6)
        expect(rest).to eq("")
      end
    end
  end

  ###
  ### skip_deadspace()
  ###
  describe "#skip_deadspace (private method testing)" do
    # Helper to access private method
    let(:skip_deadspace) do
      ->(content) do
        extractor_obj = CExtractor.from_string(content: "", chunk_size: 10)
        scanner = StringScanner.new(content)
        bytes_skipped = extractor_obj.send(:skip_deadspace, scanner)
        return [bytes_skipped, scanner.pos, scanner.rest]
      end
    end

    context "whitespace handling" do
      it "skips spaces" do
        content = "     code"
        bytes_skipped, pos, rest = skip_deadspace.call(content)
        
        expect(bytes_skipped).to eq(5)
        expect(pos).to eq(5)
        expect(rest).to eq("code")
      end

      it "skips tabs" do
        content = "\t\t\tcode"
        bytes_skipped, pos, rest = skip_deadspace.call(content)
        
        expect(bytes_skipped).to eq(3)
        expect(pos).to eq(3)
        expect(rest).to eq("code")
      end

      it "skips newlines" do
        content = "\n\n\ncode"
        bytes_skipped, pos, rest = skip_deadspace.call(content)
        
        expect(bytes_skipped).to eq(3)
        expect(pos).to eq(3)
        expect(rest).to eq("code")
      end

      it "skips carriage returns" do
        content = "\r\n\r\ncode"
        bytes_skipped, pos, rest = skip_deadspace.call(content)
        
        expect(bytes_skipped).to eq(4)
        expect(pos).to eq(4)
        expect(rest).to eq("code")
      end

      it "skips mixed whitespace" do
        content = " \t\n \r\n\t code"
        bytes_skipped, pos, rest = skip_deadspace.call(content)
        
        expect(bytes_skipped).to eq(8)
        expect(pos).to eq(8)
        expect(rest).to eq("code")
      end

      it "returns 0 when no whitespace present" do
        content = "code"
        bytes_skipped, pos, rest = skip_deadspace.call(content)
        
        expect(bytes_skipped).to eq(0)
        expect(pos).to eq(0)
        expect(rest).to eq("code")
      end
    end

    context "line comment handling" do
      it "skips single line comment" do
        content = "// comment\ncode"
        bytes_skipped, pos, rest = skip_deadspace.call(content)
        
        expect(bytes_skipped).to eq(11)
        expect(pos).to eq(11)
        expect(rest).to eq("code")
      end

      it "skips line comment without trailing newline" do
        content = "// comment at end"
        bytes_skipped, pos, rest = skip_deadspace.call(content)
        
        expect(bytes_skipped).to eq(17)
        expect(pos).to eq(17)
        expect(rest).to eq("")
      end

      it "skips multiple consecutive line comments" do
        content = "// comment 1\n// comment 2\n// comment 3\ncode"
        bytes_skipped, pos, rest = skip_deadspace.call(content)
        
        expect(bytes_skipped).to eq(39)
        expect(pos).to eq(39)
        expect(rest).to eq("code")
      end

      it "skips line comment with whitespace before it" do
        content = "   // comment\ncode"
        bytes_skipped, pos, rest = skip_deadspace.call(content)
        
        expect(bytes_skipped).to eq(14)
        expect(pos).to eq(14)
        expect(rest).to eq("code")
      end

      it "handles line comment with special characters" do
        content = "// TODO: fix this!!!\ncode"
        bytes_skipped, pos, rest = skip_deadspace.call(content)
        
        expect(bytes_skipped).to eq(21)
        expect(pos).to eq(21)
        expect(rest).to eq("code")
      end
    end

    context "block comment handling" do
      it "skips single-line block comment" do
        content = "/* comment */code"
        bytes_skipped, pos, rest = skip_deadspace.call(content)
        
        expect(bytes_skipped).to eq(13)
        expect(pos).to eq(13)
        expect(rest).to eq("code")
      end

      it "skips multi-line block comment" do
        content = "/* comment\nline 2\nline 3 */code"
        bytes_skipped, pos, rest = skip_deadspace.call(content)
        
        expect(bytes_skipped).to eq(27)
        expect(pos).to eq(27)
        expect(rest).to eq("code")
      end

      it "skips multiple consecutive block comments" do
        content = "/* first *//* second *//* third */code"
        bytes_skipped, pos, rest = skip_deadspace.call(content)
        
        expect(bytes_skipped).to eq(34)
        expect(pos).to eq(34)
        expect(rest).to eq("code")
      end

      it "skips block comment with whitespace before it" do
        content = "   /* comment */code"
        bytes_skipped, pos, rest = skip_deadspace.call(content)
        
        expect(bytes_skipped).to eq(16)
        expect(pos).to eq(16)
        expect(rest).to eq("code")
      end

      it "handles block comment with asterisks inside" do
        content = "/* ** comment ** */code"
        bytes_skipped, pos, rest = skip_deadspace.call(content)
        
        expect(bytes_skipped).to eq(19)
        expect(pos).to eq(19)
        expect(rest).to eq("code")
      end

      it "handles block comment with forward slashes inside" do
        content = "/* comment // not a line comment */code"
        bytes_skipped, pos, rest = skip_deadspace.call(content)
        
        expect(bytes_skipped).to eq(35)
        expect(pos).to eq(35)
        expect(rest).to eq("code")
      end

      it "handles unterminated block comment" do
        content = "/* unterminated comment"
        bytes_skipped, pos, rest = skip_deadspace.call(content)
        
        expect(bytes_skipped).to eq(23)
        expect(pos).to eq(23)
        expect(rest).to eq("")
      end
    end

    context "preprocessor directive handling" do
      it "skips simple #include directive" do
        content = "#include <stdio.h>\ncode"
        bytes_skipped, pos, rest = skip_deadspace.call(content)
        
        expect(bytes_skipped).to eq(19)
        expect(pos).to eq(19)
        expect(rest).to eq("code")
      end

      it "skips #define directive" do
        content = "#define MAX 100\ncode"
        bytes_skipped, pos, rest = skip_deadspace.call(content)
        
        expect(bytes_skipped).to eq(16)
        expect(pos).to eq(16)
        expect(rest).to eq("code")
      end

      it "skips #ifdef directive" do
        content = "#ifdef DEBUG\ncode"
        bytes_skipped, pos, rest = skip_deadspace.call(content)
        
        expect(bytes_skipped).to eq(13)
        expect(pos).to eq(13)
        expect(rest).to eq("code")
      end

      it "skips directive with line continuation" do
        content = "#define MACRO(x) \\\n  do { something; } \\\n  while(0)\ncode"
        bytes_skipped, pos, rest = skip_deadspace.call(content)
        
        expect(bytes_skipped).to eq(52)
        expect(pos).to eq(52)
        expect(rest).to eq("code")
      end

      it "skips multiple consecutive directives" do
        content = "#include <stdio.h>\n#include <stdlib.h>\n#define MAX 100\ncode"
        bytes_skipped, pos, rest = skip_deadspace.call(content)
        
        expect(bytes_skipped).to eq(55)
        expect(pos).to eq(55)
        expect(rest).to eq("code")
      end

      it "skips directive with whitespace before hash" do
        content = "  #define FOO\ncode"
        bytes_skipped, pos, rest = skip_deadspace.call(content)
        
        expect(bytes_skipped).to eq(14)
        expect(pos).to eq(14)
        expect(rest).to eq("code")
      end

      it "skips directive without trailing newline" do
        content = "#define FOO"
        bytes_skipped, pos, rest = skip_deadspace.call(content)
        
        expect(bytes_skipped).to eq(11)
        expect(pos).to eq(11)
        expect(rest).to eq("")
      end

      it "handles directive with multiple line continuations" do
        content = "#define LONG_MACRO \\\n  line1 \\\n  line2 \\\n  line3\ncode"
        bytes_skipped, pos, rest = skip_deadspace.call(content)
        
        expect(bytes_skipped).to eq(49)
        expect(pos).to eq(49)
        expect(rest).to eq("code")
      end
    end

    context "mixed deadspace handling" do
      it "skips whitespace followed by comment" do
        content = "  \t/* comment */code"
        bytes_skipped, pos, rest = skip_deadspace.call(content)
        
        expect(bytes_skipped).to eq(16)
        expect(pos).to eq(16)
        expect(rest).to eq("code")
      end

      it "skips comment followed by whitespace" do
        content = "/* comment */  \ncode"
        bytes_skipped, pos, rest = skip_deadspace.call(content)
        
        expect(bytes_skipped).to eq(16)
        expect(pos).to eq(16)
        expect(rest).to eq("code")
      end

      it "skips line comment followed by block comment" do
        content = "// line\n/* block */code"
        bytes_skipped, pos, rest = skip_deadspace.call(content)
        
        expect(bytes_skipped).to eq(19)
        expect(pos).to eq(19)
        expect(rest).to eq("code")
      end

      it "skips preprocessor followed by comment" do
        content = "#define FOO\n// comment\ncode"
        bytes_skipped, pos, rest = skip_deadspace.call(content)
        
        expect(bytes_skipped).to eq(23)
        expect(pos).to eq(23)
        expect(rest).to eq("code")
      end

      it "skips comment followed by preprocessor" do
        content = "/* comment */\n#define FOO\ncode"
        bytes_skipped, pos, rest = skip_deadspace.call(content)
        
        expect(bytes_skipped).to eq(26)
        expect(pos).to eq(26)
        expect(rest).to eq("code")
      end

      it "skips complex mix of all deadspace types" do
        content = "  \n// comment\n  /* block */\n  #define FOO\n  code"
        bytes_skipped, pos, rest = skip_deadspace.call(content)
        
        expect(bytes_skipped).to eq(44)
        expect(pos).to eq(44)
        expect(rest).to eq("code")
      end
     it "skips comment followed by preprocessor" do
        content = "/* comment */\n#define FOO\ncode"
        bytes_skipped, pos, rest = skip_deadspace.call(content)
        
        expect(bytes_skipped).to eq(26)
        expect(pos).to eq(26)
        expect(rest).to eq("code")
      end
    end

    context "edge cases" do
      it "handles empty string" do
        content = ""
        bytes_skipped, pos, rest = skip_deadspace.call(content)
        
        expect(bytes_skipped).to eq(0)
        expect(pos).to eq(0)
        expect(rest).to eq("")
      end

      it "handles string with only whitespace" do
        content = "   \t\n  "
        bytes_skipped, pos, rest = skip_deadspace.call(content)
        
        expect(bytes_skipped).to eq(7)
        expect(pos).to eq(7)
        expect(rest).to eq("")
      end

      it "handles string with only comments" do
        content = "// comment\n/* block */"
        bytes_skipped, pos, rest = skip_deadspace.call(content)
        
        expect(bytes_skipped).to eq(22)
        expect(pos).to eq(22)
        expect(rest).to eq("")
      end

      it "handles string with only preprocessor directives" do
        content = "#define FOO\n#include <bar.h>"
        bytes_skipped, pos, rest = skip_deadspace.call(content)
        
        expect(bytes_skipped).to eq(28)
        expect(pos).to eq(28)
        expect(rest).to eq("")
      end

      it "does not skip code that looks like comment but isn't" do
        content = "int a = 5 / 2; // actual comment\ncode"
        bytes_skipped, pos, rest = skip_deadspace.call(content)
        
        expect(bytes_skipped).to eq(0)
        expect(pos).to eq(0)
        expect(rest).to start_with("int a")
      end

      it "handles nested block comments (not standard C)" do
        # NOTE: C extraction is not implemented as a full C parser and/or preprocessor
        # We assume that the file to be processed is either relatively simple or has already been preprocessed
        # to remove complex preprocessor directives, etc.

        content = "/* outer /* inner */ still outer */code"
        bytes_skipped, pos, rest = skip_deadspace.call(content)
        
        # We expect only partial comment block handling for nested blocks
        expect(bytes_skipped).to eq(21)
        expect(pos).to eq(21)
        expect(rest).to eq("still outer */code")
      end
    end

    context "real-world C code patterns" do
      it "skips typical file header" do
        content = <<~C
          // File: example.c
          // Author: Someone
          /* Copyright notice
             spanning multiple lines */
          
          #include <stdio.h>
          #include <stdlib.h>
          
          #define MAX_SIZE 100
          
          int main() {
        C
        
        _, _, rest = skip_deadspace.call(content)
        
        expect(rest).to start_with("int main()")
      end

      it "skips multiple successive preprocessor directive lines" do
        content = <<~C
          #ifdef DEBUG
          #define LOG(x) printf(x)
          #else
          #define LOG(x)
          #endif
          
          void foo() {
        C
        
        _, _, rest = skip_deadspace.call(content)
        
        expect(rest).to start_with("void foo()")
      end

      it "handles Doxygen-style comments" do
        content = <<~CODE
          /**
           * @brief Function description
           * @param x The parameter
           * @return The result
           */
          int func(int x) {
        CODE
        
        _, _, rest = skip_deadspace.call(content)
        
        expect(rest).to start_with("int func(int x)")
      end

      it "should not be able to process disabled code blocks" do
        # NOTE: C extraction is not implemented as a full C parser and/or preprocessor
        # We assume that the file to be processed is either relatively simple or has already been preprocessed
        # to remove complex preprocessor directives, etc.

        content = <<~CODE
          #if 0
          // This code is disabled
          void old_function() {
              // ...
          }
          #endif
          
          void new_function() {
        CODE
        
        _, _, rest = skip_deadspace.call(content)
        
        expect(rest).to start_with("void old_function() {\n    // ...\n}\n#endif\n\nvoid new_function() {\n")
      end
    end
  end


  ###
  ### extract_next_feature()
  ###
  describe "#extract_next_feature (private method testing)" do
    # Helper to create a simple extractor that looks for a specific pattern
    # NOTE: `scanner.scan()` expects pattern to match from the current position
    let(:create_pattern_extractor) do
      ->(pattern) do
        ->(scanner) do
          if scanner.scan(pattern)
            matched = scanner.matched
            return [true, matched]
          end
          return [false, nil]
        end
      end
    end

    # Helper to access private method
    let(:extract_feature) do
      ->(io, max_length, extractor, chunk_size=10) do
        extractor_obj = CExtractor.from_string(content: "", chunk_size: chunk_size)
        extractor_obj.send(:extract_next_feature, io: io, max_length: max_length, extractor: extractor)
      end
    end

     context "basic extraction" do
      it "extracts a simple pattern within first chunk" do
        content = "HELLO // comment"
        io = StringIO.new(content)
        extractor = create_pattern_extractor.call(/HELLO/)
        
        result = extract_feature.call(io, 1000, extractor)
        
        expect(result).to eq("HELLO")
        expect(io.pos).to eq(5) # Position after "HELLO"
      end

      it "returns nil when pattern is not found before EOF" do
        content = "// no content in these chunks"
        io = StringIO.new(content)
        extractor = create_pattern_extractor.call(/NOTFOUND/)
        
        result = extract_feature.call(io, 1000, extractor)
        
        expect(result).to be_nil
        expect(io.eof?).to be true
      end

      it "advances scanner position on success" do
        content = "PREFIX:DATA:SUFFIX"
        io = StringIO.new(content)
        
        extractor = ->(scanner) do
          # Look for pattern like "PREFIX:DATA:"
          if scanner.scan(/PREFIX:(\w+):/)
            return [true, scanner[1]] # Return just the captured DATA part
          end
          [false, nil]
        end
        
        result = extract_feature.call(io, 1000, extractor)
        
        expect(result).to eq("DATA")
        expect(io.pos).to eq(12) # After "PREFIX:DATA:"
      end    end

    context "multiple extractions" do
      it "extracts multiple features sequentially from same IO" do
        content = "FIRST SECOND THIRD"
        io = StringIO.new(content)
        extractor = create_pattern_extractor.call(/\w+/)
        
        result1 = extract_feature.call(io, 1000, extractor)
        result2 = extract_feature.call(io, 1000, extractor)
        result3 = extract_feature.call(io, 1000, extractor)
        result4 = extract_feature.call(io, 1000, extractor)
        
        expect(result1).to eq("FIRST")
        expect(result2).to eq("SECOND")
        expect(result3).to eq("THIRD")
        expect(result4).to be_nil
      end

      it "positions IO correctly after each extraction" do
        content = "AAA BBB CCC"
        io = StringIO.new(content)
        extractor = create_pattern_extractor.call(/\w+/)
        
        extract_feature.call(io, 1000, extractor)
        pos_after_first = io.pos
        
        extract_feature.call(io, 1000, extractor)
        pos_after_second = io.pos
        
        expect(pos_after_first).to eq(3) # After "AAA"
        expect(pos_after_second).to eq(7) # After "AAA BBB"
      end
    end

    context "whitespace and deadspace handling" do
      it "skips whitespace before pattern" do
        content = "   \n\t  PATTERN"
        io = StringIO.new(content)
        extractor = create_pattern_extractor.call(/PATTERN/)
        
        result = extract_feature.call(io, 1000, extractor)
        
        expect(result).to eq("PATTERN")
      end

      it "skips comments before pattern" do
        content = "// comment\n/* block */PATTERN"
        io = StringIO.new(content)
        extractor = create_pattern_extractor.call(/PATTERN/)
        
        result = extract_feature.call(io, 1000, extractor)
        
        expect(result).to eq("PATTERN")
      end

      it "skips preprocessor directives before pattern" do
        content = "#include <stdio.h>\n#define FOO 123\nPATTERN"
        io = StringIO.new(content)
        extractor = create_pattern_extractor.call(/PATTERN/)
        
        result = extract_feature.call(io, 1000, extractor)
        
        expect(result).to eq("PATTERN")
      end
    end

    context "buffer growth and limits" do
      it "extracts pattern that spans multiple chunks" do
        content = "/*pre*/ LOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOONG_PATTERN /*post*/"
        io = StringIO.new(content)
        # Chunk size is 10, so "LONG_PATTERN" will span chunks
        extractor = create_pattern_extractor.call(/L(O)+NG_PATTERN/)
        
        result = extract_feature.call(io, 1000, extractor)
        
        expect(result).to eq("LOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOONG_PATTERN")
      end

      it "grows buffer across many chunks until pattern is found" do
        # Create content where pattern appears after several chunks
        content = "\t" * 100 + "TARGET"
        io = StringIO.new(content)
        extractor = create_pattern_extractor.call(/TARGET/)
        
        result = extract_feature.call(io, 1000, extractor)
        
        expect(result).to eq("TARGET")
      end

      it "raises error when buffer exceeds max_length" do
        content = "x" * 200 # Long string
        io = StringIO.new(content)
        extractor = create_pattern_extractor.call(/NOTFOUND/)
        
        expect {
          extract_feature.call(io, 100, extractor)
        }.to raise_error(CeedlingException, /exceeds maximum length/)
      end
    end

    context "edge cases" do
      it "handles empty IO" do
        io = StringIO.new("")
        extractor = create_pattern_extractor.call(/ANYTHING/)
        
        result = extract_feature.call(io, 1000, extractor)
        
        expect(result).to be_nil
      end

      it "handles IO with only whitespace and comments" do
        content = "   \n\t  // comment\n/* block */  \n"
        io = StringIO.new(content)
        extractor = create_pattern_extractor.call(/PATTERN/)
        
        result = extract_feature.call(io, 1000, extractor)
        
        expect(result).to be_nil
      end

      it "handles pattern at very end of IO" do
        content = "/*prefix*/ PATTERN"
        io = StringIO.new(content)
        extractor = create_pattern_extractor.call(/PATTERN/)
        
        result = extract_feature.call(io, 1000, extractor)
        
        expect(result).to eq("PATTERN")
        expect(io.eof?).to be true
      end

      it "handles pattern at very beginning of IO" do
        content = "PATTERN /*suffix*/"
        io = StringIO.new(content)
        extractor = create_pattern_extractor.call(/PATTERN/)
        
        result = extract_feature.call(io, 1000, extractor)
        
        expect(result).to eq("PATTERN")
        expect(io.pos).to eq(7)
      end

      it "allows extraction when pattern exactly matches chunk size" do
        content = "FOUND"
        io = StringIO.new(content)
        extractor = create_pattern_extractor.call(/FOUND/)
        
        result = extract_feature.call(io, 100, extractor, 5)
        
        expect(result).to eq("FOUND")
      end

      it "allows extraction when exactly at max_length" do
        content = "\n" * 95 + "FOUND" # 100 characters
        io = StringIO.new(content)
        extractor = create_pattern_extractor.call(/FOUND/)
        
        result = extract_feature.call(io, 100, extractor)
        
        expect(result).to eq("FOUND")
      end

      it "handles pattern split exactly at chunk boundary" do
        # With chunk_size=10, "/*012345*/" fills first chunk exactly
        content = "/*012345*/PATTERN"
        io = StringIO.new(content)
        extractor = create_pattern_extractor.call(/PATTERN/)
        
        result = extract_feature.call(io, 1000, extractor)
        
        expect(result).to eq("PATTERN")
      end

      it "handles comment spanning chunk boundaries" do
        content = "/* comment across\nchunk boundary */PATTERN"
        io = StringIO.new(content)
        extractor = create_pattern_extractor.call(/PATTERN/)
        
        result = extract_feature.call(io, 1000, extractor)
        
        expect(result).to eq("PATTERN")
      end
    end

    context "performance and safety" do
      it "stops reading when max_length is reached" do
        # Create content larger than max_length
        large_content = "x" * 500
        io = StringIO.new(large_content)
        extractor = create_pattern_extractor.call(/NOTFOUND/)
        
        expect {
          extract_feature.call(io, 200, extractor)
        }.to raise_error(CeedlingException, /exceeds maximum length/)
        
        # IO should not have read entire content
        expect(io.pos).to be < large_content.length
      end

      it "handles rapid successive extractions efficiently" do
        content = "A B C D E F G H I J"
        io = StringIO.new(content)
        extractor = create_pattern_extractor.call(/\w/)
        
        results = []
        10.times do
          result = extract_feature.call(io, 1000, extractor)
          break unless result
          results << result
        end
        
        expect(results).to eq(["A", "B", "C", "D", "E", "F", "G", "H", "I", "J"])
      end
    end
  end

end