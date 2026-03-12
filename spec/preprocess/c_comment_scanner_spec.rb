# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/preprocess/c_comment_scanner'

RSpec.describe CCommentScanner do

  subject(:scanner) { CCommentScanner.new }

  # ---------------------------------------------------------------------------
  # Helper: extract the matched text for every CommentInfo in content
  # ---------------------------------------------------------------------------
  def comment_texts(content, infos)
    infos.map { |info| content[info.position, info.length] }
  end


  # ===========================================================================
  describe '#scan_string' do
  # ===========================================================================

    # -------------------------------------------------------------------------
    context 'with empty or comment-free content' do
    # -------------------------------------------------------------------------

      it 'returns empty array for an empty string' do
        expect(scanner.scan_string('')).to eq([])
      end

      it 'returns empty array for realistic C code that contains no comments' do
        content = <<~C
          #include <stdint.h>
          #include <stdbool.h>

          typedef struct {
            uint32_t count;
            uint8_t  data[16];
          } Buffer;

          static int  buffer_init(Buffer *b, uint32_t size);
          static bool buffer_full(const Buffer *b);
          static void buffer_clear(Buffer *b);
        C
        expect(scanner.scan_string(content)).to eq([])
      end

    end


    # -------------------------------------------------------------------------
    context 'with // single-line comments' do
    # -------------------------------------------------------------------------

      it 'finds an inline // comment and reports correct position, length, and lines_removed' do
        content = "int x = 5; // assign x\nint y = 6;\n"
        infos   = scanner.scan_string(content)

        expect(infos.length).to eq(1)
        expect(infos[0].position).to eq(11)
        expect(content[infos[0].position, infos[0].length]).to eq('// assign x')
        expect(infos[0].lines_removed).to eq(0)
      end

      it 'finds a // comment that extends to end of file with no trailing newline' do
        content = "int x = 5; // eof comment"
        infos   = scanner.scan_string(content)

        expect(infos.length).to eq(1)
        expect(content[infos[0].position, infos[0].length]).to eq('// eof comment')
        expect(infos[0].lines_removed).to eq(0)
      end

      it 'does not consume the terminating newline of a // comment' do
        content = "// comment\nint x;\n"
        infos   = scanner.scan_string(content)

        expect(infos.length).to eq(1)
        # The \n at position 10 must remain available; only the comment is captured
        expect(content[infos[0].position, infos[0].length]).to eq('// comment')
        expect(infos[0].lines_removed).to eq(0)
      end

      it 'handles a backslash continuation (no trailing whitespace) spanning one extra line' do
        # A backslash immediately before the newline continues the line comment.
        content = "// first line \\\nsecond line still comment\nint x;\n"
        infos   = scanner.scan_string(content)

        expect(infos.length).to eq(1)
        expect(content[infos[0].position, infos[0].length]).to eq("// first line \\\nsecond line still comment")
        expect(infos[0].lines_removed).to eq(1)
      end

      it 'handles a backslash continuation with trailing spaces between backslash and newline' do
        # GCC accepts (with a warning) whitespace between the \ and the newline.
        content = "// first line \\   \nsecond line still comment\nint x;\n"
        infos   = scanner.scan_string(content)

        expect(infos.length).to eq(1)
        expect(content[infos[0].position, infos[0].length]).to eq("// first line \\   \nsecond line still comment")
        expect(infos[0].lines_removed).to eq(1)
      end

      it 'handles a backslash continuation with trailing tabs between backslash and newline' do
        # \\\t\t\n in the Ruby string literal: one backslash, two tabs, then a newline.
        # The scanner must treat \<TAB><TAB><NEWLINE> as a continuation sequence.
        content = "// comment\\\t\t\ncontinuation\ncode;\n"
        infos   = scanner.scan_string(content)

        expect(infos.length).to eq(1)
        expect(content[infos[0].position, infos[0].length]).to eq("// comment\\\t\t\ncontinuation")
        expect(infos[0].lines_removed).to eq(1)
      end

      it 'handles a // comment with multiple continuation lines' do
        content = "// line one \\\nline two \\\nline three\ncode;\n"
        infos   = scanner.scan_string(content)

        expect(infos.length).to eq(1)
        expect(content[infos[0].position, infos[0].length]).to eq("// line one \\\nline two \\\nline three")
        expect(infos[0].lines_removed).to eq(2)
      end

    end


    # -------------------------------------------------------------------------
    context 'with /* */ block comments' do
    # -------------------------------------------------------------------------

      it 'finds an inline /* */ comment on a single line with lines_removed = 0' do
        content = "int x = /* the value */ 5;\n"
        infos   = scanner.scan_string(content)

        expect(infos.length).to eq(1)
        expect(content[infos[0].position, infos[0].length]).to eq('/* the value */')
        expect(infos[0].lines_removed).to eq(0)
      end

      it 'finds a multi-line /* */ block comment with correct lines_removed' do
        content = <<~C
          /*
           * Module: sensor
           * Version: 2.1
           */
          #include <stdint.h>
        C
        infos = scanner.scan_string(content)

        expect(infos.length).to eq(1)
        expect(infos[0].position).to eq(0)
        expect(content[infos[0].position, infos[0].length]).to eq("/*\n * Module: sensor\n * Version: 2.1\n */")
        expect(infos[0].lines_removed).to eq(3)
      end

      it 'records an unterminated /* comment that extends to EOF' do
        content = "int x = 5;\n/* unterminated block\nstill in comment\n"
        infos   = scanner.scan_string(content)

        expect(infos.length).to eq(1)
        expect(content[infos[0].position, infos[0].length]).to eq("/* unterminated block\nstill in comment\n")
        expect(infos[0].lines_removed).to eq(2)
      end

      it 'treats // sequences inside /* */ as non-special (not a nested comment)' do
        content = "/* block with // inside\nstill block */\ncode;\n"
        infos   = scanner.scan_string(content)

        expect(infos.length).to eq(1)
        expect(content[infos[0].position, infos[0].length]).to eq("/* block with // inside\nstill block */")
        expect(infos[0].lines_removed).to eq(1)
      end

    end


    # -------------------------------------------------------------------------
    context 'with string and character literals' do
    # -------------------------------------------------------------------------

      it 'does not detect // inside a double-quoted string literal as a comment' do
        content = "const char *s = \"http://example.com\";\n"
        infos   = scanner.scan_string(content)
        expect(infos).to be_empty
      end

      it 'does not detect /* */ inside a double-quoted string literal as a comment' do
        content = "const char *msg = \"/* not a comment */\";\n"
        infos   = scanner.scan_string(content)
        expect(infos).to be_empty
      end

      it 'does not detect // inside a single-quoted character literal as a comment' do
        content = "char a = '/';\nchar b = '/';\n// real comment\n"
        infos   = scanner.scan_string(content)

        expect(infos.length).to eq(1)
        expect(content[infos[0].position, infos[0].length]).to eq('// real comment')
      end

      it 'handles an escaped quote inside a string literal before a real comment' do
        # The \" inside the string must not prematurely close the literal.
        content = "char *s = \"he said \\\"hi\\\"\";\n// real comment\n"
        infos   = scanner.scan_string(content)

        expect(infos.length).to eq(1)
        expect(content[infos[0].position, infos[0].length]).to eq('// real comment')
      end

    end


    # -------------------------------------------------------------------------
    context 'with comment interaction edge cases' do
    # -------------------------------------------------------------------------

      it 'does not treat /* appearing after // as a block comment start' do
        content = "// line comment /* not a block\ncode;\n"
        infos   = scanner.scan_string(content)

        expect(infos.length).to eq(1)
        expect(content[infos[0].position, infos[0].length]).to eq('// line comment /* not a block')
        expect(infos[0].lines_removed).to eq(0)
      end

      it 'finds two adjacent comments with no code between them' do
        content = "/* block *//* another block */\ncode;\n"
        infos   = scanner.scan_string(content)

        expect(infos.length).to eq(2)
        expect(content[infos[0].position, infos[0].length]).to eq('/* block */')
        expect(content[infos[1].position, infos[1].length]).to eq('/* another block */')
      end

      it 'finds all comments in realistic mixed-comment C code in correct order' do
        content = <<~C
          /* Module header */
          #include <stdint.h> // Standard integer types

          typedef struct { // The buffer type
            uint32_t count; /* Element count */
            uint8_t  data[16];
          } Buffer;
        C
        infos = scanner.scan_string(content)

        expect(infos.length).to eq(4)
        expect(infos.map(&:lines_removed)).to all(eq(0))
        expect(comment_texts(content, infos)).to eq([
          '/* Module header */',
          '// Standard integer types',
          '// The buffer type',
          '/* Element count */'
        ])
      end

      it 'finds all comments in realistic GCC preprocessor output with line markers' do
        content = <<~PREPROCESSED
          # 1 "sensor.c"
          /* Sensor driver */
          # 3 "sensor.c"
          #define SENSOR_MAX 16 // hardware maximum
          # 4 "sensor.c"
          #define SCALE_FACTOR 0.001f /* mV per LSB */
        PREPROCESSED
        infos = scanner.scan_string(content)

        expect(infos.length).to eq(3)
        expect(comment_texts(content, infos)).to eq([
          '/* Sensor driver */',
          '// hardware maximum',
          '/* mV per LSB */'
        ])
        expect(infos[0].lines_removed).to eq(0)
        expect(infos[1].lines_removed).to eq(0)
        expect(infos[2].lines_removed).to eq(0)
      end

      it 'returns comments in ascending byte position order' do
        content = "/* first */ code; /* second */\nmore; // third\n"
        infos   = scanner.scan_string(content)

        expect(infos.length).to eq(3)
        positions = infos.map(&:position)
        expect(positions).to eq(positions.sort)
      end

    end

  end


  # ===========================================================================
  describe '#remove' do
  # ===========================================================================

    it 'replaces each comment with a single space and leaves all other content intact' do
      content = "int x = 5; // inline comment\nint y = /* value */ 6;\n"
      infos   = scanner.scan_string(content)
      result  = scanner.remove(content, infos)

      expect(result).to eq("int x = 5;  \nint y =   6;\n")
    end

    it 'preserves the original string (returns a modified copy)' do
      content  = "/* comment */ code;\n"
      original = content.dup
      infos    = scanner.scan_string(content)
      scanner.remove(content, infos)

      expect(content).to eq(original)
    end

    it 'returns the original content unchanged when comment_infos is empty' do
      content = "int x = 5;\n"
      result  = scanner.remove(content, [])
      expect(result).to eq(content)
    end

    it 'removes a multi-line block comment (replacing with space reduces newline count)' do
      content = "before\n/* multi\nline\ncomment */\nafter"
      infos   = scanner.scan_string(content)
      result  = scanner.remove(content, infos)

      original_lines = content.count("\n")
      result_lines   = result.count("\n")
      expect(original_lines - result_lines).to eq(infos[0].lines_removed)
      expect(result).to eq("before\n \nafter")
    end

    it 'correctly strips comments from realistic mixed C code' do
      content = <<~C
        /* File: sensor.c
         * Author: firmware team
         */
        #include <stdint.h> // integer types

        static uint32_t read_raw(uint8_t ch) /* channel 0-15 */ {
          return ch * 256; // placeholder
        }
      C
      infos  = scanner.scan_string(content)
      result = scanner.remove(content, infos)

      # No comment delimiters should remain
      expect(result).not_to include('//')
      expect(result).not_to include('/*')
      expect(result).not_to include('*/')
      # Structure keywords must still be present
      expect(result).to include('#include')
      expect(result).to include('static uint32_t read_raw')
      expect(result).to include('return ch * 256;')
    end

    it 'lines_removed equals exactly the newlines eliminated by replace-with-space' do
      content = <<~C
        /* header comment
           spanning four
           physical lines
        */
        void foo(void) {}
      C
      infos = scanner.scan_string(content)

      expect(infos.length).to eq(1)
      result         = scanner.remove(content, infos)
      lines_before   = content.count("\n")
      lines_after    = result.count("\n")

      expect(lines_before - lines_after).to eq(infos[0].lines_removed)
    end

  end

end
