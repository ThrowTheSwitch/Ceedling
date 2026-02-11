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
        extractor = CExtractor.from_string(content: "", chunk_size: 10)
        scanner = StringScanner.new(content)
        bytes_skipped = extractor.send(:skip_c_string, scanner, quote)
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
        extractor = CExtractor.from_string(content: "", chunk_size: 10)
        scanner = StringScanner.new(content)
        bytes_skipped = extractor.send(:skip_deadspace, scanner)
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

    context "IO access and buffer usage" do
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
        }.to raise_error(CeedlingException, /exceeded maximum length/)
      end

      it "extracts multiple features from same chunk" do
        # Other test cases deal with growing the internal buffer with multiple chunk reads from IO.
        # This test case ensures we can extract multiple features from the same large chunk.

        content = "FIRST" + (' ' * 500) + "SECOND" + (' ' * 500) + "THIRD"
        io = StringIO.new(content)
        extractor = create_pattern_extractor.call(/\w+/)

        extractor_obj = CExtractor.from_string(content: "", chunk_size: 2000)

        result1 = extractor_obj.send(:extract_next_feature, io: io, max_length: 1200, extractor: extractor)
        result2 = extractor_obj.send(:extract_next_feature, io: io, max_length: 1200, extractor: extractor)
        result3 = extractor_obj.send(:extract_next_feature, io: io, max_length: 1200, extractor: extractor)
        result4 = extractor_obj.send(:extract_next_feature, io: io, max_length: 1200, extractor: extractor)
               
        expect(result1).to eq("FIRST")
        expect(result2).to eq("SECOND")
        expect(result3).to eq("THIRD")
        expect(result4).to be_nil
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
        }.to raise_error(CeedlingException, /exceeded maximum length/)
        
        # IO should not have read entire content
        expect(io.pos).to be < large_content.length
      end

      it "handles rapid successive extractions" do
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

  ###
  ### extract_balanced_braces()
  ###

  describe "#extract_balanced_braces (private method testing)" do
    # Helper to access private method
    let(:extract_braces) do
      ->(content) do
        extractor = CExtractor.from_string(content: "", chunk_size: 10)
        scanner = StringScanner.new(content)
        success, block = extractor.send(:extract_balanced_braces, scanner)
        return [success, block, scanner.pos, scanner.rest]
      end
    end

    context "simple balanced braces" do
      it "extracts single-level braces" do
        content = "{ code }"
        success, block, pos, rest = extract_braces.call(content)
        
        expect(success).to be true
        expect(block).to eq("{ code }")
        expect(pos).to eq(8)
        expect(rest).to eq("")
      end

      it "extracts empty braces" do
        content = "{}"
        success, block, pos, rest = extract_braces.call(content)
        
        expect(success).to be true
        expect(block).to eq("{}")
        expect(pos).to eq(2)
        expect(rest).to eq("")
      end

      it "extracts braces with content after" do
        content = "{ code } more"
        success, block, pos, rest = extract_braces.call(content)
        
        expect(success).to be true
        expect(block).to eq("{ code }")
        expect(pos).to eq(8)
        expect(rest).to eq(" more")
      end

      it "extracts braces with whitespace" do
        content = "{   \n\t  }"
        success, block, pos, rest = extract_braces.call(content)
        
        expect(success).to be true
        expect(block).to eq("{   \n\t  }")
        expect(pos).to eq(9)
        expect(rest).to eq("")
      end
    end

    context "nested braces" do
      it "extracts one level of nesting" do
        content = "{ outer { inner } }"
        success, block, pos, rest = extract_braces.call(content)
        
        expect(success).to be true
        expect(block).to eq("{ outer { inner } }")
        expect(pos).to eq(19)
        expect(rest).to eq("")
      end

      it "extracts two levels of nesting" do
        content = "{ a { b { c } } }"
        success, block, pos, rest = extract_braces.call(content)
        
        expect(success).to be true
        expect(block).to eq("{ a { b { c } } }")
        expect(pos).to eq(17)
        expect(rest).to eq("")
      end

      it "extracts multiple nested blocks at same level" do
        content = "{ { a } { b } { c } }"
        success, block, pos, rest = extract_braces.call(content)
        
        expect(success).to be true
        expect(block).to eq("{ { a } { b } { c } }")
        expect(pos).to eq(21)
        expect(rest).to eq("")
      end

      it "extracts deeply nested braces" do
        content = "{ { { { { deep } } } } }"
        success, block, pos, rest = extract_braces.call(content)
        
        expect(success).to be true
        expect(block).to eq("{ { { { { deep } } } } }")
        expect(pos).to eq(24)
        expect(rest).to eq("")
      end
    end

    context "braces in strings" do
      it "ignores braces in double-quoted strings" do
        content = '{ "string with brace }" }'
        success, block, pos, rest = extract_braces.call(content)
        
        expect(success).to be true
        expect(block).to eq('{ "string with brace }" }')
        expect(pos).to eq(25)
        expect(rest).to eq("")
      end

      it "ignores braces in single-quoted strings" do
        content = "{ 'char {' }"
        success, block, pos, rest = extract_braces.call(content)
        
        expect(success).to be true
        expect(block).to eq("{ 'char {' }")
        expect(pos).to eq(12)
        expect(rest).to eq("")
      end

      it "handles escaped quotes in strings with braces" do
        content = '{ "string with \\" and { brace" }'
        success, block, pos, rest = extract_braces.call(content)
        
        expect(success).to be true
        expect(block).to eq('{ "string with \\" and { brace" }')
        expect(pos).to eq(32)
        expect(rest).to eq("")
      end

      it "handles multiple strings with braces" do
        content = '{ "first { }" "second } " }'
        success, block, pos, rest = extract_braces.call(content)
        
        expect(success).to be true
        expect(block).to eq('{ "first { }" "second } " }')
        expect(pos).to eq(27)
        expect(rest).to eq("")
      end

      it "handles empty strings" do
        content = '{ "" }'
        success, block, pos, rest = extract_braces.call(content)
        
        expect(success).to be true
        expect(block).to eq('{ "" }')
        expect(pos).to eq(6)
        expect(rest).to eq("")
      end
    end

    context "braces in comments" do
      it "ignores braces in line comments" do
        content = "{ code // comment with { brace\n}"
        success, block, pos, rest = extract_braces.call(content)
        
        expect(success).to be true
        expect(block).to eq("{ code // comment with { brace\n}")
        expect(pos).to eq(32)
        expect(rest).to eq("")
      end

      it "ignores braces in block comments" do
        content = "{ code /* comment with { brace */ }"
        success, block, pos, rest = extract_braces.call(content)
        
        expect(success).to be true
        expect(block).to eq("{ code /* comment with { brace */ }")
        expect(pos).to eq(35)
        expect(rest).to eq("")
      end

      it "handles multiple comments with braces" do
        content = "{ /* { */ code // }\n}"
        success, block, pos, rest = extract_braces.call(content)
        
        expect(success).to be true
        expect(block).to eq("{ /* { */ code // }\n}")
        expect(pos).to eq(21)
        expect(rest).to eq("")
      end

      it "handles nested block comments with braces" do
        content = "{ /* outer { /* inner } */ */ }"
        success, block, pos, rest = extract_braces.call(content)
        
        expect(success).to be true
        expect(block).to eq("{ /* outer { /* inner } */ */ }")
        expect(pos).to eq(31)
        expect(rest).to eq("")
      end
    end

    context "real C code patterns" do
      it "extracts simple function body" do
        content = "{ return 0; }"
        success, block, pos, rest = extract_braces.call(content)
        
        expect(success).to be true
        expect(block).to eq("{ return 0; }")
        expect(pos).to eq(13)
        expect(rest).to eq("")
      end

      it "extracts function body with nested blocks" do
        content = "{ if (x) { do_something(); } }"
        success, block, pos, rest = extract_braces.call(content)
        
        expect(success).to be true
        expect(block).to eq("{ if (x) { do_something(); } }")
        expect(pos).to eq(30)
        expect(rest).to eq("")
      end

      it "extracts function body with multiple statements" do
        content = <<~CODE.chomp
          {
            int x = 5;
            printf("value: %d", x);
            return x;
          }
        CODE
        success, block, pos, rest = extract_braces.call(content)
        
        expect(success).to be true
        expect(block).to eq(content)
        expect(pos).to eq(content.length)
        expect(rest).to eq("")
      end

      it "extracts struct initialization" do
        content = '{ .field1 = 10, .field2 = "test" }'
        success, block, pos, rest = extract_braces.call(content)
        
        expect(success).to be true
        expect(block).to eq('{ .field1 = 10, .field2 = "test" }')
        expect(pos).to eq(34)
        expect(rest).to eq("")
      end

      it "extracts array initialization" do
        content = "{ 1, 2, 3, 4, 5 }"
        success, block, pos, rest = extract_braces.call(content)
        
        expect(success).to be true
        expect(block).to eq("{ 1, 2, 3, 4, 5 }")
        expect(pos).to eq(17)
        expect(rest).to eq("")
      end

      it "extracts switch statement" do
        content = <<~CODE.chomp
          {
            switch (x) {
              case 1: { action1(); break; }
              case 2: { action2(); break; }
              default: { action_default(); }
            }
          }
        CODE
        success, block, pos, rest = extract_braces.call(content)
        
        expect(success).to be true
        expect(block).to eq(content)
        expect(pos).to eq(content.length)
        expect(rest).to eq("")
      end

      it "extracts do-while loop" do
        content = "{ do { process(); } while (condition); }"
        success, block, pos, rest = extract_braces.call(content)
        
        expect(success).to be true
        expect(block).to eq("{ do { process(); } while (condition); }")
        expect(pos).to eq(40)
        expect(rest).to eq("")
      end

      it "extracts nested if-else blocks" do
        content = <<~CODE.chomp
          {
            if (a) {
              if (b) { x(); }
              else { y(); }
            } else {
              z();
            }
          }
        CODE
        success, block, pos, rest = extract_braces.call(content)
        
        expect(success).to be true
        expect(block).to eq(content)
        expect(pos).to eq(content.length)
        expect(rest).to eq("")
      end
    end

    context "failure cases" do
      it "fails when not starting at opening brace" do
        content = "not a brace"
        success, block, pos, rest = extract_braces.call(content)
        
        expect(success).to be false
        expect(block).to be_nil
        expect(pos).to eq(1) # Advanced by one character (the 'n')
        expect(rest).to eq("ot a brace")
      end

      it "fails on unbalanced braces (missing closing)" do
        content = "{ incomplete"
        success, block, pos, rest = extract_braces.call(content)
        
        expect(success).to be false
        expect(block).to be_nil
        expect(pos).to eq(12) # At end of string
        expect(rest).to eq("")
      end

      it "fails on unbalanced braces (extra closing)" do
        content = "{ code } }"
        success, block, pos, rest = extract_braces.call(content)
        
        expect(success).to be true
        expect(block).to eq("{ code }")
        expect(pos).to eq(8)
        expect(rest).to eq(" }")
      end

      it "fails on unbalanced nested braces" do
        content = "{ outer { inner }"
        success, block, pos, rest = extract_braces.call(content)
        
        expect(success).to be false
        expect(block).to be_nil
        expect(pos).to eq(17)
        expect(rest).to eq("")
      end

      it "fails on empty content" do
        content = ""
        success, block, pos, rest = extract_braces.call(content)
        
        expect(success).to be false
        expect(block).to be_nil
        expect(pos).to eq(0)
        expect(rest).to eq("")
      end

      it "fails when starting with closing brace" do
        content = "} wrong"
        success, block, pos, rest = extract_braces.call(content)
        
        expect(success).to be false
        expect(block).to be_nil
        expect(pos).to eq(1)
        expect(rest).to eq(" wrong")
      end
    end

    context "edge cases with strings and comments" do
      it "handles string with escaped backslash before quote" do
        content = '{ "path\\\\file" }'
        success, block, pos, rest = extract_braces.call(content)
        
        expect(success).to be true
        expect(block).to eq('{ "path\\\\file" }')
        expect(pos).to eq(16)
        expect(rest).to eq("")
      end

      it "handles string with escaped newline" do
        content = '{ "line1\\nline2" }'
        success, block, pos, rest = extract_braces.call(content)
        
        expect(success).to be true
        expect(block).to eq('{ "line1\\nline2" }')
        expect(pos).to eq(18)
        expect(rest).to eq("")
      end

      it "handles character literal with closing brace" do
        content = "{ char c = '}'; }"
        success, block, pos, rest = extract_braces.call(content)
        
        expect(success).to be true
        expect(block).to eq("{ char c = '}'; }")
        expect(pos).to eq(17)
        expect(rest).to eq("")
      end

      it "handles character literal with opening brace" do
        content = "{ char c = '{'; }"
        success, block, pos, rest = extract_braces.call(content)
        
        expect(success).to be true
        expect(block).to eq("{ char c = '{'; }")
        expect(pos).to eq(17)
        expect(rest).to eq("")
      end

      it "handles escaped single quote in character literal" do
        content = "{ char c = '\\''; }"
        success, block, pos, rest = extract_braces.call(content)
        
        expect(success).to be true
        expect(block).to eq("{ char c = '\\''; }")
        expect(pos).to eq(18)
        expect(rest).to eq("")
      end

      it "handles comment at end of line with brace" do
        content = "{ code; // comment }\n}"
        success, block, pos, rest = extract_braces.call(content)
        
        expect(success).to be true
        expect(block).to eq("{ code; // comment }\n}")
        expect(pos).to eq(22)
        expect(rest).to eq("")
      end

      it "handles block comment spanning multiple lines with braces" do
        content = <<~CODE.chomp
          {
            /* This is a comment
               with { braces } in it
               spanning lines */
            code;
          }
        CODE
        success, block, pos, rest = extract_braces.call(content)
        
        expect(success).to be true
        expect(block).to eq(content)
        expect(pos).to eq(content.length)
        expect(rest).to eq("")
      end

      it "handles unterminated string (malformed C)" do
        # NOTE: This tests behavior with malformed C code
        content = '{ "unterminated }'
        success, block, _, _ = extract_braces.call(content)
        
        # The extractor should fail because the closing brace is inside an unterminated string
        expect(success).to be false
        expect(block).to be_nil
      end

      it "handles unterminated comment (malformed C)" do
        # NOTE: This tests behavior with malformed C code
        content = "{ /* unterminated }"
        success, block, _, _ = extract_braces.call(content)
        
        # The extractor should fail because the closing brace is inside an unterminated comment
        expect(success).to be false
        expect(block).to be_nil
      end
    end

    context "complex real-world patterns" do
      it "extracts function with macro usage" do
        content = <<~CODE.chomp
          {
            MACRO_CALL(arg1, arg2);
            if (CHECK_FLAG(x)) {
              DO_SOMETHING();
            }
          }
        CODE
        success, block, pos, rest = extract_braces.call(content)
        
        expect(success).to be true
        expect(block).to eq(content)
        expect(pos).to eq(content.length)
        expect(rest).to eq("")
      end

      it "extracts function with string containing comment-like text" do
        content = '{ printf("/* not a comment */"); }'
        success, block, pos, rest = extract_braces.call(content)
        
        expect(success).to be true
        expect(block).to eq('{ printf("/* not a comment */"); }')
        expect(pos).to eq(34)
        expect(rest).to eq("")
      end

      it "extracts function with comment containing string-like text" do
        content = '{ /* "not a string" */ code; }'
        success, block, pos, rest = extract_braces.call(content)
        
        expect(success).to be true
        expect(block).to eq('{ /* "not a string" */ code; }')
        expect(pos).to eq(30)
        expect(rest).to eq("")
      end

      it "extracts nested struct and array initializers" do
        content = <<~CODE.chomp
          {
            struct data d = {
              .array = { 1, 2, 3 },
              .nested = { { 4, 5 }, { 6, 7 } }
            };
          }
        CODE
        success, block, pos, rest = extract_braces.call(content)
        
        expect(success).to be true
        expect(block).to eq(content)
        expect(pos).to eq(content.length)
        expect(rest).to eq("")
      end

      it "extracts function with ternary operator and braces" do
        content = "{ result = condition ? { .a = 1 } : { .b = 2 }; }"
        success, block, pos, rest = extract_braces.call(content)
        
        expect(success).to be true
        expect(block).to eq("{ result = condition ? { .a = 1 } : { .b = 2 }; }")
        expect(pos).to eq(49)
        expect(rest).to eq("")
      end

      it "extracts function with compound literal" do
        content = "{ func((struct point){ .x = 10, .y = 20 }); }"
        success, block, pos, rest = extract_braces.call(content)
        
        expect(success).to be true
        expect(block).to eq("{ func((struct point){ .x = 10, .y = 20 }); }")
        expect(pos).to eq(45)
        expect(rest).to eq("")
      end

      it "extracts function with designated initializers and nested braces" do
        content = <<~CODE.chomp
          {
            struct config cfg = {
              [0] = { .name = "first", .value = { 1, 2 } },
              [1] = { .name = "second", .value = { 3, 4 } }
            };
          }
        CODE
        success, block, pos, rest = extract_braces.call(content)
        
        expect(success).to be true
        expect(block).to eq(content)
        expect(pos).to eq(content.length)
        expect(rest).to eq("")
      end
    end

    context "scanner position management" do
      it "leaves scanner at correct position after successful extraction" do
        content = "{ first }{ second }{third}"
        extractor = CExtractor.from_string(content: "", chunk_size: 10)
        scanner = StringScanner.new(content)
        
        success1, block1 = extractor.send(:extract_balanced_braces, scanner)

        expect(success1).to be true
        expect(block1).to eq("{ first }")

        success2, block2 = extractor.send(:extract_balanced_braces, scanner)
        
        expect(success2).to be true
        expect(block2).to eq("{ second }")

        success3, block3 = extractor.send(:extract_balanced_braces, scanner)
        
        expect(success3).to be true
        expect(block3).to eq("{third}")

        expect(scanner.eos?).to be true
      end

      it "leaves scanner at correct position after failed extraction" do
        content = "not_brace { valid }"
        extractor = CExtractor.from_string(content: "", chunk_size: 10)
        scanner = StringScanner.new(content)
        
        success1, block1 = extractor.send(:extract_balanced_braces, scanner)
        
        expect(success1).to be false
        expect(block1).to be_nil
        expect(scanner.pos).to eq(1) # Advanced by one character
        
        # Skip to the valid brace
        scanner.scan(/[^{]*/)
        success2, block2 = extractor.send(:extract_balanced_braces, scanner)
        
        expect(success2).to be true
        expect(block2).to eq("{ valid }")
      end

      it "handles scanner at end of string" do
        content = "{ code }"
        extractor = CExtractor.from_string(content: "", chunk_size: 10)
        scanner = StringScanner.new(content)
        
        # Extract the only block
        extractor.send(:extract_balanced_braces, scanner)
        
        # Try to extract again at end of string
        success, block = extractor.send(:extract_balanced_braces, scanner)
        
        expect(success).to be false
        expect(block).to be_nil
        expect(scanner.eos?).to be true
      end
    end

    context "performance considerations" do
      it "handles very long brace blocks" do
        # Create a large but balanced brace block
        inner_content = "int x = 0;\n" * 100
        content = "{\n#{inner_content}}"
        success, block, pos, rest = extract_braces.call(content)
        
        expect(success).to be true
        expect(block).to eq(content)
        expect(pos).to eq(content.length)
        expect(rest).to eq("")
      end

     it "handles deeply nested braces" do
        # Create 50 levels of nesting
        opening = "{ " * 50
        closing = " }" * 50
        content = opening + "core" + closing
        success, block, pos, rest = extract_braces.call(content)
        
        expect(success).to be true
        expect(block).to eq(content)
        expect(pos).to eq(content.length)
        expect(rest).to eq("")
      end

      it "handles many sequential brace blocks" do
        # Create 100 sequential blocks
        blocks = (1..100).map { |i| "{ block#{i} }" }.join(" ")
        extractor = CExtractor.from_string(content: "", chunk_size: 10)
        scanner = StringScanner.new(blocks)
        
        count = 0
        while !scanner.eos?
          scanner.scan(/\s*/)
          break if scanner.eos?
          success, _ = extractor.send(:extract_balanced_braces, scanner)
          break unless success
          count += 1
        end
        
        expect(count).to eq(100)
      end

      it "handles large strings within braces" do
        large_string = "x" * 1000
        content = "{ char* str = \"#{large_string}\"; }"
        success, block, pos, rest = extract_braces.call(content)
        
        expect(success).to be true
        expect(block).to eq(content)
        expect(pos).to eq(content.length)
        expect(rest).to eq("")
      end

      it "handles large comments within braces" do
        large_comment = "comment text " * 100
        content = "{ /* #{large_comment} */ code; }"
        success, block, pos, rest = extract_braces.call(content)
        
        expect(success).to be true
        expect(block).to eq(content)
        expect(pos).to eq(content.length)
        expect(rest).to eq("")
      end
    end
  end

  ###
  ### extract_function_signature()
  ###

  describe "#extract_function_signature (private method testing)" do
    # Helper to access private method
    let(:extract_signature) do
      ->(content) do
        extractor = CExtractor.from_string(content: "", chunk_size: 10)
        scanner = StringScanner.new(content)
        signature = extractor.send(:extract_function_signature, scanner)
        return [signature, scanner.pos, scanner.rest]
      end
    end

    context "simple function signatures" do
      it "extracts void function signature with void parameters" do
        content = "void foo(void){"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("void foo(void)")
        expect(pos).to eq(14)
        expect(rest).to eq("{")
      end

      it "extracts void function signature with no parameters" do
        content = "void foo(){"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("void foo()")
        expect(pos).to eq(10)
        expect(rest).to eq("{")
      end

      it "extracts void function signature with no parameters and brace after newline" do
        content = "void foo()\n{"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("void foo()")
        expect(pos).to eq(11)
        expect(rest).to eq("{")
      end

      it "extracts int function signature with no parameters and whitespace between signature and function body brace" do
        content = "int bar(void)    {"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("int bar(void)")
        expect(pos).to eq(17)
        expect(rest).to eq("{")
      end

      it "extracts signature followed by line comment" do
        content = "void foo(void) // comment\n{"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("void foo(void)")
        expect(pos).to eq(26)
        expect(rest).to eq("{")
      end
      
      it "extracts function signature with single parameter and comment between signature and function body brace" do
        content = "int add(int x)/* */{ int a;"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("int add(int x)")
        expect(pos).to eq(19)
        expect(rest).to eq("{ int a;")
      end

      it "extracts function signature with multiple parameters" do
        content = "int multiply(int a, int b){"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("int multiply(int a, int b)")
        expect(pos).to eq(26)
        expect(rest).to eq("{")
      end

      it "extracts function signature returning pointer" do
        content = "char* getString(void){"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("char* getString(void)")
        expect(pos).to eq(21)
        expect(rest).to eq("{")
      end

      it "extracts function signature with pointer parameter" do
        content = "void process(int* ptr){"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("void process(int* ptr)")
        expect(pos).to eq(22)
        expect(rest).to eq("{")
      end

      it "does not extract signature from declaration" do
        content = "void process(int* ptr);"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq(nil)
        expect(pos).to eq(23)
        expect(rest).to eq("")
      end

      it "does not extract signature from declaration with whitespace" do
        content = "void process(int* ptr)     ;"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq(nil)
        expect(pos).to eq(28)
        expect(rest).to eq("")
      end

      it "does not extract signature from declaration with comment" do
        content = "void process(int* ptr)/***/;"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq(nil)
        expect(pos).to eq(28)
        expect(rest).to eq("")
      end

      it "does not extract signature from declaration with newline" do
        content = "void process(int* ptr)\n;"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq(nil)
        expect(pos).to eq(24)
        expect(rest).to eq("")
      end
    end

    context "function signatures with whitespace variations" do
      it "extracts signature with extra spaces" do
        content = "int    foo   (  int   x  ){"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("int foo ( int x )")
        expect(pos).to eq(26)
        expect(rest).to eq("{")
      end

      it "extracts clean signature from one with tabs" do
        content = "int\tfoo\t(\tint\tx\t){"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("int foo ( int x )")
        expect(pos).to eq(17)
        expect(rest).to eq("{")
      end

      it "extracts clean signature from one with newlines" do
        content = "int\nfoo\n(\nint x\n){"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("int foo ( int x )")
        expect(pos).to eq(17)
        expect(rest).to eq("{")
      end

      it "extracts clean signature from one with mixed whitespace" do
        content = "int \t\n foo \t\n ( \t\n int x \t\n ){"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("int foo ( int x )")
        expect(pos).to eq(29)
        expect(rest).to eq("{")
      end
    end

    context "complex return types" do
      it "extracts function returning struct" do
        content = "struct point getPoint(void){"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("struct point getPoint(void)")
        expect(pos).to eq(27)
        expect(rest).to eq("{")
      end

      it "extracts function returning pointer to struct" do
        content = "struct node* getNode(void){"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("struct node* getNode(void)")
        expect(pos).to eq(26)
        expect(rest).to eq("{")
      end

      it "extracts function returning const pointer" do
        content = "const char* getMessage(void){"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("const char* getMessage(void)")
        expect(pos).to eq(28)
        expect(rest).to eq("{")
      end

      it "extracts function returning pointer to const" do
        content = "char* const getBuffer(void){"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("char* const getBuffer(void)")
        expect(pos).to eq(27)
        expect(rest).to eq("{")
      end

      it "extracts function returning unsigned type" do
        content = "unsigned int getValue(void){"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("unsigned int getValue(void)")
        expect(pos).to eq(27)
        expect(rest).to eq("{")
      end

      it "extracts function returning long long" do
        content = "long long getBigValue(void){"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("long long getBigValue(void)")
        expect(pos).to eq(27)
        expect(rest).to eq("{")
      end

      it "extracts function returning enum" do
        content = "enum status getStatus(void){"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("enum status getStatus(void)")
        expect(pos).to eq(27)
        expect(rest).to eq("{")
      end

      it "extracts function returning typedef'd type" do
        content = "size_t getSize(void){"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("size_t getSize(void)")
        expect(pos).to eq(20)
        expect(rest).to eq("{")
      end

      it "extracts function returning double pointer" do
        content = "char** getStringArray(void){"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("char** getStringArray(void)")
        expect(pos).to eq(27)
        expect(rest).to eq("{")
      end
    end

    context "complex parameter types" do
      it "extracts function with array parameter" do
        content = "void process(int arr[]){"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("void process(int arr[])")
        expect(pos).to eq(23)
        expect(rest).to eq("{")
      end

      it "extracts function with sized array parameter" do
        content = "void process(int arr[10]){"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("void process(int arr[10])")
        expect(pos).to eq(25)
        expect(rest).to eq("{")
      end

      it "extracts function with const parameter" do
        content = "void print(const char* str){"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("void print(const char* str)")
        expect(pos).to eq(27)
        expect(rest).to eq("{")
      end

      it "extracts function with struct parameter" do
        content = "void update(struct data d){"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("void update(struct data d)")
        expect(pos).to eq(26)
        expect(rest).to eq("{")
      end

      it "extracts function with pointer to struct parameter" do
        content = "void modify(struct node* n){"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("void modify(struct node* n)")
        expect(pos).to eq(27)
        expect(rest).to eq("{")
      end

      it "extracts function with multiple complex parameters" do
        content = "int compare(const char* s1, const char* s2, size_t len){"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("int compare(const char* s1, const char* s2, size_t len)")
        expect(pos).to eq(55)
        expect(rest).to eq("{")
      end

      it "extracts function with function pointer parameter" do
        content = "void callback(void (*func)(int)){"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("void callback(void (*func)(int))")
        expect(pos).to eq(32)
        expect(rest).to eq("{")
      end

      it "extracts function with complex function pointer parameter" do
        content = "void register(int (*compare)(const void*, const void*)){"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("void register(int (*compare)(const void*, const void*))")
        expect(pos).to eq(55)
        expect(rest).to eq("{")
      end

      it "extracts function with double pointer parameter" do
        content = "void allocate(char** buffer){"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("void allocate(char** buffer)")
        expect(pos).to eq(28)
        expect(rest).to eq("{")
      end

      it "extracts function with enum parameter" do
        content = "void setState(enum state s){"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("void setState(enum state s)")
        expect(pos).to eq(27)
        expect(rest).to eq("{")
      end
    end

    context "function signatures with storage class specifiers" do
      it "extracts static function" do
        content = "static int helper(void){"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("static int helper(void)")
        expect(pos).to eq(23)
        expect(rest).to eq("{")
      end

      it "extracts inline function" do
        content = "inline int fast(void){"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("inline int fast(void)")
        expect(pos).to eq(21)
        expect(rest).to eq("{")
      end

      it "extracts extern function" do
        content = "extern void external(void){"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("extern void external(void)")
        expect(pos).to eq(26)
        expect(rest).to eq("{")
      end

      it "extracts static inline function" do
        content = "static inline int optimize(void){"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("static inline int optimize(void)")
        expect(pos).to eq(32)
        expect(rest).to eq("{")
      end
    end

    context "function signatures with qualifiers" do
      it "extracts function with const qualifier" do
        content = "const int getValue(void){"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("const int getValue(void)")
        expect(pos).to eq(24)
        expect(rest).to eq("{")
      end

      it "extracts function with volatile qualifier" do
        content = "volatile int getRegister(void){"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("volatile int getRegister(void)")
        expect(pos).to eq(30)
        expect(rest).to eq("{")
      end

      it "extracts function with restrict qualifier" do
        content = "void copy(char* restrict dest, const char* restrict src){"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("void copy(char* restrict dest, const char* restrict src)")
        expect(pos).to eq(56)
        expect(rest).to eq("{")
      end

      it "extracts function with multiple qualifiers" do
        content = "static const volatile int getSpecial(void){"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("static const volatile int getSpecial(void)")
        expect(pos).to eq(42)
        expect(rest).to eq("{")
      end
    end

    context "function signatures with variadic parameters" do
      it "extracts function with variadic parameters" do
        content = "int printf(const char* format, ...){"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("int printf(const char* format, ...)")
        expect(pos).to eq(35)
        expect(rest).to eq("{")
      end

      it "extracts function with only variadic parameters" do
        content = "void log(...){"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("void log(...)")
        expect(pos).to eq(13)
        expect(rest).to eq("{")
      end

      it "extracts function with multiple parameters and variadic" do
        content = "int sprintf(char* buffer, const char* format, ...){"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("int sprintf(char* buffer, const char* format, ...)")
        expect(pos).to eq(50)
        expect(rest).to eq("{")
      end
    end

    context "function signatures with nested parentheses" do
      it "extracts signature with function pointer return type" do
        content = "int (*getFunction(void))(int, int){"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("int (*getFunction(void))(int, int)")
        expect(pos).to eq(34)
        expect(rest).to eq("{")
      end

      it "extracts signature with complex function pointer parameter" do
        content = "void sort(int* array, int (*compare)(int, int)){"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("void sort(int* array, int (*compare)(int, int))")
        expect(pos).to eq(47)
        expect(rest).to eq("{")
      end

      it "extracts signature with multiple function pointer parameters" do
        content = "void process(void (*init)(void), void (*cleanup)(void)){"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("void process(void (*init)(void), void (*cleanup)(void))")
        expect(pos).to eq(55)
        expect(rest).to eq("{")
      end

      it "extracts signature with nested function pointers" do
        content = "void register(void (*callback)(int (*)(void))){"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("void register(void (*callback)(int (*)(void)))")
        expect(pos).to eq(46)
        expect(rest).to eq("{")
      end

      it "extracts signature with array of function pointers" do
        content = "void dispatch(void (*handlers[])(int)){"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("void dispatch(void (*handlers[])(int))")
        expect(pos).to eq(38)
        expect(rest).to eq("{")
      end
    end

    context "function signatures with strings and comments" do
      it "extracts signature with string in default parameter (C++ style, but testing robustness)" do
        content = 'void log(const char* msg = "default"){'
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq('void log(const char* msg = "default")')
        expect(pos).to eq(37)
        expect(rest).to eq("{")
      end

      it "extracts signature with parentheses in string" do
        content = 'void print(const char* format = "value: (%d)"){'
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq('void print(const char* format = "value: (%d)")')
        expect(pos).to eq(46)
        expect(rest).to eq("{")
      end

      it "extracts signature with character literal containing parenthesis" do
        content = "void process(char c = ')'){"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("void process(char c = ')')")
        expect(pos).to eq(26)
        expect(rest).to eq("{")
      end
    end

    context "edge cases and boundary conditions" do
      it "extracts very long signature" do
        params = (1..50).map { |i| "int param#{i}" }.join(", ")
        content = "void longFunction(#{params})"
        signature, pos, rest = extract_signature.call(content + '{}')
        
        expect(signature).to eq(content)
        expect(pos).to eq(content.length)
        expect(rest).to eq("{}")
      end

      it "extracts signature with deeply nested parentheses" do
        content = "void complex(int (*(*(*f)(int))(int))(int)){"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("void complex(int (*(*(*f)(int))(int))(int))")
        expect(pos).to eq(43)
        expect(rest).to eq("{")
      end
    end

    context "real-world C function patterns" do
      it "extracts main function signature" do
        content = "int main(int argc, char* argv[]){"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("int main(int argc, char* argv[])")
        expect(pos).to eq(32)
        expect(rest).to eq("{")
      end

      it "extracts signal handler signature" do
        content = "void signal_handler(int signum){"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("void signal_handler(int signum)")
        expect(pos).to eq(31)
        expect(rest).to eq("{")
      end

      it "extracts qsort compare function signature" do
        content = "int compare(const void* a, const void* b){"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("int compare(const void* a, const void* b)")
        expect(pos).to eq(41)
        expect(rest).to eq("{")
      end

      it "extracts pthread function signature" do
        content = "void* thread_function(void* arg){"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("void* thread_function(void* arg)")
        expect(pos).to eq(32)
        expect(rest).to eq("{")
      end

      it "extracts interrupt handler signature" do
        content = "void __attribute__((interrupt)) ISR_Handler(void){"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq("void __attribute__((interrupt)) ISR_Handler(void)")
        expect(pos).to eq(49)
        expect(rest).to eq("{")
      end
    end
  end

end