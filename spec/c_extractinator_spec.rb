# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/c_extractinator'

describe CExtractinator do

  context "#extract_functions" do
    # Helper method to create extractinator and extract functions from a string
    let(:extract_from) do
      ->(content) do
        extractinator = CExtractinator.from_string(content)
        extractinator.extract_functions()
      end
    end

    it "should extract nothing from blank input" do
      funcs = extract_from.call('')
      expect( funcs.length ).to eq 0
    end

    it "should extract nothing from whitespace" do
      funcs = extract_from.call("                   \n\n\r\n         \t\n\n\n\n")
      expect( funcs.length ).to eq 0
    end

    it "should extract a simple function" do
      file_contents = <<~CONTENTS
      void a_function(void) {
        int a = 1 + 1;
      }
      CONTENTS

      funcs = extract_from.call(file_contents)

      expect( funcs.length ).to eq 1
      expect( funcs[0].name ).to eq 'a_function'
      expect( funcs[0].signature ).to eq 'void a_function(void)'
      expect( funcs[0].body ).to eq "{\n  int a = 1 + 1;\n}"
      expect( funcs[0].code_block ).to eq file_contents.strip()
      expect( funcs[0].line_count ).to eq 3
    end

    it "should extract multiple simple functions" do
      file_contents = <<~CONTENTS
      int a_function(int a, int b) {
        int c = a + b;
        c += 5;
        return c;
      }

      void BFUNCTION(void) { int a = 1 + 1; }

        uint16_t*  C_Function (void)
      {
        return &global_var;
      }
      
      CONTENTS

      funcs = extract_from.call(file_contents)

      expect( funcs.length ).to eq 3

      expect( funcs[0].name ).to eq 'a_function'
      expect( funcs[0].signature ).to eq 'int a_function(int a, int b)'
      expect( funcs[0].body ).to eq "{\n  int c = a + b;\n  c += 5;\n  return c;\n}"
      expect( funcs[0].code_block ).to eq "int a_function(int a, int b) {\n  int c = a + b;\n  c += 5;\n  return c;\n}"
      expect( funcs[0].line_count ).to eq 5

      expect( funcs[1].name ).to eq 'BFUNCTION'
      expect( funcs[1].signature ).to eq 'void BFUNCTION(void)'
      expect( funcs[1].body ).to eq "{ int a = 1 + 1; }"
      expect( funcs[1].code_block ).to eq "void BFUNCTION(void) { int a = 1 + 1; }"
      expect( funcs[1].line_count ).to eq 1

      expect( funcs[2].name ).to eq 'C_Function'
      expect( funcs[2].signature ).to eq 'uint16_t*  C_Function (void)'
      expect( funcs[2].body ).to eq "{\n  return &global_var;\n}"
      expect( funcs[2].code_block ).to eq "uint16_t*  C_Function (void)\n{\n  return &global_var;\n}"
      expect( funcs[2].line_count ).to eq 4
    end

    it "should extract functions while ignoring module variables and preprocessor directives" do
      file_contents = <<~CONTENTS

      #include <stdint.h>
      #include "foo.h"

      int global_var;                    // Simple variable
      static const char* ptr = "hello";  // Initialized variable
      struct foo { int x; } instance;    // Struct with brackets
      int array[] = {1, 2, 3};           // Array initialization with braces

      void a_function(void) { int a = 1 + 1; }

      #define FOO 123
      #define MACRO(x) \
        do { \
          something(x); \
        } while(0)
      #pragma pack(1)      

      void b_function(void) { int a = 1 + 1; }
      
      CONTENTS

      funcs = extract_from.call(file_contents)

      expect( funcs.length ).to eq 2

      expect( funcs[0].name ).to eq 'a_function'
      expect( funcs[0].signature ).to eq 'void a_function(void)'
      expect( funcs[0].body ).to eq "{ int a = 1 + 1; }"
      expect( funcs[0].code_block ).to eq "void a_function(void) { int a = 1 + 1; }"
      expect( funcs[0].line_count ).to eq 1

      expect( funcs[1].name ).to eq 'b_function'
      expect( funcs[1].signature ).to eq 'void b_function(void)'
      expect( funcs[1].body ).to eq "{ int a = 1 + 1; }"
      expect( funcs[1].code_block ).to eq "void b_function(void) { int a = 1 + 1; }"
      expect( funcs[1].line_count ).to eq 1
    end

    it "should ignore commented out functions and handle comments with braces" do
      file_contents = <<~CONTENTS

      // This is a commented out function that should be ignored
      // void commented_function(void) {
      //   int x = 1;
      // }

      void real_function_a(void) {
        int a = 1;
        // Comment with braces: { } should not break extraction
        int b = 2;
      }

      /* 
       * Multi-line comment with function-like text
       * void another_commented_function(void) {
       *   return 42;
       * }
       */

      void real_function_b(void) {
        /* Inline comment with braces { } */
        return;
      }

      /*
      void yet_another_commented_function(void) {
        int z = 3;
      }
      */

      void real_function_c(void) { 
        // Single line comment with opening brace {
        int x = 1;
        /* Multi-line comment with closing brace } */
        int y = 2;
      }

      CONTENTS

      funcs = extract_from.call(file_contents)

      expect( funcs.length ).to eq 3

      expect( funcs[0].name ).to eq 'real_function_a'
      expect( funcs[0].signature ).to eq 'void real_function_a(void)'
      expect( funcs[0].body ).to eq "{\n  int a = 1;\n  // Comment with braces: { } should not break extraction\n  int b = 2;\n}"
      expect( funcs[0].line_count ).to eq 5

      expect( funcs[1].name ).to eq 'real_function_b'
      expect( funcs[1].signature ).to eq 'void real_function_b(void)'
      expect( funcs[1].body ).to eq "{\n  /* Inline comment with braces { } */\n  return;\n}"
      expect( funcs[1].line_count ).to eq 4

      expect( funcs[2].name ).to eq 'real_function_c'
      expect( funcs[2].signature ).to eq 'void real_function_c(void)'
      expect( funcs[2].body ).to eq "{ \n  // Single line comment with opening brace {\n  int x = 1;\n  /* Multi-line comment with closing brace } */\n  int y = 2;\n}"
      expect( funcs[2].line_count ).to eq 6
    end

    it "should extract functions with nested braces from control flow and initializers" do
      file_contents = <<~CONTENTS

      void function_with_if_else(int x) {
        if (x > 0) {
          do_something();
        } else {
          do_something_else();
        }
      }

      void function_with_loops(void) {
        for (int i = 0; i < 10; i++) {
          while (condition) {
            do_work();
          }
        }
      }

      void function_with_switch(int value) {
        switch (value) {
          case 1: {
            handle_case_1();
            break;
          }
          case 2: {
            handle_case_2();
            break;
          }
          default: {
            handle_default();
          }
        }
      }

      void function_with_struct_init(void) {
        struct point {
          int x;
          int y;
        } p = {
          .x = 10,
          .y = 20
        };
        
        int array[] = {1, 2, 3, {4, 5, 6}};
      }

      void function_with_nested_blocks(void) {
        {
          int local_scope = 1;
          {
            int deeper_scope = 2;
            if (condition) {
              {
                int deepest = 3;
              }
            }
          }
        }
      }

      CONTENTS

      funcs = extract_from.call(file_contents)

      expect( funcs.length ).to eq 5

      expect( funcs[0].name ).to eq 'function_with_if_else'
      expect( funcs[0].signature ).to eq 'void function_with_if_else(int x)'
      expect( funcs[0].body ).to eq "{\n  if (x > 0) {\n    do_something();\n  } else {\n    do_something_else();\n  }\n}"
      expect( funcs[0].line_count ).to eq 7

      expect( funcs[1].name ).to eq 'function_with_loops'
      expect( funcs[1].signature ).to eq 'void function_with_loops(void)'
      expect( funcs[1].body ).to eq "{\n  for (int i = 0; i < 10; i++) {\n    while (condition) {\n      do_work();\n    }\n  }\n}"
      expect( funcs[1].line_count ).to eq 7

      expect( funcs[2].name ).to eq 'function_with_switch'
      expect( funcs[2].signature ).to eq 'void function_with_switch(int value)'
      expect( funcs[2].body ).to eq "{\n  switch (value) {\n    case 1: {\n      handle_case_1();\n      break;\n    }\n    case 2: {\n      handle_case_2();\n      break;\n    }\n    default: {\n      handle_default();\n    }\n  }\n}"
      expect( funcs[2].line_count ).to eq 15

      expect( funcs[3].name ).to eq 'function_with_struct_init'
      expect( funcs[3].signature ).to eq 'void function_with_struct_init(void)'
      expect( funcs[3].body ).to eq "{\n  struct point {\n    int x;\n    int y;\n  } p = {\n    .x = 10,\n    .y = 20\n  };\n  \n  int array[] = {1, 2, 3, {4, 5, 6}};\n}"
      expect( funcs[3].line_count ).to eq 11

      expect( funcs[4].name ).to eq 'function_with_nested_blocks'
      expect( funcs[4].signature ).to eq 'void function_with_nested_blocks(void)'
      expect( funcs[4].body ).to eq "{\n  {\n    int local_scope = 1;\n    {\n      int deeper_scope = 2;\n      if (condition) {\n        {\n          int deepest = 3;\n        }\n      }\n    }\n  }\n}"
      expect( funcs[4].line_count ).to eq 13
    end
  end

end
