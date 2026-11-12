# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/c_extractor/c_extractor'
require 'ceedling/c_extractor/c_extractor_code_text'
require 'ceedling/c_extractor/c_extractor_functions'
require 'ceedling/c_extractor/c_extractor_declarations'
require 'ceedling/c_extractor/c_extractor_preprocessing'
require 'ceedling/c_extractor/c_extractor_definitions'

##
## These tests exercise the composition of all CExtractor* objects -- real,
## fully-wired collaborators, not mocked -- extracting features from real C source
## code. Migrated here from spec/units/c_extractor/ (its former name,
## c_extractor_integration_spec.rb, already said what it was; the directory now
## conveys the tier instead of the filename needing to). spec/units/c_extractor/
## still holds exhaustive per-method unit coverage of each CExtractor* class in
## isolation, including of CExtractor itself.
##
describe CExtractor do

  let(:extractor) do
    code_text     = CExtractorCodeText.new
    declarations  = CExtractorDeclarations.new({ c_extractor_code_text: code_text })
    functions     = CExtractorFunctions.new({ c_extractor_code_text: code_text })
    preprocessing = CExtractorPreprocessing.new({ c_extractor_code_text: code_text })
    definitions   = CExtractorDefinitions.new({ c_extractor_code_text: code_text })
    declarations.setup()
    functions.setup()
    extractor = CExtractor.new(
      {
        c_extractor_code_text:     code_text,
        c_extractor_functions:     functions,
        c_extractor_declarations:  declarations,
        c_extractor_preprocessing: preprocessing,
        c_extractor_definitions:   definitions,
        # Bare double (no :partials_max_extraction_length stub) so #respond_to? is
        # false and CExtractor falls back to its own built-in default buffer length.
        configurator:              double('Configurator'),
        loginator:                 double('Loginator').as_null_object,
        file_wrapper:              double('FileWrapper').as_null_object
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

    # Each element in order, as its kind and its text or signature
    def sequence_of(content, chunk_size: CExtractorConstants::DEFAULT_CHUNK_SIZE)
      extractor.from_string( content: content, chunk_size: chunk_size ).element_sequence.map { |element| [element.class.name.split( '::' ).last, element.respond_to?( :text ) ? element.text : element.signature] }
    end

    it "should extract nothing from blank input" do
      contents = extract_from.call('')
      expect( contents.function_definitions.length ).to eq 0
      expect( contents.variable_declarations.length ).to eq 0
    end

    it "should extract nothing from whitespace" do
      contents = extract_from.call("                   \n\n\r\n         \t\n\n\n\n")
      expect( contents.function_definitions.length ).to eq 0
      expect( contents.variable_declarations.length ).to eq 0
    end

    it "should extract a simple function" do
      file_contents = <<~CONTENTS
      void a_function(void) {
        int a = 1 + 1;
      }
      CONTENTS

      contents = extract_from.call(file_contents)

      expect( contents.variable_declarations.length ).to eq 0

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

      expect( contents.variable_declarations.length ).to eq 0
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
      file_contents = <<~'CONTENTS'

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

      expect( contents.variable_declarations.length ).to eq 4

      expect( contents.variable_declarations[0].name ).to eq 'global_var'
      expect( contents.variable_declarations[0].type ).to eq 'int'
      expect( contents.variable_declarations[0].decorators ).to eq []
      expect( contents.variable_declarations[0].text ).to eq 'int global_var;'

      expect( contents.variable_declarations[1].original ).to eq 'static const char* ptr = "hello";'
      expect( contents.variable_declarations[1].name ).to eq 'ptr'
      expect( contents.variable_declarations[1].type ).to eq 'char*'
      expect( contents.variable_declarations[1].decorators ).to eq ['static', 'const']
      expect( contents.variable_declarations[1].text ).to eq 'char* ptr = "hello";'

      expect( contents.variable_declarations[2].name ).to eq 'instance'
      expect( contents.variable_declarations[2].decorators ).to eq []
      expect( contents.variable_declarations[2].text ).to eq 'instance;'
      expect( contents.variable_declarations[2].defined_type.text ).to eq 'struct foo { int x; };'

      expect( contents.variable_declarations[3].name ).to eq 'array'
      expect( contents.variable_declarations[3].type ).to eq 'int'
      expect( contents.variable_declarations[3].decorators ).to eq []
      expect( contents.variable_declarations[3].text ).to eq 'int array[] = {1, 2, 3};'

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

      expect( contents.macro_definitions.length ).to eq 2
      expect( contents.macro_definitions[0].text ).to eq "#define FOO 123"
      expect( contents.macro_definitions[0].line_num ).to eq 12
      expect( contents.macro_definitions[1].text ).to start_with("#define MACRO(x) \\\n")
      expect( contents.macro_definitions[1].line_num ).to eq 13
      expect( contents.variable_declarations[0].line_num ).to eq 5
      expect( contents.variable_declarations[1].line_num ).to eq 6
      expect( contents.variable_declarations[2].line_num ).to eq 7
      expect( contents.variable_declarations[3].line_num ).to eq 8
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

      expect( contents.variable_declarations.length ).to eq 0
      expect( contents.function_definitions.length ).to eq 3

      expect( contents.function_definitions[0].name ).to eq 'real_function_a'
      expect( contents.function_definitions[0].signature ).to eq 'void real_function_a(void)'
      # Line comment + its newline replaced by one space; 2-space indents on both sides preserved
      expect( contents.function_definitions[0].body ).to eq "{\n  int a = 1;\n     int b = 2;\n}"
      expect( contents.function_definitions[0].line_count ).to eq 5  # based on original code_block, not rebuilt body

      expect( contents.function_definitions[1].name ).to eq 'real_function_b'
      expect( contents.function_definitions[1].signature ).to eq 'void real_function_b(void)'
      # Block comment replaced by one space; newline + indent after comment preserved
      expect( contents.function_definitions[1].body ).to eq "{\n   \n  return;\n}"
      expect( contents.function_definitions[1].line_count ).to eq 4  # based on original code_block, not rebuilt body

      expect( contents.function_definitions[2].name ).to eq 'real_function_c'
      expect( contents.function_definitions[2].signature ).to eq 'void real_function_c(void)'
      # Line comment + its newline → space (5 chars before int x); block comment → space (3 chars on blank line)
      expect( contents.function_definitions[2].body ).to eq "{ \n     int x = 1;\n   \n  int y = 2;\n}"
      expect( contents.function_definitions[2].line_count ).to eq 6  # based on original code_block, not rebuilt body
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

      expect( contents.variable_declarations.length ).to eq 0
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

      expect( contents.variable_declarations.length ).to eq 2

      expect( contents.variable_declarations[0].original ).to eq 'static int global_counter = 0;'
      expect( contents.variable_declarations[0].name ).to eq 'global_counter'
      expect( contents.variable_declarations[0].type ).to eq 'int'
      expect( contents.variable_declarations[0].decorators ).to eq ['static']
      expect( contents.variable_declarations[0].text ).to eq 'int global_counter = 0;'
      expect( contents.variable_declarations[0].line_num ).to eq 8

      expect( contents.variable_declarations[1].original ).to eq 'const char* global_message = "Hello, World!";'
      expect( contents.variable_declarations[1].name ).to eq 'global_message'
      expect( contents.variable_declarations[1].type ).to eq 'char*'
      expect( contents.variable_declarations[1].decorators ).to eq ['const']
      expect( contents.variable_declarations[1].text ).to eq 'char* global_message = "Hello, World!";'
      expect( contents.variable_declarations[1].line_num ).to eq 9

      expect( contents.function_declarations.length ).to eq 2
      expect( contents.function_declarations[0].line_num ).to eq 12
      expect( contents.function_declarations[1].line_num ).to eq 13

      expect( contents.function_definitions.length ).to eq 2

      # Note: For sake of space, `body` and `code_block` are not tested.

      expect( contents.function_definitions[0].name ).to eq 'complex_function'
      expect( contents.function_definitions[0].signature ).to eq 'int complex_function(int param1, const char* param2, void* param3)'
      expect( contents.function_definitions[0].line_count ).to eq 71
      expect( contents.function_definitions[0].line_num ).to eq 19

      expect( contents.function_definitions[1].name ).to eq 'simple_function'
      expect( contents.function_definitions[1].signature ).to eq 'void simple_function(void)'
      expect( contents.function_definitions[1].line_count ).to eq 3
      expect( contents.function_definitions[1].line_num ).to eq 92

      expect( contents.macro_definitions.length ).to eq 2
      expect( contents.macro_definitions[0].text ).to eq "#define MAX_SIZE 100"
      expect( contents.macro_definitions[0].line_num ).to eq 4
      expect( contents.macro_definitions[1].text ).to eq "#define PROCESS(x) do { process_data(x); } while(0)"
      expect( contents.macro_definitions[1].line_num ).to eq 5
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

      expect( contents.variable_declarations.length ).to eq 0

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

    it "should extract macro definitions and no other features from a macros-only input" do
      file_contents = <<~'CONTENTS'
      #define SIMPLE 1
      #define WITH_ARGS(x, y) ((x) + (y))
      #define MULTILINE(a) \
        do { \
          process(a); \
        } while(0)
      CONTENTS

      contents = extract_from.call(file_contents)

      expect( contents.macro_definitions.length ).to eq 3
      expect( contents.macro_definitions[0].text ).to eq "#define SIMPLE 1"
      expect( contents.macro_definitions[0].line_num ).to eq 1
      expect( contents.macro_definitions[1].text ).to eq "#define WITH_ARGS(x, y) ((x) + (y))"
      expect( contents.macro_definitions[1].line_num ).to eq 2
      expect( contents.macro_definitions[2].text ).to start_with("#define MULTILINE(a) \\\n")
      expect( contents.macro_definitions[2].line_num ).to eq 3
      expect( contents.function_definitions.length ).to eq 0
      expect( contents.function_declarations.length ).to eq 0
      expect( contents.variable_declarations.length ).to eq 0
    end

    # #1262: Partials-generated headers occasionally concatenated two adjacent
    # #define lines onto one physical line. Reconstructing the joined text
    # from element_sequence (as generator_partials.rb does) rules the plain,
    # comment-free case in or out formally, rather than by inspection of
    # #_collect_directive alone. This shape -- three plain register-offset
    # macros in a row, no comments -- is expected to reconstruct cleanly.
    it "reconstructs three adjacent plain #define macros joined by newlines with no text lost between them" do
      file_contents = <<~'CONTENTS'
      #define START_ADDRESS 0x00
      #define IDX_DATARATE (ADS124S08_REG_ADDR_DATARATE - START_ADDRESS)
      #define IDX_REF (ADS124S08_REG_ADDR_REF - START_ADDRESS)
      CONTENTS

      contents = extract_from.call(file_contents)

      expect( contents.macro_definitions.length ).to eq 3
      joined = contents.element_sequence.map(&:text).join("\n")
      expect( joined ).to eq(
        "#define START_ADDRESS 0x00\n" +
        "#define IDX_DATARATE (ADS124S08_REG_ADDR_DATARATE - START_ADDRESS)\n" +
        "#define IDX_REF (ADS124S08_REG_ADDR_REF - START_ADDRESS)"
      )
    end

    # #1262's actual reported trigger: a trailing // comment on one #define containing
    # an ordinary English contraction. The stray apostrophe used to be scanned as the
    # start of a char literal, sending the directive scanner hunting for a closing
    # match straight through this macro's own newline and into the next two #defines
    # -- merging all three into one macro_definitions entry with no separating newline,
    # which is exactly what later caused Partials-generated headers to concatenate two
    # #define lines onto one physical line ("stray '#' in program").
    it "reconstructs three adjacent #define macros when one has a trailing comment with an apostrophe" do
      file_contents = <<~'CONTENTS'
      #define START_ADDRESS 0x00 // don't change this
      #define IDX_DATARATE (ADS124S08_REG_ADDR_DATARATE - START_ADDRESS)
      #define IDX_REF (ADS124S08_REG_ADDR_REF - START_ADDRESS)
      CONTENTS

      contents = extract_from.call(file_contents)

      expect( contents.macro_definitions.length ).to eq 3
      expect( contents.macro_definitions[0].text ).to eq "#define START_ADDRESS 0x00 // don't change this"
      expect( contents.macro_definitions[1].text ).to eq "#define IDX_DATARATE (ADS124S08_REG_ADDR_DATARATE - START_ADDRESS)"
      expect( contents.macro_definitions[2].text ).to eq "#define IDX_REF (ADS124S08_REG_ADDR_REF - START_ADDRESS)"

      joined = contents.element_sequence.map(&:text).join("\n")
      expect( joined ).to eq(
        "#define START_ADDRESS 0x00 // don't change this\n" +
        "#define IDX_DATARATE (ADS124S08_REG_ADDR_DATARATE - START_ADDRESS)\n" +
        "#define IDX_REF (ADS124S08_REG_ADDR_REF - START_ADDRESS)"
      )
    end

    it "should extract a function definition following a #define with an escaped character in a string literal (GH #1184)" do
      file_contents = <<~'CONTENTS'
      #include "world.h"
      #define SZ1 sizeof("\n")
      void helloWorld() { return; }
      CONTENTS

      contents = extract_from.call(file_contents)

      expect( contents.macro_definitions.length ).to eq 1
      expect( contents.macro_definitions[0].text ).to eq '#define SZ1 sizeof("\n")'

      expect( contents.function_definitions.length ).to eq 1
      expect( contents.function_definitions[0].name ).to eq 'helloWorld'
      expect( contents.function_definitions[0].body ).to eq '{ return; }'
    end

    it "should consume #pragma and #include directives without storing them" do
      file_contents = <<~CONTENTS
      #pragma once
      #include <stdio.h>
      #include "myheader.h"

      void a_function(void) {}
      CONTENTS

      contents = extract_from.call(file_contents)

      expect( contents.macro_definitions.length ).to eq 0
      expect( contents.function_definitions.length ).to eq 1
      expect( contents.function_definitions[0].name ).to eq 'a_function'
    end

    it "should fail to extract a function longer than max buffer length" do
      file_contents = <<~CONTENTS
      void a_function(void) {
        int a = 1 + 1;
      }
      CONTENTS

      # TODO: Test for function name extraction after implementing generic handling of feature summaries
      expect { extractor.from_string(content: file_contents, chunk_size: 10, max_buffer_length: 20) }.to raise_error(CeedlingException, /Extraction exceeded maximum length/)
    end

    it "should extract a variable declaration longer than 1000 characters" do
      # A single limit governs every feature type (see extract_next_feature); this confirms a
      # declaration comfortably longer than the old, now-removed 1000-character inner limit is
      # captured rather than silently dropped, as long as it's within the (much larger) buffer
      # ceiling -- the default here, since none is passed explicitly.
      values = (1..400).map { |n| n.to_s }.join(', ')
      file_contents = "static const int a_table[] = { #{values} };\n"
      expect(file_contents.length).to be > 1000

      contents = extractor.from_string(content: file_contents)
      expect(contents.variable_declarations.length).to eq 1
      expect(contents.variable_declarations[0].name).to eq 'a_table'
    end

    it "should extract typedef definitions and no other features from a typedefs-only input" do
      file_contents = <<~CONTENTS
      typedef int MyInt;
      typedef const char* CStr;
      typedef void (*Callback)(int, void*);
      typedef enum { RED, GREEN, BLUE } Color;
      typedef struct {
        int x;
        int y;
      } Point;
      CONTENTS

      contents = extract_from.call(file_contents)

      expect( contents.type_definitions.length ).to eq 5

      expect( contents.type_definitions[0].text ).to eq "typedef int MyInt;"
      expect( contents.type_definitions[0].line_num ).to eq 1
      expect( contents.type_definitions[1].text ).to eq "typedef const char* CStr;"
      expect( contents.type_definitions[1].line_num ).to eq 2
      expect( contents.type_definitions[2].text ).to eq "typedef void (*Callback)(int, void*);"
      expect( contents.type_definitions[2].line_num ).to eq 3
      expect( contents.type_definitions[3].text ).to eq "typedef enum { RED, GREEN, BLUE } Color;"
      expect( contents.type_definitions[3].line_num ).to eq 4
      expect( contents.type_definitions[4].text ).to start_with("typedef struct {\n")
      expect( contents.type_definitions[4].text ).to end_with("} Point;")
      expect( contents.type_definitions[4].line_num ).to eq 5

      expect( contents.function_definitions.length ).to eq 0
      expect( contents.function_declarations.length ).to eq 0
      expect( contents.variable_declarations.length ).to eq 0
      expect( contents.macro_definitions.length ).to eq 0
    end

    it "should extract typedefs alongside functions, variables, and macros" do
      file_contents = <<~CONTENTS
      #include <stdint.h>

      #define MAX_VAL 255

      typedef uint8_t Byte;
      typedef struct { int x; int y; } Point;

      static int global_counter = 0;

      void helper(void);

      int compute(int a, int b) {
        return a + b;
      }
      CONTENTS

      contents = extract_from.call(file_contents)

      expect( contents.type_definitions.length ).to eq 2
      expect( contents.type_definitions[0].text ).to eq "typedef uint8_t Byte;"
      expect( contents.type_definitions[0].line_num ).to eq 5
      expect( contents.type_definitions[1].text ).to eq "typedef struct { int x; int y; } Point;"
      expect( contents.type_definitions[1].line_num ).to eq 6

      expect( contents.macro_definitions.length ).to eq 1
      expect( contents.macro_definitions[0].text ).to eq "#define MAX_VAL 255"
      expect( contents.macro_definitions[0].line_num ).to eq 3

      expect( contents.variable_declarations.length ).to eq 1
      expect( contents.variable_declarations[0].name ).to eq 'global_counter'
      expect( contents.variable_declarations[0].line_num ).to eq 8

      expect( contents.function_declarations.length ).to eq 1
      expect( contents.function_declarations[0].name ).to eq 'helper'

      expect( contents.function_definitions.length ).to eq 1
      expect( contents.function_definitions[0].name ).to eq 'compute'
    end

    it "should extract non-typedef struct, enum, and union definitions into aggregate_definitions" do
      file_contents = <<~'CONTENTS'
        #include <stdint.h>

        struct Point {
          int x;
          int y;
        };

        enum Color { RED, GREEN, BLUE };

        union Number {
          int   i;
          float f;
        };

        /* struct with declarator — the type joins aggregate_definitions, the variable variable_declarations */
        struct Foo { int val; } foo_instance;

        typedef struct { int a; int b; } Pair;

        int some_global = 0;

        void a_function(void) {
          int local = 1;
        }
      CONTENTS

      contents = extract_from.call(file_contents)

      expect( contents.aggregate_definitions.length ).to eq 4
      expect( contents.aggregate_definitions[0].text ).to start_with('struct Point')
      expect( contents.aggregate_definitions[0].text ).to include('int x;')
      expect( contents.aggregate_definitions[0].line_num ).to eq 3
      expect( contents.aggregate_definitions[1].text ).to eq "enum Color { RED, GREEN, BLUE };"
      expect( contents.aggregate_definitions[1].line_num ).to eq 8
      expect( contents.aggregate_definitions[2].text ).to start_with('union Number')
      expect( contents.aggregate_definitions[2].line_num ).to eq 10

      # struct Foo { int val; } foo_instance; defines the type its variable names
      expect( contents.aggregate_definitions[3].text ).to eq 'struct Foo { int val; };'
      expect( contents.aggregate_definitions[3].line_num ).to eq 16
      expect( contents.variable_declarations.length ).to eq 2
      expect( contents.variable_declarations[0].name ).to eq 'foo_instance'
      expect( contents.variable_declarations[0].defined_type ).to equal( contents.aggregate_definitions[3] )
      expect( contents.variable_declarations[1].name ).to eq 'some_global'

      expect( contents.type_definitions.length ).to eq 1
      expect( contents.type_definitions[0].text ).to include('typedef struct')

      expect( contents.function_definitions.length ).to eq 1
      expect( contents.function_definitions[0].name ).to eq 'a_function'
      expect( contents.macro_definitions.length     ).to eq 0
      expect( contents.function_declarations.length ).to eq 0
    end

    it "should consume static assert statements without collecting them" do
      file_contents = <<~'CONTENTS'
        #include <stdint.h>

        _Static_assert(sizeof(int) == 4, "int must be 32-bit");

        typedef struct {
          int x;
          int y;
        } Point;

        static_assert(sizeof(Point) == 8);

        static_assert(
          offsetof(Point, y) == sizeof(int),
          "y must follow x with no padding"
        );

        void some_function(void) {
          int local = 0;
        }
      CONTENTS

      contents = extract_from.call(file_contents)

      # Static asserts are consumed — nothing lands in any CModule field
      expect( contents.function_definitions.length  ).to eq 1
      expect( contents.function_declarations.length ).to eq 0
      expect( contents.variable_declarations.length ).to eq 0
      expect( contents.type_definitions.length      ).to eq 1   # the typedef struct
      expect( contents.macro_definitions.length     ).to eq 0   # #include is not #define

      expect( contents.function_definitions[0].name ).to eq 'some_function'
      expect( contents.type_definitions[0].text ).to include('typedef struct')
    end

    it "should populate element_sequence in cross-type line order from a single file" do
      # One item of each extractable type, ordered by line number.
      # Blank lines ensure each item lands on a predictable, distinct line.
      file_contents = <<~CONTENTS

      typedef uint8_t Byte;

      #define MAX 100

      int global_var;

      void helper(void);

      void compute(int x) {
        return x;
      }
      CONTENTS

      contents = extract_from.call(file_contents)

      expect( contents.element_sequence.length ).to eq 5

      expect( contents.element_sequence[0] ).to be_a( CExtractorTypes::CStatement )
      expect( contents.element_sequence[0].line_num ).to eq 2   # typedef

      expect( contents.element_sequence[1] ).to be_a( CExtractorTypes::CStatement )
      expect( contents.element_sequence[1].line_num ).to eq 4   # macro

      expect( contents.element_sequence[2] ).to be_a( CExtractorTypes::CVariableDeclaration )
      expect( contents.element_sequence[2].line_num ).to eq 6

      expect( contents.element_sequence[3] ).to be_a( CExtractorTypes::CFunctionDeclaration )
      expect( contents.element_sequence[3].line_num ).to eq 8

      expect( contents.element_sequence[4] ).to be_a( CExtractorTypes::CFunctionDefinition )
      expect( contents.element_sequence[4].line_num ).to eq 10

      # Spot-check that element_sequence holds the same object references as the typed arrays —
      # no duplication, just an ordering index into the same structs.
      expect( contents.element_sequence[0] ).to equal( contents.type_definitions[0] )
      expect( contents.element_sequence[1] ).to equal( contents.macro_definitions[0] )
      expect( contents.element_sequence[2] ).to equal( contents.variable_declarations[0] )
      expect( contents.element_sequence[3] ).to equal( contents.function_declarations[0] )
      expect( contents.element_sequence[4] ).to equal( contents.function_definitions[0] )
    end

    it "should place all header items before all source items in element_sequence after CModule merge" do
      # Header has a typedef at line 1 and a function declaration at line 3.
      header_string = <<~CONTENTS
      typedef uint8_t Byte;

      void helper(void);
      CONTENTS

      # Source has a macro at line 1, a variable at line 3, and a function definition at line 5.
      # Line numbers intentionally overlap with the header (both start at 1) to prove that
      # element_sequence order is governed by the + operand order — not by line-number sorting.
      source_string = <<~CONTENTS
      #define FOO 1

      int counter = 0;

      void helper(void) {
        return;
      }
      CONTENTS

      header_module = extract_from.call(header_string)
      source_module = extract_from.call(source_string)

      # Merge header-first (matching Partializer's extract_module_contents order)
      merged = header_module + source_module

      expect( merged.element_sequence.length ).to eq 5

      # Header items first, in their within-file order
      expect( merged.element_sequence[0] ).to be_a( CExtractorTypes::CStatement )
      expect( merged.element_sequence[0].text ).to include( "typedef uint8_t Byte;" )
      expect( merged.element_sequence[0].line_num ).to eq 1

      expect( merged.element_sequence[1] ).to be_a( CExtractorTypes::CFunctionDeclaration )
      expect( merged.element_sequence[1].name ).to eq 'helper'
      expect( merged.element_sequence[1].line_num ).to eq 3

      # Source items follow, also in their within-file order.
      # element_sequence[2].line_num == 1 — same as element_sequence[0].line_num — but
      # the source macro still appears after the header items, confirming that + ordering,
      # not line-number sorting, determines the sequence.
      expect( merged.element_sequence[2] ).to be_a( CExtractorTypes::CStatement )
      expect( merged.element_sequence[2].text ).to include( "#define FOO 1" )
      expect( merged.element_sequence[2].line_num ).to eq 1

      expect( merged.element_sequence[3] ).to be_a( CExtractorTypes::CVariableDeclaration )
      expect( merged.element_sequence[3].name ).to eq 'counter'
      expect( merged.element_sequence[3].line_num ).to eq 3

      expect( merged.element_sequence[4] ).to be_a( CExtractorTypes::CFunctionDefinition )
      expect( merged.element_sequence[4].name ).to eq 'helper'
      expect( merged.element_sequence[4].line_num ).to eq 5

      # Confirm the typed arrays are unaffected by the merge
      expect( merged.function_definitions.length  ).to eq 1
      expect( merged.function_declarations.length ).to eq 1
      expect( merged.variable_declarations.length ).to eq 1
      expect( merged.type_definitions.length      ).to eq 1
      expect( merged.macro_definitions.length     ).to eq 1
    end

    it "extracts function definitions and declarations with MSVC/GCC compiler extensions" do
      file_contents = <<~CONTENTS
        __declspec(dllexport) void exported_func(int x) { return; }
        int __cdecl cdecl_func(void) { return 0; }
        void __attribute__((noreturn)) fatal_func(const char* msg) { while(1); }
        static __forceinline int fast_add(int a, int b) { return a + b; }
        void plain_func(void) { }
      CONTENTS

      contents = extract_from.call(file_contents)

      expect(contents.function_definitions.length).to eq 5

      names = contents.function_definitions.map(&:name)
      expect(names).to include('exported_func', 'cdecl_func', 'fatal_func', 'fast_add', 'plain_func')

      # Signatures retain annotations verbatim
      exported = contents.function_definitions.find { |f| f.name == 'exported_func' }
      expect(exported.signature).to include('__declspec(dllexport)')

      fast = contents.function_definitions.find { |f| f.name == 'fast_add' }
      expect(fast.decorators).to include('static', '__forceinline')

      plain = contents.function_definitions.find { |f| f.name == 'plain_func' }
      expect(plain.decorators).to eq([])
    end

    it "extracts variable declarations with compiler extensions" do
      file_contents = <<~CONTENTS
        int counter __attribute__((aligned(16)));
        char buf[] __attribute__((section(".data")));
        struct Point my_pt __attribute__((aligned(4)));
        struct { int x; int y; } coords __attribute__((aligned(8)));
        __declspec(dllexport) extern int exported_var;
        int plain_var;
      CONTENTS

      contents = extract_from.call(file_contents)

      expect(contents.variable_declarations.length).to eq 6

      names = contents.variable_declarations.map(&:name)
      expect(names).to include('counter', 'buf', 'my_pt', 'coords', 'exported_var', 'plain_var')

      counter = contents.variable_declarations.find { |v| v.name == 'counter' }
      expect(counter.type).to eq('int')
      expect(counter.text).to include('__attribute__((aligned(16)))')

      buf = contents.variable_declarations.find { |v| v.name == 'buf' }
      expect(buf.type).to eq('char')

      exported = contents.variable_declarations.find { |v| v.name == 'exported_var' }
      expect(exported.name).to eq('exported_var')

      plain = contents.variable_declarations.find { |v| v.name == 'plain_var' }
      expect(plain.type).to eq('int')
      expect(plain.decorators).to eq([])
    end

    # A bare, top-level, semicolon-less macro invocation (an x-macro call expanding to
    # a full function definition once the macro itself is applied) has no leading '#',
    # no trailing ';', and no trailing '{' -- directives-only preprocessing never
    # expands it, so every extractor below sees it as literal, unexpanded text. Left
    # unhandled, whichever extractor's own forward scan reaches it next either
    # swallows it as a bogus prefix (the variable-declaration catch-all) or actively
    # misinterprets a later, unrelated '{' as its own body (the function-signature
    # scanners), silently losing whatever real content that brace belonged to (GH #1294).
    context "bare macro invocations" do
      it "should extract a bare macro-invocation-as-statement without corrupting the following variable declaration (GH #1294)" do
        file_contents = <<~CONTENTS
        #define MODULE_DEV_TYPE_CB(dev_type)      \\
            void MODULE_TrigCbDev##dev_type(void) \\
            {                                     \\
                MODULE_CommonTrigCb();            \\
            }

        MODULE_DEV_TYPE_CB(0)

        static AlertEntry_t s_alert_table[ALERT_MANAGER_MAX_ALERTS];
        CONTENTS

        contents = extract_from.call(file_contents)

        expect(contents.macro_invocations.length).to eq 1
        expect(contents.macro_invocations[0].text).to eq 'MODULE_DEV_TYPE_CB(0)'

        expect(contents.variable_declarations.length).to eq 1
        var = contents.variable_declarations[0]
        expect(var.name).to eq 's_alert_table'
        expect(var.type).to eq 'AlertEntry_t'
        expect(var.decorators).to eq ['static']

        # macro definition, then the bare invocation, then the variable -- in that order
        texts = contents.element_sequence.map { |item| item.is_a?(CExtractorTypes::CVariableDeclaration) ? item.name : item.text }
        expect(texts).to eq [
          "#define MODULE_DEV_TYPE_CB(dev_type)      \\\n    void MODULE_TrigCbDev##dev_type(void) \\\n    {                                     \\\n        MODULE_CommonTrigCb();            \\\n    }",
          'MODULE_DEV_TYPE_CB(0)',
          's_alert_table'
        ]
      end

      # Same reporter-shape fixture as above, but with a stray space before ## on the
      # continuation line -- simulating the exact cross-toolchain divergence issue #1294
      # originally reported (a real preprocessor's own reconstruction of this macro
      # text, not something Ceedling's extraction ever added on its own). Proves the
      # whitespace-canonicalization fix engages correctly end to end, through the real
      # backslash-continuation handling, not just in the isolated scanner unit tests.
      it "normalizes a preprocessor-inserted space before ## in a backslash-continued macro definition" do
        file_contents = <<~CONTENTS
        #define MODULE_DEV_TYPE_CB(dev_type)      \\
            void MODULE_TrigCbDev ##dev_type(void) \\
            {                                     \\
                MODULE_CommonTrigCb();            \\
            }

        MODULE_DEV_TYPE_CB(0)

        static AlertEntry_t s_alert_table[ALERT_MANAGER_MAX_ALERTS];
        CONTENTS

        contents = extract_from.call(file_contents)

        expect(contents.macro_definitions.length).to eq 1
        expect(contents.macro_definitions[0].text).to include('MODULE_TrigCbDev##dev_type')
        expect(contents.macro_definitions[0].text).not_to include('MODULE_TrigCbDev ##dev_type')
      end

      it "should extract a bare macro invocation without losing the typedef that follows it" do
        file_contents = <<~CONTENTS
        #define FOO(x) void bar##x(void) { }
        FOO(0)
        typedef struct { int a; } Baz_t;
        CONTENTS

        contents = extract_from.call(file_contents)

        expect(contents.macro_invocations.length).to eq 1
        expect(contents.macro_invocations[0].text).to eq 'FOO(0)'

        expect(contents.type_definitions.length).to eq 1
        expect(contents.type_definitions[0].text).to include('Baz_t')
      end

      it "should extract a bare macro invocation without losing the aggregate definition that follows it" do
        file_contents = <<~CONTENTS
        #define FOO(x) void bar##x(void) { }
        FOO(0)
        struct Baz { int a; };
        CONTENTS

        contents = extract_from.call(file_contents)

        expect(contents.macro_invocations.length).to eq 1
        expect(contents.aggregate_definitions.length).to eq 1
        expect(contents.aggregate_definitions[0].text).to include('struct Baz')
      end

      it "should extract a bare macro invocation without losing the real function definition that follows it" do
        file_contents = <<~CONTENTS
        #define FOO(x) void bar##x(void) { }
        FOO(0)
        void RealFunc(void) { }
        CONTENTS

        contents = extract_from.call(file_contents)

        expect(contents.macro_invocations.length).to eq 1
        expect(contents.function_definitions.length).to eq 1
        expect(contents.function_definitions[0].name).to eq 'RealFunc'
      end

      it "should extract a bare macro invocation without losing the real function declaration that follows it" do
        file_contents = <<~CONTENTS
        #define FOO(x) void bar##x(void) { }
        FOO(0)
        void RealFunc(void);
        CONTENTS

        contents = extract_from.call(file_contents)

        expect(contents.macro_invocations.length).to eq 1
        expect(contents.function_declarations.length).to eq 1
        expect(contents.function_declarations[0].name).to eq 'RealFunc'
      end

      it "should extract multiple consecutive bare macro invocations, each individually, without losing what follows" do
        file_contents = <<~CONTENTS
        #define FOO(x) void bar##x(void) { }
        FOO(0)
        FOO(1)
        FOO(2)
        static int x;
        CONTENTS

        contents = extract_from.call(file_contents)

        expect(contents.macro_invocations.map(&:text)).to eq ['FOO(0)', 'FOO(1)', 'FOO(2)']

        expect(contents.variable_declarations.length).to eq 1
        expect(contents.variable_declarations[0].name).to eq 'x'
        expect(contents.variable_declarations[0].decorators).to eq ['static']
      end

      # A bare invocation with genuinely nothing after it (not even a newline) is
      # indistinguishable, at extraction time, from "not enough of the file has been
      # read yet" -- unterminated trailing content is already silently dropped for
      # every other feature type in this codebase (a file ending in `int x` with no
      # trailing ';' is dropped the same way), so this is a pre-existing, accepted
      # limitation this fix doesn't change, not a new gap it introduces.
      it "silently drops a bare macro invocation trailing at the very end of the file with nothing after it, consistent with every other unterminated trailing construct" do
        file_contents = "static int x;\n#define FOO(dev) void bar##dev(void) { }\nFOO(0)"

        contents = extract_from.call(file_contents)

        expect(contents.variable_declarations.length).to eq 1
        expect(contents.variable_declarations[0].name).to eq 'x'

        expect(contents.macro_invocations.length).to eq 0
      end

      it "still silently drops a trailing bare macro invocation even with a trailing newline after it -- a newline alone doesn't resolve the chunk-boundary ambiguity" do
        file_contents = <<~CONTENTS
        static int x;
        #define FOO(dev) void bar##dev(void) { }
        FOO(0)
        CONTENTS

        contents = extract_from.call(file_contents)

        expect(contents.variable_declarations.length).to eq 1
        expect(contents.variable_declarations[0].name).to eq 'x'

        expect(contents.macro_invocations.length).to eq 0
      end

      it "extracts a bare macro invocation followed by further real (non-deadspace) content" do
        file_contents = <<~CONTENTS
        static int x;
        #define FOO(dev) void bar##dev(void) { }
        FOO(0)
        static int y;
        CONTENTS

        contents = extract_from.call(file_contents)

        expect(contents.variable_declarations.map(&:name)).to eq ['x', 'y']
        expect(contents.macro_invocations.length).to eq 1
        expect(contents.macro_invocations[0].text).to eq 'FOO(0)'
      end
    end

    # A function pointer's name sits inside parentheses, which a bare macro invocation's shape
    # also starts with. Each declaration must arrive whole, as one element.
    context "with function-pointer declarators" do
      it "extracts a function-pointer variable as one variable" do
        expect( sequence_of( "int (*g_hook)(int);\n" ) ).to eq [['CVariableDeclaration', 'int (*g_hook)(int);']]
      end

      it "extracts an initialized function-pointer variable as one variable" do
        expect( sequence_of( "int (*g_hook)(int) = 0;\n" ) ).to eq [['CVariableDeclaration', 'int (*g_hook)(int) = 0;']]
      end

      it "extracts a function-pointer variable whose base type is a typedef as one variable" do
        expect( sequence_of( "result_t (*on_done)(int);\n" ) ).to eq [['CVariableDeclaration', 'result_t (*on_done)(int);']]
      end

      it "extracts a constant function-pointer variable as one variable" do
        expect( sequence_of( "int (*const k_hook)(int) = bump;\n" ) ).to eq [['CVariableDeclaration', 'int (*const k_hook)(int) = bump;']]
      end

      it "extracts an initialized pointer to an array as one variable" do
        expect( sequence_of( "int (*g_row)[4] = 0;\n" ) ).to eq [['CVariableDeclaration', 'int (*g_row)[4] = 0;']]
      end

      it "extracts a declaration of a function returning a function pointer as one declaration" do
        expect( sequence_of( "int (*ticker_get(void))(int);\n" ) ).to eq [['CFunctionDeclaration', 'int (*ticker_get(void))(int);']]
      end

      it "extracts a definition of a function returning a function pointer as one definition" do
        expect( sequence_of( "int (*ticker_get(void))(int) { return bump; }\n" ) ).to eq [['CFunctionDefinition', 'int (*ticker_get(void))(int)']]
      end
    end

    # A struct, union or enum keyword can lead a variable or a function as well as a type. Each
    # statement must arrive as what it declares.
    context "with a struct, union or enum keyword leading the statement" do
      it "extracts an initialized struct variable as a variable" do
        expect( sequence_of( "struct ops g_ops = { 1 };\n" ) ).to eq [['CVariableDeclaration', 'struct ops g_ops = { 1 };']]
      end

      it "extracts an initialized union variable as a variable" do
        expect( sequence_of( "union u g_u = { 0 };\n" ) ).to eq [['CVariableDeclaration', 'union u g_u = { 0 };']]
      end

      it "extracts an initialized array of struct pointers as a variable" do
        expect( sequence_of( "struct ops *tbl[] = { &a1, &b1 };\n" ) ).to eq [['CVariableDeclaration', 'struct ops *tbl[] = { &a1, &b1 };']]
      end

      it "extracts a table of designated function pointers as a variable" do
        expect( sequence_of( "struct drv_ops g_drv = { .init = drv_init, .read = drv_read };\n" ) ).to eq [['CVariableDeclaration', 'struct drv_ops g_drv = { .init = drv_init, .read = drv_read };']]
      end

      it "extracts an initialized array of structs as a variable" do
        expect( sequence_of( "struct ops g_arr[2] = { {1}, {2} };\n" ) ).to eq [['CVariableDeclaration', 'struct ops g_arr[2] = { {1}, {2} };']]
      end

      it "extracts a function returning a struct pointer, with a stray ';' after its body, as a function" do
        expect( sequence_of( "struct ops *make_ops(void) { return &k; };\nint after;\n" ) ).to eq [['CFunctionDefinition', 'struct ops *make_ops(void)'], ['CVariableDeclaration', 'int after;']]
      end

      it "extracts a function returning a struct, with a stray ';' after its body, as a function" do
        expect( sequence_of( "struct ops make_v(void) { struct ops o = { 1 }; return o; };\n" ) ).to eq [['CFunctionDefinition', 'struct ops make_v(void)']]
      end

      # A feature can end at the buffer's last byte, before the stray ';' after it is read
      (1..8).each do |chunk_size|
        it "reads past a stray ';' after a function body with #{chunk_size}-byte chunks" do
          expect( sequence_of( "struct ops *make_ops(void) { return 0; };\nint after;\n", chunk_size: chunk_size ) ).to eq [['CFunctionDefinition', 'struct ops *make_ops(void)'], ['CVariableDeclaration', 'int after;']]
          expect( sequence_of( "int f(void) { return 0; };\nint after;\n", chunk_size: chunk_size ) ).to eq [['CFunctionDefinition', 'int f(void)'], ['CVariableDeclaration', 'int after;']]
        end
      end

      it "extracts a type with an attribute after its body as a type" do
        expect( sequence_of( "struct pk { char c; int i; } __attribute__((packed));\nint after;\n" ) ).to eq [['CStatement', 'struct pk { char c; int i; } __attribute__((packed));'], ['CVariableDeclaration', 'int after;']]
      end
    end

    # A type specifier that takes parentheses has a macro invocation's shape. Each declaration
    # must still arrive whole, as one element.
    context "with type specifiers that take parentheses" do
      [
        ['typeof(int) g_t;',      'CVariableDeclaration', 'typeof(int) g_t;'],
        ['_Atomic(int) g_a;',     'CVariableDeclaration', '_Atomic(int) g_a;'],
        ['_Alignas(8) int g_al;', 'CVariableDeclaration', '_Alignas(8) int g_al;'],
        ['typeof(*g_pp) g_q;',    'CVariableDeclaration', 'typeof(*g_pp) g_q;'],
        ['typeof(int) tf(void);', 'CFunctionDeclaration', 'typeof(int) tf(void);']
      ].each do |content, kind, text|
        it "extracts `#{content}` as one element" do
          expect( sequence_of( "#{content}\n" ) ).to eq [[kind, text]]
        end
      end
    end

    # An asm label's ')' ends a declaration as a parameter list does. A variable with one must
    # still arrive as a variable, and a function with one as a function.
    context "with C23 attributes" do
      it "reads each feature a C23 attribute leads and every feature after it" do
        content = <<~CONTENTS
          [[nodiscard]] static int f(void) { return 0; }
          [[nodiscard]] int g(void);
          [[maybe_unused]] static int count;
          int h(void) { return 1; }
        CONTENTS

        expect( sequence_of( content ) ).to eq [
          ['CFunctionDefinition',  '[[nodiscard]] static int f(void)'],
          ['CFunctionDeclaration', '[[nodiscard]] int g(void);'],
          ['CVariableDeclaration', '[[maybe_unused]] int count;'],
          ['CFunctionDefinition',  'int h(void)']
        ]
      end
    end

    context "with asm labels" do
      it "extracts each declaration as the element it declares" do
        content = "int g_s asm(\"g_sym\");\nint f(void) __asm(\"f_sym\");\nint f2(void) MY_API asm(\"f2_sym\");\n" \
                  "asm(\".globl top_sym\");\nint after_fn(void) { return 7; }\n"

        expect( sequence_of( content ) ).to eq [
          ['CVariableDeclaration', 'int g_s asm("g_sym");'],
          ['CFunctionDeclaration', 'int f(void) __asm("f_sym");'],
          ['CFunctionDeclaration', 'int f2(void) MY_API asm("f2_sym");'],
          ['CVariableDeclaration', 'asm(".globl top_sym");'],
          ['CFunctionDefinition', 'int after_fn(void)']
        ]
      end
    end

    # A chunk may end at a lone '/', which may open a comment the next chunk holds
    context "with a comment after a macro invocation's arguments" do
      (1..24).each do |chunk_size|
        it "reads the same elements with #{chunk_size}-byte chunks" do
          content = "FOO(x) /* c */;\nint after;\n"
          expect( sequence_of( content, chunk_size: chunk_size ) ).to eq sequence_of( content )
        end
      end
    end

    # Fallback preprocessing leaves comments in place, inside declarations too
    context "with comments inside declarations" do
      it "reads on past a declaration that ends in a comment" do
        expect( sequence_of( "int g_m /* count */;\nint after_fn(void) { return 7; }\n" ) ).to eq [['CVariableDeclaration', 'int g_m ;'], ['CFunctionDefinition', 'int after_fn(void)']]
      end

      it "reads a declaration whose initializer follows a line comment" do
        expect( sequence_of( "int g_n // count\n    = 3;\nint after;\n" ) ).to eq [['CVariableDeclaration', 'int g_n = 3;'], ['CVariableDeclaration', 'int after;']]
      end

      # A comment after a feature can run past the buffer's end, so it must be read again whole
      (1..24).each do |chunk_size|
        it "reads past a comment after a declaration with #{chunk_size}-byte chunks" do
          expect( sequence_of( "int g_last; // trailing; comment\nint after;\n", chunk_size: chunk_size ) ).to eq [['CVariableDeclaration', 'int g_last;'], ['CVariableDeclaration', 'int after;']]
          expect( sequence_of( "int g_last; /* trailing; comment */\nint after;\n", chunk_size: chunk_size ) ).to eq [['CVariableDeclaration', 'int g_last;'], ['CVariableDeclaration', 'int after;']]
        end
      end
    end

    # A declaration that defines its type holds two things. The type is defined once, ahead of its
    # variables in element_sequence, and every variable of the statement names that one record.
    context "a declaration that defines its type" do
      it "records the type as an aggregate ahead of the variables that share it" do
        contents = extract_from.call( "int before;\nstatic struct pair { int a[2]; } g_p1, *g_p2 = &g_p1;\n" )
        type     = contents.aggregate_definitions.first

        expect( type ).to have_attributes( text: 'struct pair { int a[2]; };', kind: :aggregate, tag: 'pair', line_num: 2 )
        expect( contents.element_sequence.map( &:class ) ).to eq [
          CExtractorTypes::CVariableDeclaration, CExtractorTypes::CStatement,
          CExtractorTypes::CVariableDeclaration, CExtractorTypes::CVariableDeclaration
        ]
        expect( contents.variable_declarations.drop( 1 ).map( &:defined_type ) ).to all( equal( type ) )
      end

      # The type held a member's array size, which no longer reads as the variable's own
      it "reads each variable of the statement without the type's body" do
        vars = extract_from.call( "static struct pair { int a[2]; } g_p1, *g_p2 = &g_p1;\n" ).variable_declarations

        expect( vars.map { |v| [v.name, v.type, v.text, v.array_suffix, v.decorators] } ).to eq [
          ['g_p1', '', 'g_p1;', '', ['static']],
          ['g_p2', '*', '*g_p2 = &g_p1;', '', ['static']]
        ]
      end

      it "reads an anonymous struct, union or enum with no tag" do
        contents = extract_from.call( "static struct { int n; } s;\nunion { int i; float f; } u;\nstatic enum { IDLE, RUN } e;\n" )

        expect( contents.aggregate_definitions.map { |t| [t.text, t.tag] } ).to eq [
          ['struct { int n; };', nil], ['union { int i; float f; };', nil], ['enum { IDLE, RUN };', nil]
        ]
        expect( contents.variable_declarations.map( &:name ) ).to eq ['s', 'u', 'e']
      end

      # An extension after the body belongs to the type, and one after the name to the variable
      it "keeps each extension with what it follows" do
        vars = extract_from.call( "struct { char c; int i; } __attribute__((packed)) s_pk __attribute__((unused));\n" ).variable_declarations

        expect( vars.first.defined_type.text ).to eq 'struct { char c; int i; } __attribute__((packed));'
        expect( vars.first.text ).to eq 's_pk __attribute__((unused));'
      end

      it "keeps an initializer, an asm label and a qualifier with the variable" do
        var = extract_from.call( "static const struct ops { int a; } g_ops asm(\"sym\") = { 1 };\n" ).variable_declarations.first

        expect( var ).to have_attributes( name: 'g_ops', decorators: ['static', 'const'], asm_label: 'asm("sym")', text: 'g_ops asm("sym") = { 1 };' )
      end

      it "reads a struct whose members are function pointers" do
        var = extract_from.call( "static struct drv { int (*read)(void); void (*write)(int); } s_drv;\n" ).variable_declarations.first

        expect( var ).to have_attributes( name: 's_drv', declarator: nil )
        expect( var.defined_type.tag ).to eq 'drv'
      end

      it "reads an enum with an underlying type" do
        type = extract_from.call( "enum mode : unsigned char { OFF, ON } g_mode;\n" ).aggregate_definitions.first

        expect( type ).to have_attributes( text: 'enum mode : unsigned char { OFF, ON };', tag: 'mode' )
      end
    end

    context "a statement that names a type" do
      it "reads a forward declaration as a type statement, never a variable" do
        contents = extract_from.call( "struct node;\nunion word;\n" )

        expect( contents.aggregate_definitions.map { |t| [t.text, t.tag] } ).to eq [['struct node;', 'node'], ['union word;', 'word']]
        expect( contents.variable_declarations ).to be_empty
      end

      it "records the tag and the name a typedef gives a struct" do
        contents = extract_from.call( "typedef struct node node_t;\ntypedef struct item { int v; } item_t;\ntypedef int count_t;\n" )

        expect( contents.type_definitions.map { |t| [t.kind, t.tag, t.type_name] } ).to eq [
          [:typedef, 'node', 'node_t'], [:typedef, 'item', 'item_t'], [:typedef, nil, nil]
        ]
      end

      it "records each statement's kind" do
        contents = extract_from.call( "#define N 1\ntypedef int n_t;\nstruct s { int a; };\nint n;\n" )

        expect( contents.element_sequence.grep( CExtractorTypes::CStatement ).map( &:kind ) ).to eq [:macro, :typedef, :aggregate]
      end
    end

  end

end
