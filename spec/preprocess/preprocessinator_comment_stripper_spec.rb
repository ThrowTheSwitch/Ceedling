# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/preprocess/c_comment_scanner'
require 'ceedling/preprocess/preprocessinator_comment_stripper'
require 'ceedling/preprocess/preprocessinator_code_finder'

RSpec.describe PreprocessinatorCommentStripper do

  before(:each) do
    @stripper = PreprocessinatorCommentStripper.new(
      {
        c_comment_scanner: CCommentScanner.new
      }
    )

    # PreprocessinatorCodeFinder is used to verify that stripped output preserves
    # correct source-line mapping via the marker-relative arithmetic it implements.
    @finder = PreprocessinatorCodeFinder.new
  end


  # ===========================================================================
  describe '#strip_string' do
  # ===========================================================================

    # -------------------------------------------------------------------------
    context 'with comment-free preprocessor output' do
    # -------------------------------------------------------------------------

      it 'returns content unchanged when there are no comments' do
        content = <<~PREPROCESSED
          # 1 "module.c"
          #define MODULE_H
          # 2 "module.c"
          #define MAX_SIZE 256
          # 3 "module.c"
          #include "types.h"
        PREPROCESSED

        result = @stripper.strip_string(content)
        expect(result).to eq(content)
      end

    end


    # -------------------------------------------------------------------------
    context 'with single-line // comments' do
    # -------------------------------------------------------------------------

      it 'replaces inline // comments with spaces and leaves markers and directives intact' do
        content = <<~PREPROCESSED
          # 1 "module.c"
          #define FOO 1 // enable feature
          # 2 "module.c"
          #define BAR 2 // another setting
          # 3 "module.c"
          #define BAZ 3
        PREPROCESSED

        result = @stripper.strip_string(content)

        # Comments replaced with spaces
        expect(result).not_to include('//')
        # Directives and markers intact
        expect(result).to include('# 1 "module.c"')
        expect(result).to include('#define FOO 1')
        expect(result).to include('#define BAR 2')
        expect(result).to include('# 3 "module.c"')
        expect(result).to include('#define BAZ 3')
        # Marker count unchanged
        expect(result.scan(/^#\s+\d+\s+"[^"]+"/).length).to eq(
          content.scan(/^#\s+\d+\s+"[^"]+"/).length
        )
      end

    end


    # -------------------------------------------------------------------------
    context 'with multi-line /* */ comments' do
    # -------------------------------------------------------------------------

      it 'replaces a multi-line block comment with blank lines and leaves markers unchanged' do
        content = <<~PREPROCESSED
          # 1 "sensor.c"
          /*
           * Sensor module
           * Platform: RTOS
           */
          #define SENSOR_H
          # 7 "sensor.c"
          #define MAX_CHANNELS 16
        PREPROCESSED

        result = @stripper.strip_string(content)

        expect(result).not_to include('/*')
        expect(result).not_to include('*/')
        # The # 7 "sensor.c" marker is left unchanged (blank-line replacement preserves line count)
        expect(result).to include('# 7 "sensor.c"')
        expect(result).to include('#define SENSOR_H')
        expect(result).to include('#define MAX_CHANNELS 16')
      end

      it 'preserves source line numbers via blank-line replacement so code finder is correct' do
        # Comment /*...*/ spans source lines 1-4 (3 internal newlines → lines_removed=3).
        # Replaced by \n\n\n, preserving line count.  # 7 "sensor.c" is unchanged.
        # Code finder: # 1 + 4 newlines (\n\n\n replacement + original \n after */) = 5.
        # MAX_CHANNELS: unchanged # 7 + 0 newlines = 7.
        content = <<~PREPROCESSED
          # 1 "sensor.c"
          /*
           * Sensor module
           * Platform: RTOS
           */
          #define SENSOR_H
          # 7 "sensor.c"
          #define MAX_CHANNELS 16
        PREPROCESSED

        result = @stripper.strip_string(content)

        # Verify source-line mapping via PreprocessinatorCodeFinder round-trip.
        # #define SENSOR_H: marker # 1 + 4 newlines = line 5.
        expect(@finder.find_in_preprpocessed_string(result, '#define SENSOR_H')).to eq(5)
        # #define MAX_CHANNELS 16: unchanged marker # 7 + 0 newlines = line 7.
        expect(@finder.find_in_preprpocessed_string(result, '#define MAX_CHANNELS 16')).to eq(7)
      end

      it 'handles a large realistic module header with multi-line block comment' do
        content = <<~PREPROCESSED
          # 1 "buffer.h"
          /*
           * buffer.h -- Ring buffer implementation
           *
           * Copyright (c) 2025 ThrowTheSwitch
           * SPDX-License-Identifier: MIT
           */
          # 8 "buffer.h"
          #ifndef BUFFER_H
          # 9 "buffer.h"
          #define BUFFER_H
          # 10 "buffer.h"
          #define BUFFER_MAX_SIZE 512 /* hardware constraint */
          # 11 "buffer.h"
          typedef struct {
          # 12 "buffer.h"
          } Buffer;
          # 13 "buffer.h"
          void buffer_init(Buffer *b); // Initialize buffer
          # 14 "buffer.h"
          #endif
        PREPROCESSED

        result = @stripper.strip_string(content)

        # All comments stripped
        expect(result).not_to include('//')
        expect(result).not_to include('/*')
        expect(result).not_to include('*/')

        # Source-line mapping must be correct via round-trip.
        # The 6-line header comment (lines_removed=5) is replaced by \n\n\n\n\n.
        # All markers # 8 through # 14 are unchanged.
        # Each # N "file" marker is immediately followed by its directive (0 newlines),
        # so code finder returns N+0=N for each.
        expect(@finder.find_in_preprpocessed_string(result, '#ifndef BUFFER_H')).to eq(8)
        expect(@finder.find_in_preprpocessed_string(result, '#define BUFFER_H')).to eq(9)
        expect(@finder.find_in_preprpocessed_string(result, '#define BUFFER_MAX_SIZE 512')).to eq(10)
        expect(@finder.find_in_preprpocessed_string(result, 'void buffer_init(Buffer *b);')).to eq(13)
      end

      it 'replaces multiple multi-line comments with blank lines preserving line markers' do
        content = <<~PREPROCESSED
          # 1 "multi.c"
          /* first comment
             two lines */
          #define FIRST 1
          # 5 "multi.c"
          /* second comment
             also two lines */
          #define SECOND 2
          # 9 "multi.c"
          #define THIRD 3
        PREPROCESSED

        result = @stripper.strip_string(content)

        # Both comments stripped
        expect(result).not_to include('/*')
        expect(result).not_to include('*/')

        # All markers unchanged.
        expect(result).to include('# 5 "multi.c"')
        expect(result).to include('# 9 "multi.c"')

        # Source-line mapping via round-trip for all three defines.
        # Each comment (lines_removed=1) is replaced by \n, preserving line count.
        # FIRST: # 1 + 2 newlines (\n replacement + original \n after */) = 3.
        # SECOND: # 5 + 2 newlines = 7.
        # THIRD: # 9 + 0 newlines = 9.
        expect(@finder.find_in_preprpocessed_string(result, '#define FIRST 1')).to eq(3)
        expect(@finder.find_in_preprpocessed_string(result, '#define SECOND 2')).to eq(7)
        expect(@finder.find_in_preprpocessed_string(result, '#define THIRD 3')).to eq(9)
      end

      it 'replaces a multi-line comment before any line marker with equivalent blank lines' do
        content = <<~PREPROCESSED
          /* file header spanning
             two lines */
          # 3 "foo.c"
          #define FOO 1
        PREPROCESSED

        result = @stripper.strip_string(content)
        expect(result).not_to include('/*')
        # Marker unchanged; code finder: # 3 + 0 newlines = 3.
        expect(result).to include('# 3 "foo.c"')
        expect(@finder.find_in_preprpocessed_string(result, '#define FOO 1')).to eq(3)
      end

      it 'handles an inline single-line /* */ block comment without changing markers' do
        content = <<~PREPROCESSED
          # 1 "opts.c"
          #define TIMEOUT 100 /* milliseconds */
          # 2 "opts.c"
          #define RETRIES 3
        PREPROCESSED

        result = @stripper.strip_string(content)

        expect(result).not_to include('/*')
        # Marker count unchanged
        expect(result.scan(/^#\s+\d+\s+"[^"]+"/).length).to eq(
          content.scan(/^#\s+\d+\s+"[^"]+"/).length
        )
        # Content correct
        expect(result).to include('#define TIMEOUT 100')
        expect(result).to include('#define RETRIES 3')
      end

    end


    # -------------------------------------------------------------------------
    context 'with C code preceding multi-line comments' do
    # -------------------------------------------------------------------------

      it 'maps code before a comment and code after when no subsequent marker exists' do
        # Pattern: marker → code → multi-line comment → more code (no following marker).
        # Comment (lines_removed=1) replaced by \n; line count preserved; no markers change.
        content = <<~PREPROCESSED
          # 1 "calc.c"
          int result = 0;
          /* initial
             value */
          result += 1;
        PREPROCESSED

        result = @stripper.strip_string(content)

        expect(result).not_to include('/*')
        # int result = 0: marker # 1 + 0 newlines = 1.
        # result += 1: marker # 1 + 3 newlines (code \n + \n replacement + original \n after */) = 4.
        expect(@finder.find_in_preprpocessed_string(result, 'int result = 0;')).to eq(1)
        expect(@finder.find_in_preprpocessed_string(result, 'result += 1;')).to eq(4)
      end

      it 'maps code before a comment and code after when a subsequent marker exists' do
        # Pattern: marker → code → multi-line comment → more code → marker → code.
        # Subsequent marker is unchanged; code after comment maps to original source line.
        content = <<~PREPROCESSED
          # 1 "calc.c"
          int result = 0;
          /* initial
             value */
          result += 1;
          # 6 "calc.c"
          return result;
        PREPROCESSED

        result = @stripper.strip_string(content)

        expect(result).not_to include('/*')
        # int result = 0: marker # 1 + 0 newlines = 1.
        # result += 1: marker # 1 + 3 newlines = 4 (original source line 4).
        # return result: unchanged marker # 6 + 0 newlines = 6.
        expect(@finder.find_in_preprpocessed_string(result, 'int result = 0;')).to eq(1)
        expect(@finder.find_in_preprpocessed_string(result, 'result += 1;')).to eq(4)
        expect(@finder.find_in_preprpocessed_string(result, 'return result;')).to eq(6)
      end

      it 'maps multiple code lines before a comment and code after' do
        # Pattern: marker → several code lines → multi-line comment → code → marker → code.
        # Blank-line replacement preserves newline count; subsequent marker unchanged.
        content = <<~PREPROCESSED
          # 1 "gpio.c"
          void gpio_init(void) {
          int port = 0;
          /* configure
             port
             registers */
          port = GPIO_BASE;
          # 8 "gpio.c"
          gpio_write(port);
        PREPROCESSED

        result = @stripper.strip_string(content)

        expect(result).not_to include('/*')
        # void gpio_init: marker # 1 + 0 = 1.
        # int port = 0:   marker # 1 + 1 newline = 2.
        # port = GPIO_BASE: marker # 1 + 5 newlines (void, int port, \n\n replacement, original \n) = 6.
        # gpio_write: unchanged marker # 8 + 0 = 8.
        expect(@finder.find_in_preprpocessed_string(result, 'void gpio_init(void) {')).to eq(1)
        expect(@finder.find_in_preprpocessed_string(result, 'int port = 0;')).to eq(2)
        expect(@finder.find_in_preprpocessed_string(result, 'port = GPIO_BASE;')).to eq(6)
        expect(@finder.find_in_preprpocessed_string(result, 'gpio_write(port);')).to eq(8)
      end

      it 'maps code correctly when blank lines surround a comment within code' do
        # Blank lines before and after the comment remain in the output as-is;
        # the comment is replaced by equivalent newlines, preserving the total line count.
        content = <<~PREPROCESSED
          # 1 "sensor.c"
          uint8_t data;

          /* multi
             line
             comment */

          uint32_t result;
          # 9 "sensor.c"
          process(result);
        PREPROCESSED

        result = @stripper.strip_string(content)

        expect(result).not_to include('/*')
        # uint8_t data: marker # 1 + 0 = 1.
        # uint32_t result: marker # 1 + 6 newlines
        #   (data \n, blank \n, \n\n replacement, original \n after */, blank \n) = 7.
        # process: unchanged marker # 9 + 0 = 9.
        expect(@finder.find_in_preprpocessed_string(result, 'uint8_t data;')).to eq(1)
        expect(@finder.find_in_preprpocessed_string(result, 'uint32_t result;')).to eq(7)
        expect(@finder.find_in_preprpocessed_string(result, 'process(result);')).to eq(9)
      end

      it 'accumulates correct newline count for two comments under the same marker' do
        # Two multi-line comments follow code under # 1 with no intermediate marker.
        # Each comment (lines_removed=1) is replaced by \n; total line count preserved.
        content = <<~PREPROCESSED
          # 1 "shared.c"
          int x = 0;
          /* first
             comment */
          int y = 0;
          /* second
             comment */
          int z = 0;
          # 9 "shared.c"
          int w = 0;
        PREPROCESSED

        result = @stripper.strip_string(content)

        expect(result).not_to include('/*')
        # int x: marker # 1 + 0 = 1.
        # int y: marker # 1 + 3 newlines (x \n, \n replacement, original \n) = 4.
        # int z: marker # 1 + 6 newlines (x, repl, orig, y \n, repl, orig) = 7.
        # int w: unchanged marker # 9 + 0 = 9.
        expect(@finder.find_in_preprpocessed_string(result, 'int x = 0;')).to eq(1)
        expect(@finder.find_in_preprpocessed_string(result, 'int y = 0;')).to eq(4)
        expect(@finder.find_in_preprpocessed_string(result, 'int z = 0;')).to eq(7)
        expect(@finder.find_in_preprpocessed_string(result, 'int w = 0;')).to eq(9)
      end

      it 'handles // and /* */ comments interleaved with code under the same marker' do
        # Single-line // comments → space replacement (line count unchanged).
        # Multi-line block comment → blank-line replacement (line count unchanged).
        # All markers preserved as-is.
        content = <<~PREPROCESSED
          # 1 "mixed.c"
          int x; // x value
          /* two
             lines */
          int y; // y value
          # 6 "mixed.c"
          int z;
        PREPROCESSED

        result = @stripper.strip_string(content)

        expect(result).not_to include('//')
        expect(result).not_to include('/*')
        # int x: marker # 1 + 0 = 1.
        # int y: marker # 1 + 3 newlines (x-line \n, \n replacement, original \n) = 4.
        # int z: unchanged marker # 6 + 0 = 6.
        expect(@finder.find_in_preprpocessed_string(result, 'int x;')).to eq(1)
        expect(@finder.find_in_preprpocessed_string(result, 'int y;')).to eq(4)
        expect(@finder.find_in_preprpocessed_string(result, 'int z;')).to eq(6)
      end

      it 'maps all code correctly in realistic function-level output with multiple comment types' do
        # Realistic preprocessed output: directives, a block comment immediately after
        # a marker, C code under a marker, an inline single-line block comment, and
        # then another multi-line block comment after code.  All markers unchanged.
        content = <<~PREPROCESSED
          # 1 "module.c"
          #include <stdint.h>
          # 2 "module.c"
          /* Module initialization
             functions */
          # 5 "module.c"
          static int initialized = 0;
          # 6 "module.c"
          void module_init(void) {
          # 7 "module.c"
          int status = 0; /* pending */
          /* retry
             loop */
          status = do_init();
          # 12 "module.c"
          initialized = status;
          # 13 "module.c"
          }
        PREPROCESSED

        result = @stripper.strip_string(content)

        expect(result).not_to include('//')
        expect(result).not_to include('/*')
        expect(result).not_to include('*/')

        # All markers unchanged.
        # Comment 1 ("Module initialization\n   functions"): lines_removed=1, replaced by \n.
        # Comment 2 ("pending"): lines_removed=0, replaced by space.
        # Comment 3 ("retry\n   loop"): lines_removed=1, replaced by \n.
        #
        # #include <stdint.h>: marker # 1 + 0 = 1.
        # static int initialized: unchanged marker # 5 + 0 = 5.
        # void module_init: unchanged marker # 6 + 0 = 6.
        # int status = 0: unchanged marker # 7 + 0 = 7.
        # status = do_init(): marker # 7 + 3 newlines
        #   (status-line \n + \n replacement + original \n after retry comment) = 10.
        # initialized = status: unchanged marker # 12 + 0 = 12.
        # }: unchanged marker # 13 + 0 = 13.
        expect(@finder.find_in_preprpocessed_string(result, '#include <stdint.h>')).to eq(1)
        expect(@finder.find_in_preprpocessed_string(result, 'static int initialized = 0;')).to eq(5)
        expect(@finder.find_in_preprpocessed_string(result, 'void module_init(void) {')).to eq(6)
        expect(@finder.find_in_preprpocessed_string(result, 'int status = 0;')).to eq(7)
        expect(@finder.find_in_preprpocessed_string(result, 'status = do_init();')).to eq(10)
        expect(@finder.find_in_preprpocessed_string(result, 'initialized = status;')).to eq(12)
        expect(@finder.find_in_preprpocessed_string(result, '}')).to eq(13)
      end

    end


    # -------------------------------------------------------------------------
    context 'with mixed comment types' do
    # -------------------------------------------------------------------------

      it 'strips a comprehensive realistic directives-only preprocessor output' do
        content = <<~PREPROCESSED
          # 1 "platform.h"
          /*
           * platform.h -- Hardware abstraction layer
           *
           * Target: STM32F4
           */
          # 7 "platform.h"
          #ifndef PLATFORM_H // include guard check
          # 8 "platform.h"
          #define PLATFORM_H
          # 9 "platform.h"
          #define CPU_FREQ_HZ  168000000UL /* 168 MHz */
          # 10 "platform.h"
          #define FLASH_SIZE   0x100000UL  /* 1 MB   */
          # 11 "platform.h"
          #define RAM_SIZE     0x020000UL  /* 128 KB */
          # 12 "platform.h"
          typedef unsigned int uint32_t; // fundamental integer type
          # 16 "platform.h"
          #endif /* PLATFORM_H */
        PREPROCESSED

        result = @stripper.strip_string(content)

        expect(result).not_to include('//')
        expect(result).not_to include('/*')
        expect(result).not_to include('*/')

        # Source-line mapping must be preserved for all key directives.
        # The 5-line block comment (lines_removed=4) is replaced by \n\n\n\n.
        # All markers # 7 through # 16 are unchanged.
        # Directives immediately follow their respective # N "file" markers (0 newlines
        # between), so code finder returns N+0=N for each.
        expect(@finder.find_in_preprpocessed_string(result, '#ifndef PLATFORM_H')).to eq(7)
        expect(@finder.find_in_preprpocessed_string(result, '#define PLATFORM_H')).to eq(8)
        expect(@finder.find_in_preprpocessed_string(result, '#define CPU_FREQ_HZ  168000000UL')).to eq(9)
        expect(@finder.find_in_preprpocessed_string(result, '#define FLASH_SIZE   0x100000UL')).to eq(10)
        expect(@finder.find_in_preprpocessed_string(result, '#define RAM_SIZE     0x020000UL')).to eq(11)
        expect(@finder.find_in_preprpocessed_string(result, 'typedef unsigned int uint32_t;')).to eq(12)
        expect(@finder.find_in_preprpocessed_string(result, '#endif')).to eq(16)
      end

    end

  end

end
