# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/c_extractor/c_extractor_declarations'
require 'ceedling/c_extractor/c_extractor_code_text'
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
        declarations = CExtractorDeclarations.new({ c_extractor_code_text: CExtractorCodeText.new() })
        declarations.setup()
        declarations.max_line_length = max_line_length
        success, variable = declarations.try_extract_variable(scanner)
        return [success, variable, scanner.pos, scanner.rest]
      end
    end

    # Shorthand to check a single-variable result
    def check_single(variable, name:, type:, decorators: [], text:, array_suffix: '')
      expect(variable).to be_an(Array)
      expect(variable.length).to eq 1
      v = variable[0]
      expect(v.name).to eq name
      expect(v.type).to eq type
      expect(v.decorators).to eq decorators
      expect(v.text).to eq text
      expect(v.array_suffix).to eq array_suffix
    end

    context "simple variable declarations" do
      it "extracts simple int variable" do
        content = "int x;"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 'x', type: 'int', text: 'int x;')
        expect(variable[0].original).to eq 'int x;'
        expect(pos).to eq(6)
        expect(rest).to eq("")
      end

      it "extracts simple char variable" do
        content = "char c;"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 'c', type: 'char', text: 'char c;')
        expect(pos).to eq(7)
        expect(rest).to eq("")
      end

      it "extracts simple float variable" do
        content = "float value;"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 'value', type: 'float', text: 'float value;')
        expect(pos).to eq(12)
        expect(rest).to eq("")
      end

      it "extracts simple double variable" do
        content = "double pi;"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 'pi', type: 'double', text: 'double pi;')
        expect(pos).to eq(10)
        expect(rest).to eq("")
      end

      it "extracts variable with underscore in name" do
        content = "int my_variable;"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 'my_variable', type: 'int', text: 'int my_variable;')
        expect(pos).to eq(16)
        expect(rest).to eq("")
      end

      it "extracts variable with camelCase name" do
        content = "int myVariable;"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 'myVariable', type: 'int', text: 'int myVariable;')
        expect(pos).to eq(15)
        expect(rest).to eq("")
      end

      it "extracts variable with number in name" do
        content = "int value123;"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 'value123', type: 'int', text: 'int value123;')
        expect(pos).to eq(13)
        expect(rest).to eq("")
      end
    end

    context "pointer variable declarations" do
      it "extracts pointer variable with asterisk next to type" do
        content = "int* ptr;"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 'ptr', type: 'int*', text: 'int* ptr;')
        expect(pos).to eq(9)
        expect(rest).to eq("")
      end

      it "extracts pointer variable with asterisk next to name" do
        content = "int *ptr;"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 'ptr', type: 'int *', text: 'int *ptr;')
        expect(pos).to eq(9)
        expect(rest).to eq("")
      end

      it "extracts pointer variable with asterisk in middle" do
        content = "int * ptr;"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 'ptr', type: 'int *', text: 'int * ptr;')
        expect(pos).to eq(10)
        expect(rest).to eq("")
      end

      it "extracts double pointer variable" do
        content = "char** buffer;"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 'buffer', type: 'char**', text: 'char** buffer;')
        expect(pos).to eq(14)
        expect(rest).to eq("")
      end

      it "extracts triple pointer variable" do
        content = "void*** ptr;"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 'ptr', type: 'void***', text: 'void*** ptr;')
        expect(pos).to eq(12)
        expect(rest).to eq("")
      end

      it "extracts pointer to const" do
        content = "const int* ptr;"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 'ptr', type: 'int*', decorators: ['const'], text: 'int* ptr;')
        expect(pos).to eq(15)
        expect(rest).to eq("")
      end

      it "extracts const pointer" do
        content = "int* const ptr;"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        # `const` is not a leading decorator here (int* comes first), no stripping
        expect(variable.length).to eq 1
        expect(variable[0].name).to eq 'ptr'
        expect(variable[0].decorators).to eq []
        expect(variable[0].text).to eq 'int* const ptr;'
        expect(pos).to eq(15)
        expect(rest).to eq("")
      end

      it "extracts const pointer to const" do
        content = "const int* const ptr;"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        # Leading `const` is a decorator; gsub removes all `const` occurrences
        check_single(variable, name: 'ptr', type: 'int*', decorators: ['const'], text: 'int* ptr;')
        expect(pos).to eq(21)
        expect(rest).to eq("")
      end
    end

    context "array variable declarations" do
      it "extracts simple array" do
        content = "int arr[10];"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 'arr', type: 'int', text: 'int arr[10];', array_suffix: '[10]')
        expect(pos).to eq(12)
        expect(rest).to eq("")
      end

      it "extracts array without size" do
        content = "int arr[];"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 'arr', type: 'int', text: 'int arr[];', array_suffix: '[]')
        expect(pos).to eq(10)
        expect(rest).to eq("")
      end

      it "extracts multi-dimensional array" do
        content = "int matrix[3][4];"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 'matrix', type: 'int', text: 'int matrix[3][4];', array_suffix: '[3][4]')
        expect(pos).to eq(17)
        expect(rest).to eq("")
      end

      it "extracts three-dimensional array" do
        content = "int cube[2][3][4];"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 'cube', type: 'int', text: 'int cube[2][3][4];', array_suffix: '[2][3][4]')
        expect(pos).to eq(18)
        expect(rest).to eq("")
      end

      it "extracts array of pointers" do
        content = "char* strings[10];"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 'strings', type: 'char*', text: 'char* strings[10];', array_suffix: '[10]')
        expect(pos).to eq(18)
        expect(rest).to eq("")
      end

      it "extracts pointer to array" do
        content = "int (*ptr)[10];"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 'ptr', type: 'int', text: 'int (*ptr)[10];')
        expect(pos).to eq(15)
        expect(rest).to eq("")
      end

      it "extracts array with expression size" do
        content = "int arr[MAX_SIZE];"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 'arr', type: 'int', text: 'int arr[MAX_SIZE];', array_suffix: '[MAX_SIZE]')
        expect(pos).to eq(18)
        expect(rest).to eq("")
      end

      it "extracts array with arithmetic expression size" do
        content = "int arr[10 + 5];"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 'arr', type: 'int', text: 'int arr[10 + 5];', array_suffix: '[10 + 5]')
        expect(pos).to eq(16)
        expect(rest).to eq("")
      end
    end

    context "array variable initialization" do
      it "extracts array with simple initializer list" do
        content = "int arr[] = {1, 2, 3};"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 'arr', type: 'int', text: 'int arr[] = {1, 2, 3};', array_suffix: '[]')
        expect(pos).to eq(22)
        expect(rest).to eq("")
      end

      it "extracts array with sized initializer list" do
        content = "int arr[5] = {1, 2, 3, 4, 5};"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 'arr', type: 'int', text: 'int arr[5] = {1, 2, 3, 4, 5};', array_suffix: '[5]')
        expect(pos).to eq(29)
        expect(rest).to eq("")
      end

      it "extracts array with partial initializer list" do
        content = "int arr[10] = {1, 2, 3};"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 'arr', type: 'int', text: 'int arr[10] = {1, 2, 3};', array_suffix: '[10]')
        expect(pos).to eq(24)
        expect(rest).to eq("")
      end

      it "extracts array with empty initializer list" do
        content = "int arr[5] = {};"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 'arr', type: 'int', text: 'int arr[5] = {};', array_suffix: '[5]')
        expect(pos).to eq(16)
        expect(rest).to eq("")
      end

      it "extracts char array with string literal" do
        content = 'char str[] = "hello";'
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 'str', type: 'char', text: 'char str[] = "hello";', array_suffix: '[]')
        expect(pos).to eq(21)
        expect(rest).to eq("")
      end

      it "extracts char array with sized string literal" do
        content = 'char str[10] = "hello";'
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 'str', type: 'char', text: 'char str[10] = "hello";', array_suffix: '[10]')
        expect(pos).to eq(23)
        expect(rest).to eq("")
      end

      it "extracts multi-dimensional array with nested initializers" do
        content = "int matrix[2][3] = {{1, 2, 3}, {4, 5, 6}};"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 'matrix', type: 'int', text: 'int matrix[2][3] = {{1, 2, 3}, {4, 5, 6}};', array_suffix: '[2][3]')
        expect(pos).to eq(42)
        expect(rest).to eq("")
      end

      it "extracts array with designated initializers" do
        content = "int arr[5] = {[0] = 1, [4] = 5};"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 'arr', type: 'int', text: 'int arr[5] = {[0] = 1, [4] = 5};', array_suffix: '[5]')
        expect(pos).to eq(32)
        expect(rest).to eq("")
      end

      it "extracts array with negative values" do
        content = "int arr[] = {-1, -2, -3};"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 'arr', type: 'int', text: 'int arr[] = {-1, -2, -3};', array_suffix: '[]')
        expect(pos).to eq(25)
        expect(rest).to eq("")
      end

      it "extracts float array with decimal values" do
        content = "float arr[] = {1.5, 2.7, 3.14};"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 'arr', type: 'float', text: 'float arr[] = {1.5, 2.7, 3.14};', array_suffix: '[]')
        expect(pos).to eq(31)
        expect(rest).to eq("")
      end

      it "extracts array with hex values" do
        content = "int arr[] = {0x01, 0xFF, 0xAB};"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 'arr', type: 'int', text: 'int arr[] = {0x01, 0xFF, 0xAB};', array_suffix: '[]')
        expect(pos).to eq(31)
        expect(rest).to eq("")
      end

      it "extracts const array with initializer" do
        content = "const int arr[] = {1, 2, 3};"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 'arr', type: 'int', decorators: ['const'], text: 'int arr[] = {1, 2, 3};', array_suffix: '[]')
        expect(pos).to eq(28)
        expect(rest).to eq("")
      end

      it "extracts static array with initializer" do
        content = "static int arr[] = {10, 20, 30};"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 'arr', type: 'int', decorators: ['static'], text: 'int arr[] = {10, 20, 30};', array_suffix: '[]')
        expect(pos).to eq(32)
        expect(rest).to eq("")
      end

      it "extracts array of pointers with initializer" do
        content = 'char* arr[] = {"hello", "world"};'
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 'arr', type: 'char*', text: 'char* arr[] = {"hello", "world"};', array_suffix: '[]')
        expect(pos).to eq(33)
        expect(rest).to eq("")
      end

      it "extracts array with macro values" do
        content = "int arr[] = {MAX_VALUE, MIN_VALUE};"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 'arr', type: 'int', text: 'int arr[] = {MAX_VALUE, MIN_VALUE};', array_suffix: '[]')
        expect(pos).to eq(35)
        expect(rest).to eq("")
      end

      it "extracts array with expression values" do
        content = "int arr[] = {1 + 2, 3 * 4, 5 - 1};"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 'arr', type: 'int', text: 'int arr[] = {1 + 2, 3 * 4, 5 - 1};', array_suffix: '[]')
        expect(pos).to eq(34)
        expect(rest).to eq("")
      end
    end

    context "qualified type declarations" do
      it "extracts const variable" do
        content = "const int value;"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 'value', type: 'int', decorators: ['const'], text: 'int value;')
        expect(pos).to eq(16)
        expect(rest).to eq("")
      end

      it "extracts volatile variable" do
        content = "volatile int flag;"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 'flag', type: 'int', decorators: ['volatile'], text: 'int flag;')
        expect(pos).to eq(18)
        expect(rest).to eq("")
      end

      it "extracts const volatile variable" do
        content = "const volatile int reg;"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 'reg', type: 'int', decorators: ['const', 'volatile'], text: 'int reg;')
        expect(pos).to eq(23)
        expect(rest).to eq("")
      end

      it "extracts static variable" do
        content = "static int counter;"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 'counter', type: 'int', decorators: ['static'], text: 'int counter;')
        expect(pos).to eq(19)
        expect(rest).to eq("")
      end

      it "extracts extern variable" do
        content = "extern int global;"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 'global', type: 'int', decorators: ['extern'], text: 'int global;')
        expect(pos).to eq(18)
        expect(rest).to eq("")
      end

      it "extracts static const variable" do
        content = "static const int MAX;"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 'MAX', type: 'int', decorators: ['static', 'const'], text: 'int MAX;')
        expect(pos).to eq(21)
        expect(rest).to eq("")
      end

      it "extracts register variable" do
        content = "register int fast;"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        # `register` is not a decorator keyword -- no stripping
        expect(variable.length).to eq 1
        expect(variable[0].name).to eq 'fast'
        expect(variable[0].decorators).to eq []
        expect(variable[0].text).to eq 'register int fast;'
        expect(pos).to eq(18)
        expect(rest).to eq("")
      end
    end

    context "compound variable declarations" do
      it "expands two-variable compound declaration" do
        content = "int x, y;"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        expect(variable.length).to eq 2

        expect(variable[0].original).to eq 'int x, y;'
        expect(variable[0].name).to eq 'x'
        expect(variable[0].type).to eq 'int'
        expect(variable[0].decorators).to eq []
        expect(variable[0].text).to eq 'int x;'

        expect(variable[1].original).to eq 'int x, y;'
        expect(variable[1].name).to eq 'y'
        expect(variable[1].type).to eq 'int'
        expect(variable[1].decorators).to eq []
        expect(variable[1].text).to eq 'int y;'

        expect(pos).to eq(9)
        expect(rest).to eq("")
      end

      it "expands three-variable compound declaration with decorator" do
        content = "static int a, b, c;"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        expect(variable.length).to eq 3

        variable.each do |v|
          expect(v.original).to eq 'static int a, b, c;'
          expect(v.decorators).to eq ['static']
        end

        expect(variable[0].name).to eq 'a'
        expect(variable[0].text).to eq 'int a;'

        expect(variable[1].name).to eq 'b'
        expect(variable[1].text).to eq 'int b;'

        expect(variable[2].name).to eq 'c'
        expect(variable[2].text).to eq 'int c;'

        expect(pos).to eq(19)
        expect(rest).to eq("")
      end

      it "expands compound declaration with pointer first declarator" do
        content = "int *p, q;"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        expect(variable.length).to eq 2

        expect(variable[0].name).to eq 'p'
        expect(variable[0].type).to eq 'int *'
        expect(variable[0].decorators).to eq []
        expect(variable[0].text).to eq 'int *p;'

        expect(variable[1].name).to eq 'q'
        expect(variable[1].type).to eq 'int'
        expect(variable[1].decorators).to eq []
        expect(variable[1].text).to eq 'int q;'

        expect(pos).to eq(10)
        expect(rest).to eq("")
      end

      it "expands compound declaration with pointer declarators and decorator" do
        content = "const char *s1, *s2;"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        expect(variable.length).to eq 2

        expect(variable[0].name).to eq 's1'
        expect(variable[0].decorators).to eq ['const']
        expect(variable[0].text).to eq 'char *s1;'

        expect(variable[1].name).to eq 's2'
        expect(variable[1].decorators).to eq ['const']
        expect(variable[1].text).to eq 'char *s2;'

        expect(pos).to eq(20)
        expect(rest).to eq("")
      end
    end

    context "compiler extensions on variable declarations" do
      it "extracts name and type from variable with trailing __attribute__" do
        content = "int x __attribute__((aligned(16)));"
        success, variable, _, _ = extract_variable.call(content)
        expect(success).to be true
        check_single(variable, name: 'x', type: 'int', text: 'int x __attribute__((aligned(16)));')
      end

      it "extracts name and type with __attribute__ having nested args" do
        content = 'char* buf __attribute__((section(".data")));'
        success, variable, _, _ = extract_variable.call(content)
        expect(success).to be true
        check_single(variable, name: 'buf', type: 'char*', text: 'char* buf __attribute__((section(".data")));')
      end

      it "extracts clean name and type from variable with __declspec prefix" do
        content = "__declspec(dllexport) int counter;"
        success, variable, _, _ = extract_variable.call(content)
        expect(success).to be true
        expect(variable[0].name).to eq('counter')
        expect(variable[0].type).to eq('int')
        # __declspec is not a DECORATOR_KEYWORD so it remains in .text
        expect(variable[0].text).to include('int counter;')
      end

      it "preserves __attribute__ in .text field for correct compilation" do
        content = "int x __attribute__((aligned(16)));"
        _, variable, _, _ = extract_variable.call(content)
        expect(variable[0].text).to eq('int x __attribute__((aligned(16)));')
      end

      it "extracts name from variable with __attribute__ and initializer" do
        content = "int x __attribute__((unused)) = 0;"
        success, variable, _, _ = extract_variable.call(content)
        expect(success).to be true
        expect(variable[0].name).to eq('x')
        expect(variable[0].type).to eq('int')
      end

      it "extracts name with static decorator and trailing __attribute__" do
        content = 'static int counter __attribute__((section(".bss")));'
        success, variable, _, _ = extract_variable.call(content)
        expect(success).to be true
        check_single(variable, name: 'counter', type: 'int', decorators: ['static'],
                     text: 'int counter __attribute__((section(".bss")));')
      end

      it "extracts name and type from struct-type variable with trailing __attribute__" do
        content = "struct Point my_point __attribute__((aligned(4)));"
        success, variable, _, _ = extract_variable.call(content)
        expect(success).to be true
        check_single(variable, name: 'my_point', type: 'struct Point',
                     text: 'struct Point my_point __attribute__((aligned(4)));')
      end

      it "extracts name and type from anonymous-struct variable with trailing __attribute__" do
        content = "struct { int x; int y; } coords __attribute__((aligned(8)));"
        success, variable, _, _ = extract_variable.call(content)
        expect(success).to be true
        expect(variable[0].name).to eq('coords')
        expect(variable[0].type).to eq('struct { int x; int y; }')
        expect(variable[0].text).to eq('struct { int x; int y; } coords __attribute__((aligned(8)));')
      end

      it "extracts name and type when __attribute__ appears on a struct member inside the body" do
        content = "struct Point { int x __attribute__((aligned(4))); int y; } my_point;"
        success, variable, _, _ = extract_variable.call(content)
        expect(success).to be true
        expect(variable[0].name).to eq('my_point')
        expect(variable[0].type).to eq('struct Point { int x ; int y; }')
        expect(variable[0].text).to eq('struct Point { int x __attribute__((aligned(4))); int y; } my_point;')
      end
    end

    context "array_suffix field" do
      it "returns empty string for a scalar variable" do
        content = "static uint8 s_count;"
        success, variable, _, _ = extract_variable.call(content)
        expect(success).to be true
        check_single(variable, name: 's_count', type: 'uint8', decorators: ['static'],
                     text: 'uint8 s_count;', array_suffix: '')
      end

      it "returns subscript for a single-dimension array" do
        content = "static int arr[10];"
        success, variable, _, _ = extract_variable.call(content)
        expect(success).to be true
        check_single(variable, name: 'arr', type: 'int', decorators: ['static'],
                     text: 'int arr[10];', array_suffix: '[10]')
      end

      it "returns both subscripts for a two-dimensional array" do
        content = "static char matrix[3][4];"
        success, variable, _, _ = extract_variable.call(content)
        expect(success).to be true
        check_single(variable, name: 'matrix', type: 'char', decorators: ['static'],
                     text: 'char matrix[3][4];', array_suffix: '[3][4]')
      end

      it "returns macro-sized subscript for a named-constant array" do
        content = "static AlertEntry_t s_table[MAX_ALERTS];"
        success, variable, _, _ = extract_variable.call(content)
        expect(success).to be true
        check_single(variable, name: 's_table', type: 'AlertEntry_t', decorators: ['static'],
                     text: 'AlertEntry_t s_table[MAX_ALERTS];', array_suffix: '[MAX_ALERTS]')
      end

      it "returns empty subscript for an unsized array with initializer" do
        content = "static int arr[] = {1, 2, 3};"
        success, variable, _, _ = extract_variable.call(content)
        expect(success).to be true
        check_single(variable, name: 'arr', type: 'int', decorators: ['static'],
                     text: 'int arr[] = {1, 2, 3};', array_suffix: '[]')
      end

      it "returns subscript for a sized array with initializer" do
        content = "static int arr[5] = {0};"
        success, variable, _, _ = extract_variable.call(content)
        expect(success).to be true
        check_single(variable, name: 'arr', type: 'int', decorators: ['static'],
                     text: 'int arr[5] = {0};', array_suffix: '[5]')
      end

      it "returns empty string for a function pointer variable" do
        content = "static void (*cb)(int);"
        success, variable, _, _ = extract_variable.call(content)
        expect(success).to be true
        check_single(variable, name: 'cb', type: 'void', decorators: ['static'],
                     text: 'void (*cb)(int);', array_suffix: '')
      end
    end
  end
end
