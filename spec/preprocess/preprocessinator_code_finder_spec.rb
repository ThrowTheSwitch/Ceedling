# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/preprocess/preprocessinator_code_finder'

describe PreprocessinatorCodeFinder do

  before(:each) do
    @finder = described_class.new
  end

  context "#find_in_preprpocessed_string" do

    # -----------------------------------------------------------------------
    # nil cases
    # -----------------------------------------------------------------------

    it "returns nil for empty content" do
      expect( @finder.find_in_preprpocessed_string( "", "int foo(void);" ) ).to be_nil
    end

    it "returns nil when the search string is not present in the content" do
      content = <<~PREPROCESSED
        # 1 "source.c"
        int foo(void) { return 0; }
      PREPROCESSED

      expect( @finder.find_in_preprpocessed_string( content, "int bar(void);" ) ).to be_nil
    end

    it "returns nil when no line marker precedes the match" do
      # A marker exists but only after the match — it must not be used
      content = <<~PREPROCESSED
        int foo(void) { return 0; }
        # 5 "source.c"
        int bar(void) { return 1; }
      PREPROCESSED

      expect( @finder.find_in_preprpocessed_string( content, "int foo(void) { return 0; }" ) ).to be_nil
    end

    # -----------------------------------------------------------------------
    # Single line marker
    # -----------------------------------------------------------------------

    it "returns the marker line number when code immediately follows the marker" do
      content = <<~PREPROCESSED
        # 5 "source.c"
        int foo(void) { return 0; }
      PREPROCESSED

      expect( @finder.find_in_preprpocessed_string( content, "int foo(void) { return 0; }" ) ).to eq 5
    end

    it "returns marker linenum plus line offset when code follows after other lines" do
      # Marker says line 10; two lines of other declarations precede the match,
      # placing the target at source line 12.
      content = <<~PREPROCESSED
        # 10 "source.c"
        void setup(void);
        void teardown(void);
        int compute(int x) { return x * 2; }
      PREPROCESSED

      expect( @finder.find_in_preprpocessed_string( content, "int compute(int x) { return x * 2; }" ) ).to eq 12
    end

    it "handles a line marker carrying a single flag" do
      content = <<~PREPROCESSED
        # 7 "source.c" 2
        void process(void);
      PREPROCESSED

      expect( @finder.find_in_preprpocessed_string( content, "void process(void);" ) ).to eq 7
    end

    it "handles a line marker carrying multiple flags" do
      content = <<~PREPROCESSED
        # 13 "system/types.h" 3 4
        typedef unsigned int uint32_t;
        # 4 "source.c"
        void init(uint32_t value);
      PREPROCESSED

      expect( @finder.find_in_preprpocessed_string( content, "void init(uint32_t value);" ) ).to eq 4
    end

    # -----------------------------------------------------------------------
    # Multiple line markers
    # -----------------------------------------------------------------------

    it "uses the closest preceding marker when multiple markers exist before the match" do
      content = <<~PREPROCESSED
        # 1 "header.h" 1
        extern int global_var;
        # 20 "source.c" 2
        int foo(void) { return 0; }
      PREPROCESSED

      # The second marker (line 20) is the last one before the match
      expect( @finder.find_in_preprpocessed_string( content, "int foo(void) { return 0; }" ) ).to eq 20
    end

    it "ignores line markers that appear after the match position" do
      content = <<~PREPROCESSED
        # 3 "source.c"
        int found_here(void);
        # 10 "source.c"
        int not_here(void);
      PREPROCESSED

      # The # 10 marker follows the match and must not influence the result
      expect( @finder.find_in_preprpocessed_string( content, "int found_here(void);" ) ).to eq 3
    end

    it "handles large line numbers correctly" do
      content = <<~PREPROCESSED
        # 1 "source.c"
        /* file preamble */
        # 247 "source.c"
        static void internal_helper(void) {}
      PREPROCESSED

      expect( @finder.find_in_preprpocessed_string( content, "static void internal_helper(void) {}" ) ).to eq 247
    end

    # -----------------------------------------------------------------------
    # Multiline search string
    # -----------------------------------------------------------------------

    it "finds a multiline function body and reports the line of its opening signature" do
      content = <<~PREPROCESSED
        # 15 "module.c"
        int add(int a, int b)
        {
          return a + b;
        }
      PREPROCESSED

      func = <<~FUNCTION
        int add(int a, int b)
        {
          return a + b;
        }
      FUNCTION

      expect( @finder.find_in_preprpocessed_string( content, func ) ).to eq 15
    end

    it "reports the correct offset for a multiline match several lines after the marker" do
      # Marker at line 30; two preceding declarations push the function to line 32.
      content = <<~PREPROCESSED
        # 30 "driver.c"
        #define ENABLE  1
        #define DISABLE 0
        void driver_init(int mode)
        {
          if (mode == ENABLE) { setup(); }
        }
      PREPROCESSED

      func = <<~FUNCTION
        void driver_init(int mode)
        {
          if (mode == ENABLE) { setup(); }
        }
      FUNCTION

      expect( @finder.find_in_preprpocessed_string( content, func ) ).to eq 32
    end

    # -----------------------------------------------------------------------
    # Realistic preprocessor output
    # -----------------------------------------------------------------------

    it "correctly identifies the source line amid interspersed system header content" do
      # Models real GCC -E output: built-in markers, a system include expansion,
      # a return marker, and then the actual source file content.
      content = <<~PREPROCESSED
        # 1 "source.c"
        # 1 "<built-in>" 1
        # 1 "<command-line>" 1
        # 1 "source.c"
        # 1 "/usr/include/stdint.h" 1 3
        typedef unsigned int uint32_t;
        typedef unsigned char uint8_t;
        # 5 "source.c" 2
        #include <stdint.h>
        uint32_t counter;
        void increment(uint32_t *p) { (*p)++; }
      PREPROCESSED

      # After "# 5 "source.c" 2": line 5 = #include, line 6 = counter, line 7 = increment
      expect( @finder.find_in_preprpocessed_string( content, "void increment(uint32_t *p) { (*p)++; }" ) ).to eq 7
    end

  end


  context "#find_in_c_string" do

    # -----------------------------------------------------------------------
    # nil cases
    # -----------------------------------------------------------------------

    it "returns nil for empty content" do
      expect( @finder.find_in_c_string( "", "int foo(void);" ) ).to be_nil
    end

    it "returns nil when the search string is not present in the content" do
      content = "int foo(void);\nint bar(void);\n"
      expect( @finder.find_in_c_string( content, "int baz(void);" ) ).to be_nil
    end

    # -----------------------------------------------------------------------
    # Line number arithmetic — no GCC markers, pure newline count
    # -----------------------------------------------------------------------

    it "returns 1 when the match is at the very start of the content" do
      content = "uint32_t sensor_val;\nint x;\n"
      expect( @finder.find_in_c_string( content, "uint32_t sensor_val;" ) ).to eq 1
    end

    it "returns the correct 1-indexed line number for a match on a later line" do
      content = "int a;\nint b;\nint c;\n"
      expect( @finder.find_in_c_string( content, "int c;" ) ).to eq 3
    end

    it "returns the correct line number for a match on the last line with no trailing newline" do
      content = "void foo(void);\nvoid bar(void);\nvoid baz(void);"
      expect( @finder.find_in_c_string( content, "void baz(void);" ) ).to eq 3
    end

    it "locates a declaration several lines into a realistic C header block" do
      content = <<~C
        #include <stdint.h>
        #include <stdbool.h>
        #define MAX_CHANNELS 16
        typedef struct { uint32_t count; } Buffer;
        void buffer_init(Buffer *b);
        bool buffer_full(const Buffer *b);
      C

      expect( @finder.find_in_c_string( content, "void buffer_init(Buffer *b);" ) ).to eq 5
      expect( @finder.find_in_c_string( content, "bool buffer_full(const Buffer *b);" ) ).to eq 6
    end

    # -----------------------------------------------------------------------
    # Multiline search string
    # -----------------------------------------------------------------------

    it "finds a multiline function body and reports the line of its opening signature" do
      content = <<~C
        void setup(void);
        void teardown(void);
        int add(int a, int b)
        {
          return a + b;
        }
      C

      func = <<~FUNCTION
        int add(int a, int b)
        {
          return a + b;
        }
      FUNCTION

      expect( @finder.find_in_c_string( content, func ) ).to eq 3
    end

    it "reports the correct line for a multiline match preceded by declarations and macros" do
      content = <<~C
        #include <stdint.h>
        #define ENABLE  1
        #define DISABLE 0
        void driver_init(int mode)
        {
          if (mode == ENABLE) { setup(); }
        }
      C

      func = <<~FUNCTION
        void driver_init(int mode)
        {
          if (mode == ENABLE) { setup(); }
        }
      FUNCTION

      expect( @finder.find_in_c_string( content, func ) ).to eq 4
    end

    # -----------------------------------------------------------------------
    # Realistic C source
    # -----------------------------------------------------------------------

    it "correctly locates multiple functions in a realistic stripped C source file" do
      content = <<~C
        #include <stdint.h>
        static uint32_t counter = 0;
        void increment(void) { counter++; }
        uint32_t get_count(void) { return counter; }
        void reset(void) { counter = 0; }
      C

      expect( @finder.find_in_c_string( content, "void increment(void) { counter++; }" ) ).to eq 3
      expect( @finder.find_in_c_string( content, "uint32_t get_count(void) { return counter; }" ) ).to eq 4
      expect( @finder.find_in_c_string( content, "void reset(void) { counter = 0; }" ) ).to eq 5
    end

  end

end
