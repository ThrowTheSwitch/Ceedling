# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/c_extractor/c_extractor'
require 'ceedling/c_extractor/c_extractor_code_text'
require 'ceedling/c_extractor/c_extractor_functions'
require 'ceedling/c_extractor/c_extractor_declarations'

##
## These integration tests exercise the composition of all CExtractor* objects
## in extracting features from C source code.
## Other unit tests exhaustively exerise individual methods, including of CExtractor itself.
##
describe CExtractor do

  let(:extractor) do
    code_text    = CExtractorCodeText.new
    declarations = CExtractorDeclarations.new
    functions    = CExtractorFunctions.new({ c_extractor_code_text: code_text })
    functions.setup()
    extractor = CExtractor.new(
      {
        c_extractor_code_text: code_text,
        c_extractor_functions: functions,
        c_extractor_declarations: declarations
      }
    )
    extractor.setup()
    extractor
  end

  context "#from_string" do
    # Helper method to extract contents from a string as CModule
    let(:extract_from) do
      ->(content) { extractor.from_string(content: content) }
    end

    it "should extract nothing from blank input" do
      contents = extract_from.call('')
      expect( contents.function_definitions.length ).to eq 0
      expect( contents.variables.length ).to eq 0
    end

    it "should extract nothing from whitespace" do
      contents = extract_from.call("                   \n\n\r\n         \t\n\n\n\n")
      expect( contents.function_definitions.length ).to eq 0
      expect( contents.variables.length ).to eq 0
    end

    it "should extract a simple function" do
      file_contents = <<~CONTENTS
      void a_function(void) {
        int a = 1 + 1;
      }
      CONTENTS

      contents = extract_from.call(file_contents)

      expect( contents.variables.length ).to eq 0

      expect( contents.function_definitions.length ).to eq 1
      expect( contents.function_definitions[0].name ).to eq 'a_function'
      expect( contents.function_definitions[0].signature ).to eq 'void a_function(void)'
      expect( contents.function_definitions[0].body ).to eq "{\n  int a = 1 + 1;\n}"
      expect( contents.function_definitions[0].code_block ).to eq file_contents.strip()
      expect( contents.function_definitions[0].line_count ).to eq 3
    end

    it "should extract multiple simple functions" do
      file_contents = <<~CONTENTS
      int
      a_function(int a, int b) {
        int c = a + b;
        c += 5;
        return c;
      }

      void BFUNCTION(void) { int a = 1 + 1; }

        uint16_t*  C_Function ( void )
      {
        return &global_var;
      }
      
      CONTENTS

      contents = extract_from.call(file_contents)

      expect( contents.variables.length ).to eq 0
      expect( contents.function_definitions.length ).to eq 3

      expect( contents.function_definitions[0].name ).to eq 'a_function'
      expect( contents.function_definitions[0].signature ).to eq "int a_function(int a, int b)"
      expect( contents.function_definitions[0].body ).to eq "{\n  int c = a + b;\n  c += 5;\n  return c;\n}"
      expect( contents.function_definitions[0].code_block ).to eq "int\na_function(int a, int b) {\n  int c = a + b;\n  c += 5;\n  return c;\n}"
      expect( contents.function_definitions[0].line_count ).to eq 6

      expect( contents.function_definitions[1].name ).to eq 'BFUNCTION'
      expect( contents.function_definitions[1].signature ).to eq 'void BFUNCTION(void)'
      expect( contents.function_definitions[1].body ).to eq "{ int a = 1 + 1; }"
      expect( contents.function_definitions[1].code_block ).to eq "void BFUNCTION(void) { int a = 1 + 1; }"
      expect( contents.function_definitions[1].line_count ).to eq 1

      expect( contents.function_definitions[2].name ).to eq 'C_Function'
      expect( contents.function_definitions[2].signature ).to eq 'uint16_t* C_Function ( void )'
      expect( contents.function_definitions[2].body ).to eq "{\n  return &global_var;\n}"
      expect( contents.function_definitions[2].code_block ).to eq "uint16_t*  C_Function ( void )\n{\n  return &global_var;\n}"
      expect( contents.function_definitions[2].line_count ).to eq 4
    end

    it "should extract functions and module variables while ignoring deadspace text and errant semicolons" do
      file_contents = <<~CONTENTS

      #include <stdint.h>
      #include "foo.h"

      int global_var;                    // Simple variable
      static const char* ptr = "hello";  // Initialized variable
      struct foo { int x; } instance;;   // Struct with brackets and double semicolon
      int array[] = {1, 2, 3};           // Array initialization with braces

      void a_function(void) { int a = 1 + 1; }

      #define FOO 123
      #define MACRO(x) \
        do { \
          // Triple semicolon after fuction call inside macro \
          something(x);;; \
        } while(0)
      #pragma pack(1)      

      void b_function(void) { int a = 1 + 1;; } // Function with extra semicolon
      
      CONTENTS

      contents = extract_from.call(file_contents)

      expect( contents.variables.length ).to eq 4

      expect( contents.variables[0].name ).to eq 'global_var'
      expect( contents.variables[0].type ).to eq 'int'
      expect( contents.variables[0].decorators ).to eq []
      expect( contents.variables[0].declaration ).to eq 'int global_var;'

      expect( contents.variables[1].original ).to eq 'static const char* ptr = "hello";'
      expect( contents.variables[1].name ).to eq 'ptr'
      expect( contents.variables[1].type ).to eq 'char*'
      expect( contents.variables[1].decorators ).to eq ['static', 'const']
      expect( contents.variables[1].declaration ).to eq 'char* ptr = "hello";'

      expect( contents.variables[2].name ).to eq 'instance'
      expect( contents.variables[2].decorators ).to eq []
      expect( contents.variables[2].declaration ).to eq 'struct foo { int x; } instance;'

      expect( contents.variables[3].name ).to eq 'array'
      expect( contents.variables[3].type ).to eq 'int'
      expect( contents.variables[3].decorators ).to eq []
      expect( contents.variables[3].declaration ).to eq 'int array[] = {1, 2, 3};'

      expect( contents.function_definitions.length ).to eq 2

      expect( contents.function_definitions[0].name ).to eq 'a_function'
      expect( contents.function_definitions[0].signature ).to eq 'void a_function(void)'
      expect( contents.function_definitions[0].body ).to eq "{ int a = 1 + 1; }"
      expect( contents.function_definitions[0].code_block ).to eq "void a_function(void) { int a = 1 + 1; }"
      expect( contents.function_definitions[0].line_count ).to eq 1

      expect( contents.function_definitions[1].name ).to eq 'b_function'
      expect( contents.function_definitions[1].signature ).to eq 'void b_function(void)'
      expect( contents.function_definitions[1].body ).to eq "{ int a = 1 + 1;; }"
      expect( contents.function_definitions[1].code_block ).to eq "void b_function(void) { int a = 1 + 1;; }"
      expect( contents.function_definitions[1].line_count ).to eq 1
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

      contents = extract_from.call(file_contents)

      expect( contents.variables.length ).to eq 0
      expect( contents.function_definitions.length ).to eq 3

      expect( contents.function_definitions[0].name ).to eq 'real_function_a'
      expect( contents.function_definitions[0].signature ).to eq 'void real_function_a(void)'
      expect( contents.function_definitions[0].body ).to eq "{\n  int a = 1;\n  // Comment with braces: { } should not break extraction\n  int b = 2;\n}"
      expect( contents.function_definitions[0].line_count ).to eq 5

      expect( contents.function_definitions[1].name ).to eq 'real_function_b'
      expect( contents.function_definitions[1].signature ).to eq 'void real_function_b(void)'
      expect( contents.function_definitions[1].body ).to eq "{\n  /* Inline comment with braces { } */\n  return;\n}"
      expect( contents.function_definitions[1].line_count ).to eq 4

      expect( contents.function_definitions[2].name ).to eq 'real_function_c'
      expect( contents.function_definitions[2].signature ).to eq 'void real_function_c(void)'
      expect( contents.function_definitions[2].body ).to eq "{ \n  // Single line comment with opening brace {\n  int x = 1;\n  /* Multi-line comment with closing brace } */\n  int y = 2;\n}"
      expect( contents.function_definitions[2].line_count ).to eq 6
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

      contents = extract_from.call(file_contents)

      expect( contents.variables.length ).to eq 0
      expect( contents.function_definitions.length ).to eq 5

      expect( contents.function_definitions[0].name ).to eq 'function_with_if_else'
      expect( contents.function_definitions[0].signature ).to eq 'void function_with_if_else(int x)'
      expect( contents.function_definitions[0].body ).to eq "{\n  if (x > 0) {\n    do_something();\n  } else {\n    do_something_else();\n  }\n}"
      expect( contents.function_definitions[0].line_count ).to eq 7

      expect( contents.function_definitions[1].name ).to eq 'function_with_loops'
      expect( contents.function_definitions[1].signature ).to eq 'void function_with_loops(void)'
      expect( contents.function_definitions[1].body ).to eq "{\n  for (int i = 0; i < 10; i++) {\n    while (condition) {\n      do_work();\n    }\n  }\n}"
      expect( contents.function_definitions[1].line_count ).to eq 7

      expect( contents.function_definitions[2].name ).to eq 'function_with_switch'
      expect( contents.function_definitions[2].signature ).to eq 'void function_with_switch(int value)'
      expect( contents.function_definitions[2].body ).to eq "{\n  switch (value) {\n    case 1: {\n      handle_case_1();\n      break;\n    }\n    case 2: {\n      handle_case_2();\n      break;\n    }\n    default: {\n      handle_default();\n    }\n  }\n}"
      expect( contents.function_definitions[2].line_count ).to eq 15

      expect( contents.function_definitions[3].name ).to eq 'function_with_struct_init'
      expect( contents.function_definitions[3].signature ).to eq 'void function_with_struct_init(void)'
      expect( contents.function_definitions[3].body ).to eq "{\n  struct point {\n    int x;\n    int y;\n  } p = {\n    .x = 10,\n    .y = 20\n  };\n  \n  int array[] = {1, 2, 3, {4, 5, 6}};\n}"
      expect( contents.function_definitions[3].line_count ).to eq 11

      expect( contents.function_definitions[4].name ).to eq 'function_with_nested_blocks'
      expect( contents.function_definitions[4].signature ).to eq 'void function_with_nested_blocks(void)'
      expect( contents.function_definitions[4].body ).to eq "{\n  {\n    int local_scope = 1;\n    {\n      int deeper_scope = 2;\n      if (condition) {\n        {\n          int deepest = 3;\n        }\n      }\n    }\n  }\n}"
      expect( contents.function_definitions[4].line_count ).to eq 13
    end

    it "should extract a lengthy function and variable declarations from complex code with various C constructs" do
      file_contents = <<~CONTENTS
      #include <stdio.h>
      #include <stdlib.h>
      
      #define MAX_SIZE 100
      #define PROCESS(x) do { process_data(x); } while(0)
      
      // Global variables
      static int global_counter = 0;
      const char* global_message = "Hello, World!";
      
      // Forward declarations
      void helper_function(int value);
      int calculate_result(int a, int b);
      
      /* 
       * This is a complex function that demonstrates
       * various C language constructs
       */
      int complex_function(int param1, const char* param2, void* param3) {
        // Local variable declarations
        int result = 0;
        int array[MAX_SIZE] = {0};
        struct {
          int x;
          int y;
          char name[50];
        } local_struct = {
          .x = 10,
          .y = 20,
          .name = "test"
        };
        
        // String with special characters
        const char* message = "This string has { braces } and (parens) and \"quotes\"";
        
        // Conditional logic
        if (param1 > 0) {
          for (int i = 0; i < param1; i++) {
            array[i] = i * 2;
            
            // Nested conditionals
            if (array[i] > 50) {
              switch (array[i]) {
                case 52: {
                  result += 1;
                  break;
                }
                case 54: {
                  result += 2;
                  break;
                }
                default: {
                  result += array[i];
                }
              }
            } else {
              while (array[i] < 25) {
                array[i]++;
                result--;
              }
            }
          }
        } else {
          // Negative parameter handling
          result = -1;
        }
        
        // Function calls with various argument types
        helper_function(result);
        int temp = calculate_result(param1, result);
        
        // Pointer operations
        if (param3 != NULL) {
          int* ptr = (int*)param3;
          *ptr = temp;
        }
        
        // Multi-line macro usage
        PROCESS(result);
        
        // Comment with braces: { } should not break extraction
        /* Another comment with braces { } */
        
        // Final calculations
        result = temp + local_struct.x + local_struct.y;
        
        // Return statement
        return result;
      }
      
      // Another function after the complex one
      void simple_function(void) {
        printf("Simple\\n");
      }
      
      CONTENTS

      contents = extract_from.call(file_contents)

      expect( contents.variables.length ).to eq 2

      expect( contents.variables[0].original ).to eq 'static int global_counter = 0;'
      expect( contents.variables[0].name ).to eq 'global_counter'
      expect( contents.variables[0].type ).to eq 'int'
      expect( contents.variables[0].decorators ).to eq ['static']
      expect( contents.variables[0].declaration ).to eq 'int global_counter = 0;'

      expect( contents.variables[1].original ).to eq 'const char* global_message = "Hello, World!";'
      expect( contents.variables[1].name ).to eq 'global_message'
      expect( contents.variables[1].type ).to eq 'char*'
      expect( contents.variables[1].decorators ).to eq ['const']
      expect( contents.variables[1].declaration ).to eq 'char* global_message = "Hello, World!";'

      expect( contents.function_declarations.length ).to eq 2

      expect( contents.function_definitions.length ).to eq 2

      # Note: For sake of space, `body` and `code_block` are not tested.

      expect( contents.function_definitions[0].name ).to eq 'complex_function'
      expect( contents.function_definitions[0].signature ).to eq 'int complex_function(int param1, const char* param2, void* param3)'
      expect( contents.function_definitions[0].line_count ).to eq 71

      expect( contents.function_definitions[1].name ).to eq 'simple_function'
      expect( contents.function_definitions[1].signature ).to eq 'void simple_function(void)'
      expect( contents.function_definitions[1].line_count ).to eq 3
    end

    it "should extract multiple simple functions longer than buffer chunk size" do
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

      contents = extractor.from_string(content: file_contents, chunk_size: 10)

      expect( contents.variables.length ).to eq 0

      expect( contents.function_definitions.length ).to eq 3

      expect( contents.function_definitions[0].name ).to eq 'a_function'
      expect( contents.function_definitions[0].signature ).to eq 'int a_function(int a, int b)'
      expect( contents.function_definitions[0].body ).to eq "{\n  int c = a + b;\n  c += 5;\n  return c;\n}"
      expect( contents.function_definitions[0].code_block ).to eq "int a_function(int a, int b) {\n  int c = a + b;\n  c += 5;\n  return c;\n}"
      expect( contents.function_definitions[0].line_count ).to eq 5

      expect( contents.function_definitions[1].name ).to eq 'BFUNCTION'
      expect( contents.function_definitions[1].signature ).to eq 'void BFUNCTION(void)'
      expect( contents.function_definitions[1].body ).to eq "{ int a = 1 + 1; }"
      expect( contents.function_definitions[1].code_block ).to eq "void BFUNCTION(void) { int a = 1 + 1; }"
      expect( contents.function_definitions[1].line_count ).to eq 1

      expect( contents.function_definitions[2].name ).to eq 'C_Function'
      expect( contents.function_definitions[2].signature ).to eq 'uint16_t* C_Function (void)'
      expect( contents.function_definitions[2].body ).to eq "{\n  return &global_var;\n}"
      expect( contents.function_definitions[2].code_block ).to eq "uint16_t*  C_Function (void)\n{\n  return &global_var;\n}"
      expect( contents.function_definitions[2].line_count ).to eq 4
    end

    it "should fail to extract a function longer than max buffer length" do
      file_contents = <<~CONTENTS
      void a_function(void) {
        int a = 1 + 1;
      }
      CONTENTS

      # TODO: Test for function name extraction after implementing generic handling of feature summaries
      expect { extractor.from_string(content: file_contents, chunk_size: 10, max_buffer_length: 20) }.to raise_error(CeedlingException, /Feature extraction exceeded maximum length/)
    end

    it "should fail to extract a signature longer than max length" do
      file_contents = <<~CONTENTS
      void a_function(void) {
        int a = 1 + 1;
      }
      CONTENTS

      contents = extractor.from_string(content: file_contents, chunk_size: 10, max_line_length: 10)
      expect(contents.function_definitions.length ).to eq 0
    end
    
  end

end
