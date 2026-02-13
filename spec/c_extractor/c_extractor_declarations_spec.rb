# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/c_extractor/c_extractor_declarations'
require 'stringio'

describe CExtractorDeclarations do

  ###
  ### try_extract_variable()
  ###

  describe "#try_extract_variable" do
    # Helper to create extractor and test variable extraction
    let(:extract_variable) do
      ->(content, max_line_length=1000) do
        scanner = StringScanner.new(content)
        declarations = CExtractorDeclarations.new(max_line_length)
        success, variable = declarations.try_extract_variable(scanner)
        return [success, variable, scanner.pos, scanner.rest]
      end
    end

    context "simple variable declarations" do
      it "extracts simple int variable" do
        content = "int x;"
        success, variable, pos, rest = extract_variable.call(content)
        
        expect(success).to be true
        expect(variable).to eq("int x;")
        expect(pos).to eq(6)
        expect(rest).to eq("")
      end

      it "extracts simple char variable" do
        content = "char c;"
        success, variable, pos, rest = extract_variable.call(content)
        
        expect(success).to be true
        expect(variable).to eq("char c;")
        expect(pos).to eq(7)
        expect(rest).to eq("")
      end

      it "extracts simple float variable" do
        content = "float value;"
        success, variable, pos, rest = extract_variable.call(content)
        
        expect(success).to be true
        expect(variable).to eq("float value;")
        expect(pos).to eq(12)
        expect(rest).to eq("")
      end

      it "extracts simple double variable" do
        content = "double pi;"
        success, variable, pos, rest = extract_variable.call(content)
        
        expect(success).to be true
        expect(variable).to eq("double pi;")
        expect(pos).to eq(10)
        expect(rest).to eq("")
      end

      it "extracts variable with underscore in name" do
        content = "int my_variable;"
        success, variable, pos, rest = extract_variable.call(content)
        
        expect(success).to be true
        expect(variable).to eq("int my_variable;")
        expect(pos).to eq(16)
        expect(rest).to eq("")
      end

      it "extracts variable with camelCase name" do
        content = "int myVariable;"
        success, variable, pos, rest = extract_variable.call(content)
        
        expect(success).to be true
        expect(variable).to eq("int myVariable;")
        expect(pos).to eq(15)
        expect(rest).to eq("")
      end

      it "extracts variable with number in name" do
        content = "int value123;"
        success, variable, pos, rest = extract_variable.call(content)
        
        expect(success).to be true
        expect(variable).to eq("int value123;")
        expect(pos).to eq(13)
        expect(rest).to eq("")
      end
    end

    context "pointer variable declarations" do
      it "extracts pointer variable with asterisk next to type" do
        content = "int* ptr;"
        success, variable, pos, rest = extract_variable.call(content)
        
        expect(success).to be true
        expect(variable).to eq("int* ptr;")
        expect(pos).to eq(9)
        expect(rest).to eq("")
      end

      it "extracts pointer variable with asterisk next to name" do
        content = "int *ptr;"
        success, variable, pos, rest = extract_variable.call(content)
        
        expect(success).to be true
        expect(variable).to eq("int *ptr;")
        expect(pos).to eq(9)
        expect(rest).to eq("")
      end

      it "extracts pointer variable with asterisk in middle" do
        content = "int * ptr;"
        success, variable, pos, rest = extract_variable.call(content)
        
        expect(success).to be true
        expect(variable).to eq("int * ptr;")
        expect(pos).to eq(10)
        expect(rest).to eq("")
      end

      it "extracts double pointer variable" do
        content = "char** buffer;"
        success, variable, pos, rest = extract_variable.call(content)
        
        expect(success).to be true
        expect(variable).to eq("char** buffer;")
        expect(pos).to eq(14)
        expect(rest).to eq("")
      end

      it "extracts triple pointer variable" do
        content = "void*** ptr;"
        success, variable, pos, rest = extract_variable.call(content)
        
        expect(success).to be true
        expect(variable).to eq("void*** ptr;")
        expect(pos).to eq(12)
        expect(rest).to eq("")
      end

      it "extracts pointer to const" do
        content = "const int* ptr;"
        success, variable, pos, rest = extract_variable.call(content)
        
        expect(success).to be true
        expect(variable).to eq("const int* ptr;")
        expect(pos).to eq(15)
        expect(rest).to eq("")
      end

      it "extracts const pointer" do
        content = "int* const ptr;"
        success, variable, pos, rest = extract_variable.call(content)
        
        expect(success).to be true
        expect(variable).to eq("int* const ptr;")
        expect(pos).to eq(15)
        expect(rest).to eq("")
      end

      it "extracts const pointer to const" do
        content = "const int* const ptr;"
        success, variable, pos, rest = extract_variable.call(content)
        
        expect(success).to be true
        expect(variable).to eq("const int* const ptr;")
        expect(pos).to eq(21)
        expect(rest).to eq("")
      end
    end

    context "array variable declarations" do
      it "extracts simple array" do
        content = "int arr[10];"
        success, variable, pos, rest = extract_variable.call(content)
        
        expect(success).to be true
        expect(variable).to eq("int arr[10];")
        expect(pos).to eq(12)
        expect(rest).to eq("")
      end

      it "extracts array without size" do
        content = "int arr[];"
        success, variable, pos, rest = extract_variable.call(content)
        
        expect(success).to be true
        expect(variable).to eq("int arr[];")
        expect(pos).to eq(10)
        expect(rest).to eq("")
      end

      it "extracts multi-dimensional array" do
        content = "int matrix[3][4];"
        success, variable, pos, rest = extract_variable.call(content)
        
        expect(success).to be true
        expect(variable).to eq("int matrix[3][4];")
        expect(pos).to eq(17)
        expect(rest).to eq("")
      end

      it "extracts three-dimensional array" do
        content = "int cube[2][3][4];"
        success, variable, pos, rest = extract_variable.call(content)
        
        expect(success).to be true
        expect(variable).to eq("int cube[2][3][4];")
        expect(pos).to eq(18)
        expect(rest).to eq("")
      end

      it "extracts array of pointers" do
        content = "char* strings[10];"
        success, variable, pos, rest = extract_variable.call(content)
        
        expect(success).to be true
        expect(variable).to eq("char* strings[10];")
        expect(pos).to eq(18)
        expect(rest).to eq("")
      end

      it "extracts pointer to array" do
        content = "int (*ptr)[10];"
        success, variable, pos, rest = extract_variable.call(content)
        
        expect(success).to be true
        expect(variable).to eq("int (*ptr)[10];")
        expect(pos).to eq(15)
        expect(rest).to eq("")
      end

      it "extracts array with expression size" do
        content = "int arr[MAX_SIZE];"
        success, variable, pos, rest = extract_variable.call(content)
        
        expect(success).to be true
        expect(variable).to eq("int arr[MAX_SIZE];")
        expect(pos).to eq(18)
        expect(rest).to eq("")
      end

      it "extracts array with arithmetic expression size" do
        content = "int arr[10 + 5];"
        success, variable, pos, rest = extract_variable.call(content)
        
        expect(success).to be true
        expect(variable).to eq("int arr[10 + 5];")
        expect(pos).to eq(16)
        expect(rest).to eq("")
      end
    end

    context "array variable initialization" do
      it "extracts array with simple initializer list" do
        content = "int arr[] = {1, 2, 3};"
        success, variable, pos, rest = extract_variable.call(content)
        
        expect(success).to be true
        expect(variable).to eq("int arr[] = {1, 2, 3};")
        expect(pos).to eq(22)
        expect(rest).to eq("")
      end

      it "extracts array with sized initializer list" do
        content = "int arr[5] = {1, 2, 3, 4, 5};"
        success, variable, pos, rest = extract_variable.call(content)
        
        expect(success).to be true
        expect(variable).to eq("int arr[5] = {1, 2, 3, 4, 5};")
        expect(pos).to eq(29)
        expect(rest).to eq("")
      end

      it "extracts array with partial initializer list" do
        content = "int arr[10] = {1, 2, 3};"
        success, variable, pos, rest = extract_variable.call(content)
        
        expect(success).to be true
        expect(variable).to eq("int arr[10] = {1, 2, 3};")
        expect(pos).to eq(24)
        expect(rest).to eq("")
      end

      it "extracts array with empty initializer list" do
        content = "int arr[5] = {};"
        success, variable, pos, rest = extract_variable.call(content)
        
        expect(success).to be true
        expect(variable).to eq("int arr[5] = {};")
        expect(pos).to eq(16)
        expect(rest).to eq("")
      end

      it "extracts char array with string literal" do
        content = 'char str[] = "hello";'
        success, variable, pos, rest = extract_variable.call(content)
        
        expect(success).to be true
        expect(variable).to eq('char str[] = "hello";')
        expect(pos).to eq(21)
        expect(rest).to eq("")
      end

      it "extracts char array with sized string literal" do
        content = 'char str[10] = "hello";'
        success, variable, pos, rest = extract_variable.call(content)
        
        expect(success).to be true
        expect(variable).to eq('char str[10] = "hello";')
        expect(pos).to eq(23)
        expect(rest).to eq("")
      end

      it "extracts multi-dimensional array with nested initializers" do
        content = "int matrix[2][3] = {{1, 2, 3}, {4, 5, 6}};"
        success, variable, pos, rest = extract_variable.call(content)
        
        expect(success).to be true
        expect(variable).to eq("int matrix[2][3] = {{1, 2, 3}, {4, 5, 6}};")
        expect(pos).to eq(42)
        expect(rest).to eq("")
      end

      it "extracts array with designated initializers" do
        content = "int arr[5] = {[0] = 1, [4] = 5};"
        success, variable, pos, rest = extract_variable.call(content)
        
        expect(success).to be true
        expect(variable).to eq("int arr[5] = {[0] = 1, [4] = 5};")
        expect(pos).to eq(32)
        expect(rest).to eq("")
      end

      it "extracts array with negative values" do
        content = "int arr[] = {-1, -2, -3};"
        success, variable, pos, rest = extract_variable.call(content)
        
        expect(success).to be true
        expect(variable).to eq("int arr[] = {-1, -2, -3};")
        expect(pos).to eq(25)
        expect(rest).to eq("")
      end

      it "extracts float array with decimal values" do
        content = "float arr[] = {1.5, 2.7, 3.14};"
        success, variable, pos, rest = extract_variable.call(content)
        
        expect(success).to be true
        expect(variable).to eq("float arr[] = {1.5, 2.7, 3.14};")
        expect(pos).to eq(31)
        expect(rest).to eq("")
      end

      it "extracts array with hex values" do
        content = "int arr[] = {0x01, 0xFF, 0xAB};"
        success, variable, pos, rest = extract_variable.call(content)
        
        expect(success).to be true
        expect(variable).to eq("int arr[] = {0x01, 0xFF, 0xAB};")
        expect(pos).to eq(31)
        expect(rest).to eq("")
      end

      it "extracts const array with initializer" do
        content = "const int arr[] = {1, 2, 3};"
        success, variable, pos, rest = extract_variable.call(content)
        
        expect(success).to be true
        expect(variable).to eq("const int arr[] = {1, 2, 3};")
        expect(pos).to eq(28)
        expect(rest).to eq("")
      end

      it "extracts static array with initializer" do
        content = "static int arr[] = {10, 20, 30};"
        success, variable, pos, rest = extract_variable.call(content)
        
        expect(success).to be true
        expect(variable).to eq("static int arr[] = {10, 20, 30};")
        expect(pos).to eq(32)
        expect(rest).to eq("")
      end

      it "extracts array of pointers with initializer" do
        content = 'char* arr[] = {"hello", "world"};'
        success, variable, pos, rest = extract_variable.call(content)
        
        expect(success).to be true
        expect(variable).to eq('char* arr[] = {"hello", "world"};')
        expect(pos).to eq(33)
        expect(rest).to eq("")
      end

      it "extracts array with macro values" do
        content = "int arr[] = {MAX_VALUE, MIN_VALUE};"
        success, variable, pos, rest = extract_variable.call(content)
        
        expect(success).to be true
        expect(variable).to eq("int arr[] = {MAX_VALUE, MIN_VALUE};")
        expect(pos).to eq(35)
        expect(rest).to eq("")
      end

      it "extracts array with expression values" do
        content = "int arr[] = {1 + 2, 3 * 4, 5 - 1};"
        success, variable, pos, rest = extract_variable.call(content)
        
        expect(success).to be true
        expect(variable).to eq("int arr[] = {1 + 2, 3 * 4, 5 - 1};")
        expect(pos).to eq(34)
        expect(rest).to eq("")
      end
    end

    context "qualified type declarations" do
      it "extracts const variable" do
        content = "const int value;"
        success, variable, pos, rest = extract_variable.call(content)
        
        expect(success).to be true
        expect(variable).to eq("const int value;")
        expect(pos).to eq(16)
        expect(rest).to eq("")
      end

      it "extracts volatile variable" do
        content = "volatile int flag;"
        success, variable, pos, rest = extract_variable.call(content)
        
        expect(success).to be true
        expect(variable).to eq("volatile int flag;")
        expect(pos).to eq(18)
        expect(rest).to eq("")
      end

      it "extracts const volatile variable" do
        content = "const volatile int reg;"
        success, variable, pos, rest = extract_variable.call(content)
        
        expect(success).to be true
        expect(variable).to eq("const volatile int reg;")
        expect(pos).to eq(23)
        expect(rest).to eq("")
      end

      it "extracts static variable" do
        content = "static int counter;"
        success, variable, pos, rest = extract_variable.call(content)
        
        expect(success).to be true
        expect(variable).to eq("static int counter;")
        expect(pos).to eq(19)
        expect(rest).to eq("")
      end

      it "extracts extern variable" do
        content = "extern int global;"
        success, variable, pos, rest = extract_variable.call(content)
        
        expect(success).to be true
        expect(variable).to eq("extern int global;")
        expect(pos).to eq(18)
        expect(rest).to eq("")
      end

      it "extracts static const variable" do
        content = "static const int MAX;"
        success, variable, pos, rest = extract_variable.call(content)
        
        expect(success).to be true
        expect(variable).to eq("static const int MAX;")
        expect(pos).to eq(21)
        expect(rest).to eq("")
      end

      it "extracts register variable" do
        content = "register int fast;"
        success, variable, pos, rest = extract_variable.call(content)
        
        expect(success).to be true
        expect(variable).to eq("register int fast;")
        expect(pos).to eq(18)
        expect(rest).to eq("")
      end
    end

  end
end