# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'timeout'
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
      ->(content) do
        scanner = StringScanner.new(content)
        declarations = CExtractorDeclarations.new({ c_extractor_code_text: CExtractorCodeText.new() })
        declarations.setup()
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

      # #1266 follow-on: same unanchored-substring risk class as #1262/#1266. The type-side
      # identifier "counter_t" itself contains "count" as a substring; a plain rindex(name)
      # would still find the real trailing occurrence here (rindex searches right-to-left),
      # but this pins down that the \b-anchored match extract_type now uses doesn't regress
      # this ordinary case, where the type name happens to share a substring with the
      # declared name.
      it "extracts a variable whose type name contains the variable's own name as a substring" do
        content = "counter_t count;"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 'count', type: 'counter_t', text: 'counter_t count;')
        expect(pos).to eq(content.length)
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
        # Leading `const` (qualifying `int`) is a decorator; the second `const`
        # (qualifying the pointer itself) is part of the declarator and stays put
        check_single(variable, name: 'ptr', type: 'int* const', decorators: ['const'], text: 'int* const ptr;')
        expect(pos).to eq(21)
        expect(rest).to eq("")
      end

      it "extracts volatile pointer to volatile" do
        content = "volatile int* volatile ptr;"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        # Same as const/const above: only the leading qualifier is a decorator
        check_single(variable, name: 'ptr', type: 'int* volatile', decorators: ['volatile'], text: 'int* volatile ptr;')
        expect(pos).to eq(27)
        expect(rest).to eq("")
      end

      it "extracts static const pointer to const" do
        content = "static const int* const ptr;"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        # `static` and the leading `const` are decorators; the trailing `const`
        # on the pointer itself is retained in both `.type` and `.text`
        check_single(variable, name: 'ptr', type: 'int* const', decorators: ['static', 'const'], text: 'int* const ptr;')
        expect(pos).to eq(28)
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

    context "escape sequences in string literal initializers" do
      it "extracts pointer variable with escaped quote in string literal initializer" do
        content = 'char* s = "say \"hi\"";'
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 's', type: 'char*', text: 'char* s = "say \"hi\"";')
        expect(pos).to eq(content.length)
        expect(rest).to eq("")
      end

      it "extracts pointer variable with escaped backslash in string literal initializer" do
        content = 'char* s = "C:\\\\dir";'
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 's', type: 'char*', text: 'char* s = "C:\\\\dir";')
        expect(pos).to eq(content.length)
        expect(rest).to eq("")
      end

      it "extracts pointer variable with escaped newline in string literal initializer" do
        content = 'char* s = "line1\\nline2";'
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 's', type: 'char*', text: 'char* s = "line1\\nline2";')
        expect(pos).to eq(content.length)
        expect(rest).to eq("")
      end

      it "extracts pointer variable with hex escape in string literal initializer" do
        content = 'char* s = "\\x41\\x42";'
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 's', type: 'char*', text: 'char* s = "\\x41\\x42";')
        expect(pos).to eq(content.length)
        expect(rest).to eq("")
      end

      it "extracts pointer variable with octal escape in string literal initializer" do
        content = 'char* s = "\\101\\102";'
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 's', type: 'char*', text: 'char* s = "\\101\\102";')
        expect(pos).to eq(content.length)
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

      # A comma after an initializer separates declarators just as one before it does. A comma
      # inside brackets, braces or a literal belongs to the initializer.
      [
        ['int g_x = 0, g_y;',                  [['g_x', 'int', 'int g_x = 0;'], ['g_y', 'int', 'int g_y;']]],
        ['int g_p = f(1, 2), g_q, g_r = 3;',   [['g_p', 'int', 'int g_p = f(1, 2);'], ['g_q', 'int', 'int g_q;'], ['g_r', 'int', 'int g_r = 3;']]],
        ['char *g_s = "a,b", *g_t;',           [['g_s', 'char *', 'char *g_s = "a,b";'], ['g_t', 'char *', 'char *g_t;']]],
        ["char g_c = ',', g_d;",               [['g_c', 'char', "char g_c = ',';"], ['g_d', 'char', 'char g_d;']]],
        ['int g_a[2] = {1, 2}, g_b;',          [['g_a', 'int', 'int g_a[2] = {1, 2};'], ['g_b', 'int', 'int g_b;']]],
        ['struct ops g_o = { 1 }, g_n = { 2 };', [['g_o', 'struct ops', 'struct ops g_o = { 1 };'], ['g_n', 'struct ops', 'struct ops g_n = { 2 };']]],
        ['int g_m[N == 2 ? 2 : 3] = {0}, g_k;', [['g_m', 'int', 'int g_m[N == 2 ? 2 : 3] = {0};'], ['g_k', 'int', 'int g_k;']]]
      ].each do |content, expected|
        it "splits `#{content}` at its top-level commas" do
          success, variables, _pos, _rest = extract_variable.call( content )

          expect( success ).to be true
          expect( variables.map { |v| [v.name, v.type, v.text] } ).to eq expected
          expect( variables.map( &:original ).uniq ).to eq [content]
        end
      end

      # A later declarator takes the text ahead of the first one's declarator. Stars, qualifiers
      # after a star, attributes after the name and line breaks belong to the first declarator.
      [
        ["int\ng_x = 0, g_y = 1;",                                  ['g_y', 'int', [], 'int g_y = 1;']],
        ["const unsigned char\n  g_tbl[] = {1, 2}, g_after = 3;",   ['g_after', 'unsigned char', ['const'], 'unsigned char g_after = 3;']],
        ['int *const g_a = 0, g_b;',                                ['g_b', 'int', [], 'int g_b;']],
        ['const char *const g_n = "x", *const g_m = "y";',          ['g_m', 'char *const', ['const'], 'char *const g_m = "y";']],
        ['int *restrict g_a = 0, g_b = 2;',                         ['g_b', 'int', [], 'int g_b = 2;']],
        ['int g_a __attribute__((aligned(4))) = 1, g_b;',           ['g_b', 'int', [], 'int g_b;']],
        ['__ALIGNED(4) uint8_t g_buf[16] = {0}, g_buf2[16];',       ['g_buf2', '__ALIGNED(4) uint8_t', [], '__ALIGNED(4) uint8_t g_buf2[16];']],
        ['__attribute__((section(".x"))) int g_s = 1, g_t;',        ['g_t', 'int', [], '__attribute__((section(".x"))) int g_t;']]
      ].each do |content, (name, type, decorators, text)|
        it "gives a later declarator only the base type of `#{content.gsub( "\n", '\n' )}`" do
          success, variables, _pos, _rest = extract_variable.call( content )

          expect( success ).to be true
          expect( variables.last.to_h.slice( :name, :type, :decorators, :text ) ).to eq( name: name, type: type, decorators: decorators, text: text )
        end
      end

      # Without the first name the base type can't be found, so the declaration stays whole. It
      # reads as nameless, as a declaration a macro spells does, rather than named by its last.
      [
        'int (g_a) = 1, g_b = 2;',
        'static ARR_OF(int, hits)[3], n;'
      ].each do |content|
        it "keeps `#{content}` whole and nameless, since its first name can't be read" do
          success, variables, _pos, _rest = extract_variable.call( content )

          expect( success ).to be true
          expect( variables.map { |v| [v.name, v.type, v.text] } ).to eq [[nil, nil, content.delete_prefix( 'static ' )]]
        end
      end

      # A word may stand between the type and the name: a qualifier, a type or storage keyword, a
      # memory-space keyword, a compiler's `__` extension or a macro in capitals. A word ahead of a
      # star is never the name, and a bracket inside parentheses is no array size.
      [
        ['int __far a, b;',                          [['a', 'int __far'], ['b', 'int __far']]],
        ['char __far *p, *q;',                       [['p', 'char __far *'], ['q', 'char __far *']]],
        ['unsigned char xdata a, b;',                [['a', 'unsigned char xdata'], ['b', 'unsigned char xdata']]],
        ['int MYQ *p, *q;',                          [['p', 'int MYQ *'], ['q', 'int MYQ *']]],
        ['int MYQ a, b;',                            [['a', 'int MYQ'], ['b', 'int MYQ']]],
        ['int _Atomic a, b;',                        [['a', 'int _Atomic'], ['b', 'int _Atomic']]],
        ['struct S _Atomic s, t;',                   [['s', 'struct S _Atomic'], ['t', 'struct S _Atomic']]],
        ['typeof(int[3]) a, b;',                     [['a', 'typeof(int[3])'], ['b', 'typeof(int[3])']]],
        ['_Alignas(sizeof(x[0])) int a, b;',         [['a', '_Alignas(sizeof(x[0])) int'], ['b', '_Alignas(sizeof(x[0])) int']]],
        ['int *x MY_ATTR, y;',                       [['MY_ATTR', 'int *x'], ['y', 'int']]],
        ['const u8 MAX_A = 1, MAX_B = 2;',           [['MAX_A', 'u8'], ['MAX_B', 'u8']]],
        ['unsigned long MAX_A = 1, MAX_B = 2;',      [['MAX_A', 'unsigned long'], ['MAX_B', 'unsigned long']]]
      ].each do |content, expected|
        it "splits `#{content}` with each variable's base type" do
          success, variables, _pos, _rest = extract_variable.call( content )

          expect( success ).to be true
          expect( variables.map { |v| [v.name, v.type] } ).to eq expected
        end
      end

      # An unexpanded attribute macro after the first name reads as the name, which leaves a base
      # type no declaration could have. The statement then stays one record, read whole.
      [
        "const char g_a KEEP = 'x', g_b = 'y';",
        'const uint8_t table[] PROGMEM = {1}, t2[] PROGMEM = {2};'
      ].each do |content|
        it "keeps `#{content}` one record when a macro after its first name misleads the base type" do
          success, variables, _pos, _rest = extract_variable.call( content )

          expect( success ).to be true
          expect( variables.map( &:text ) ).to eq [content.delete_prefix( 'const ' )]
        end
      end

      # A name read in capitals after another word is taken for an attribute macro, so the word
      # before it is the real name and the statement stays one record
      [
        ['static const int MAX_A UNUSED = 3, MAX_B = 1;', 'int MAX_A UNUSED = 3, MAX_B = 1;'],
        ['static const u8 MAX_A UNUSED = 3, MAX_B = 1;',  'u8 MAX_A UNUSED = 3, MAX_B = 1;'],
        ['static int data UNUSED, other;',                'int data UNUSED, other;'],
        ['static int a1 __maybe_unused, b1;',             'int a1 __maybe_unused, b1;']
      ].each do |content, text|
        it "keeps `#{content}` one record when a capitalized name follows the first name" do
          success, variables, _pos, _rest = extract_variable.call( content )

          expect( success ).to be true
          expect( variables.map( &:text ) ).to eq [text]
        end
      end

      it "splits a compound declaration whose first function pointer has an initializer" do
        success, variables, _pos, _rest = extract_variable.call( "static int (*a)(int) = f, (*b)(int);" )

        expect( success ).to be true
        expect( variables.map { |v| [v.name, v.type, v.decorators, v.declarator] } ).to eq [
          ['a', 'int', ['static'], '(*a)(int)'],
          ['b', 'int', ['static'], '(*b)(int)']
        ]
      end

      # Array sizes are found in one pass, however many parentheses a literal holds
      it "reads a declaration whose literal holds many parentheses within a time bound" do
        content = 'int MACRO("' + ('(' * 20_000) + '") x, y;'

        success, variables = nil
        Timeout.timeout( 2 ) { success, variables, _, _ = extract_variable.call( content ) }

        expect( success ).to be true
        expect( variables.map( &:name ) ).to eq ['x', 'y']
      end

      it "splits a compound declaration after a large initializer table within a time bound" do
        content = 'static const uint8_t table[] = { ' + ('0x5A, ' * 20_000) + '0 }, after;'

        success, variables = nil
        Timeout.timeout( 2 ) { success, variables, _, _ = extract_variable.call( content ) }

        expect( success ).to be true
        expect( variables.map( &:name ) ).to eq ['table', 'after']
      end
    end

    # GCC and Clang accept '$' in an identifier, at its start, middle or end
    context "names holding '$'" do
      [
        ['static int hook$2;',     [['hook$2', 'int', '']]],
        ['int g$v[2];',            [['g$v', 'int', '[2]']]],
        ['int $lead;',             [['$lead', 'int', '']]],
        ['int trail$;',            [['trail$', 'int', '']]],
        ['int a$1 = 0, b$2;',      [['a$1', 'int', ''], ['b$2', 'int', '']]],
        ['struct s$t x$y;',        [['x$y', 'struct s$t', '']]],
        ['static int x$_Atomic;',  [['x$_Atomic', 'int', '']]]
      ].each do |content, expected|
        it "reads `#{content}`" do
          success, variables, _pos, _rest = extract_variable.call( content )

          expect( success ).to be true
          expect( variables.map { |v| [v.name, v.type, v.array_suffix] } ).to eq expected
        end
      end
    end

    # A variable's extern repeats its type, so a type keyword or a specifier's argument must stay
    context "type specifiers and keywords" do
      [
        ['typeof(int) g_t;',            'g_t',  'typeof(int)'],
        ['_Atomic(int) g_a;',           'g_a',  '_Atomic(int)'],
        ['typeof(*g_pp) g_q;',          'g_q',  'typeof(*g_pp)'],
        ['__typeof__(int) g_u;',        'g_u',  '__typeof__(int)'],
        ['_BitInt(8) g_b;',             'g_b',  '_BitInt(8)'],
        ['typeof(int (*)(int)) g_fp;',  'g_fp', 'typeof(int (*)(int))'],
        ['typeof(int[3]) g_arr;',       'g_arr', 'typeof(int[3])'],
        ['typeof(char (*)[4]) g_pa;',   'g_pa', 'typeof(char (*)[4])'],
        ['__typeof_unqual(const int) g_tu;', 'g_tu', '__typeof_unqual(const int)'],
        ['_Alignas(8) int g_al;',       'g_al', '_Alignas(8) int'],
        ['_Bool g_f;',                  'g_f',  '_Bool'],
        ['_Atomic int g_ai;',           'g_ai', '_Atomic int'],
        ['_Thread_local int g_tl;',     'g_tl', '_Thread_local int'],
        ['_Complex double g_c;',        'g_c',  '_Complex double']
      ].each do |content, name, type|
        it "reads `#{content}` with its type whole" do
          success, variables, _pos, _rest = extract_variable.call( content )

          expect( success ).to be true
          expect( variables.map { |v| [v.name, v.type] } ).to eq [[name, type]]
        end
      end

      it "gives a later declarator a base type a specifier spells" do
        success, variables, _pos, _rest = extract_variable.call( 'typeof(*p) a = 0, b;' )

        expect( success ).to be true
        expect( variables.map { |v| [v.name, v.type, v.text] } ).to eq [['a', 'typeof(*p)', 'typeof(*p) a = 0;'], ['b', 'typeof(*p)', 'typeof(*p) b;']]
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

    # An asm label names the variable's symbol. The record keeps it apart from the name and type,
    # and its text keeps it for the definition.
    # An alignment specifier or attribute may lead a declaration, ahead of its storage class
    context "a leading alignment specifier or attribute" do
      [
        ['_Alignas(8) static int s_as;',                ['static'],          '_Alignas(8) int',  '_Alignas(8) int s_as;'],
        ['alignas(16) static const int s_c = 1;',       ['static', 'const'], 'alignas(16) int',  'alignas(16) int s_c = 1;'],
        ['__attribute__((unused)) static int s_u;',     ['static'],          'int',              '__attribute__((unused)) int s_u;'],
        ['static _Alignas(4) volatile int s_v;',        ['static', 'volatile'], '_Alignas(4) int', '_Alignas(4) int s_v;']
      ].each do |content, decorators, type, text|
        it "reads `#{content}` with its storage class as a decorator" do
          success, variables, _pos, _rest = extract_variable.call( content )

          expect( success ).to be true
          expect( variables.map { |v| [v.decorators, v.type, v.text] } ).to eq [[decorators, type, text]]
        end
      end
    end

    context "asm labels" do
      def read_all(content)
        success, variables, _, _ = extract_variable.call( content )
        expect( success ).to be true
        variables.map { |v| v.to_h.slice( :name, :type, :array_suffix, :declarator, :text, :asm_label ) }
      end

      it "reads a variable by its name, whichever spelling its label takes" do
        expect( read_all( 'int g_s __asm__("g_symbol") = 1;' ) ).to eq( [{ name: 'g_s', type: 'int', array_suffix: '', declarator: nil,
                                                                           text: 'int g_s __asm__("g_symbol") = 1;', asm_label: '__asm__("g_symbol")' }] )
        expect( read_all( 'int g_b asm("g_b_sym");' ).first ).to include( name: 'g_b', type: 'int', asm_label: 'asm("g_b_sym")' )
        expect( read_all( 'static char *g_p __asm ("g_p_sym");' ).first ).to include( name: 'g_p', type: 'char *', asm_label: '__asm ("g_p_sym")' )
      end

      it "reads a label after an array size, an attribute or a declarator group" do
        expect( read_all( 'int g_a[2] asm("g_a_sym") = { 1, 2 };' ).first ).to include( name: 'g_a', array_suffix: '[2]', asm_label: 'asm("g_a_sym")' )
        expect( read_all( 'int g_u __attribute__((used)) asm("g_u_sym");' ).first ).to include( name: 'g_u', type: 'int', asm_label: 'asm("g_u_sym")' )
        expect( read_all( 'int (*fp)(int) __asm__("fp_label");' ).first ).to include( name: 'fp', declarator: '(*fp)(int)', asm_label: '__asm__("fp_label")' )
        expect( read_all( 'int (*g)(int) __attribute__((used)) __asm__("sym") = f;' ).first ).to include( name: 'g', declarator: '(*g)(int)', asm_label: '__asm__("sym")' )
      end

      it "reads each label of a compound declaration" do
        expect( read_all( 'int a asm("a_sym") = 1, *b asm("b_sym"), c;' ).map { |v| v.slice( :name, :type, :asm_label ) } ).to eq( [
          { name: 'a', type: 'int', asm_label: 'asm("a_sym")' },
          { name: 'b', type: 'int *', asm_label: 'asm("b_sym")' },
          { name: 'c', type: 'int', asm_label: nil }
        ] )
      end

      it "gives a variable without a label none" do
        expect( read_all( 'int asm_count = 1;' ).first ).to include( name: 'asm_count', asm_label: nil )
      end
    end

    context "multiline declarations" do
      it "extracts array declaration whose closing brace and semicolon fall on the final line after multiline data (GH #1182)" do
        content = "static uint8_t arr[10] = {\n    0x00, 0x01, 0x02, 0x03, 0x04,\n    0x05, 0x06, 0x07, 0x08, 0x09\n};"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 'arr', type: 'uint8_t', decorators: ['static'],
                     text: 'uint8_t arr[10] = { 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09 };',
                     array_suffix: '[10]')
        expect(pos).to eq(content.length)
        expect(rest).to eq("")
      end

      it "extracts nested multi-dimensional array initializer whose closing braces and semicolon fall on the final line" do
        content = "static int matrix[2][3] = {\n    {1, 2, 3},\n    {4, 5, 6}\n};"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 'matrix', type: 'int', decorators: ['static'],
                     text: 'int matrix[2][3] = { {1, 2, 3}, {4, 5, 6} };',
                     array_suffix: '[2][3]')
        expect(pos).to eq(content.length)
        expect(rest).to eq("")
      end

      it "expands a compound declaration whose second declarator has a multiline brace initializer" do
        content = "static int a, arr[3] = {\n    1,\n    2,\n    3\n};"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        expect(variable.length).to eq 2

        expect(variable[0].name).to eq 'a'
        expect(variable[0].decorators).to eq ['static']
        expect(variable[0].text).to eq 'int a;'

        expect(variable[1].name).to eq 'arr'
        expect(variable[1].decorators).to eq ['static']
        expect(variable[1].array_suffix).to eq '[3]'
        expect(variable[1].text).to eq 'int arr[3] = { 1, 2, 3 };'

        expect(pos).to eq(content.length)
        expect(rest).to eq("")
      end

      it "extracts a declaration with the type and name split across lines and no braces involved" do
        content = "int\n    x;"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 'x', type: 'int', text: 'int x;')
        expect(pos).to eq(content.length)
        expect(rest).to eq("")
      end

      it "extracts a declaration whose initializer value falls on the line after the assignment" do
        content = "int x =\n    5;"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 'x', type: 'int', text: 'int x = 5;')
        expect(pos).to eq(content.length)
        expect(rest).to eq("")
      end

      it "extracts a declaration whose terminating semicolon is alone on the line following a bracketed declarator" do
        content = "int arr[10]\n;"
        success, variable, pos, rest = extract_variable.call(content)

        expect(success).to be true
        check_single(variable, name: 'arr', type: 'int', text: 'int arr[10] ;', array_suffix: '[10]')
        expect(pos).to eq(content.length)
        expect(rest).to eq("")
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

    # The name of a function pointer or a pointer to an array sits inside parentheses. The type
    # is what comes ahead of them, and the declarator keeps the rest a declaration needs.
    context "parenthesized declarators" do
      def read_one(content)
        success, variables, _, _ = extract_variable.call( content )
        expect( success ).to be true
        expect( variables.length ).to eq 1
        variables.first.to_h.slice( :name, :type, :array_suffix, :declarator, :text )
      end

      it "reads a function pointer's declarator" do
        expect( read_one( "static void (*cb)(int);" ) ).to eq(
          name: 'cb', type: 'void', array_suffix: '', declarator: '(*cb)(int)', text: 'void (*cb)(int);'
        )
      end

      it "reads an array of function pointers by its name" do
        expect( read_one( "static int (*s_table[2])(int) = { one, two };" ) ).to eq(
          name: 's_table', type: 'int', array_suffix: '', declarator: '(*s_table[2])(int)', text: 'int (*s_table[2])(int) = { one, two };'
        )
      end

      it "reads a constant function pointer by its name" do
        expect( read_one( "int (*const k_hook)(int) = bump;" ) ).to include( name: 'k_hook', type: 'int', declarator: '(*const k_hook)(int)' )
      end

      it "reads a pointer to an array's declarator" do
        expect( read_one( "int (*ptr)[10];" ) ).to include( name: 'ptr', type: 'int', array_suffix: '', declarator: '(*ptr)[10]' )
      end

      it "keeps pointer stars ahead of the parentheses in the type" do
        expect( read_one( "extern char *(*name_of)(int);" ) ).to include( name: 'name_of', type: 'char *', declarator: '(*name_of)(int)' )
      end

      # The declarator is repeated in an extern, which must agree with the definition
      it "keeps a calling convention written inside the parentheses" do
        expect( read_one( "static void (__stdcall *on_tick)(int);" ) ).to eq(
          name: 'on_tick', type: 'void', array_suffix: '', declarator: '(__stdcall *on_tick)(int)', text: 'void (__stdcall *on_tick)(int);'
        )
      end

      it "reads a qualifier a compiler adds past the name" do
        expect( read_one( "int (* _Nullable np)(int);" ) ).to include( name: 'np', type: 'int', declarator: '(* _Nullable np)(int)' )
      end

      it "keeps a calling convention ahead of an attribute among the stars" do
        expect( read_one( "void (__stdcall * __attribute__((unused)) fp)(int);" ) ).to include(
          name: 'fp', type: 'void', declarator: '(__stdcall * __attribute__((unused)) fp)(int)'
        )
      end

      [
        ['void (*(fp34))(void) = 0;',          'fp34',      '(*(fp34))(void)'],
        ['static int (*hook$1)(int) = 0;',     'hook$1',    '(*hook$1)(int)'],
        ['int (*s_hook /* callback */)(int);', 's_hook',    '(*s_hook )(int)']
      ].each do |content, name, declarator|
        it "reads `#{content}` by its name #{name}" do
          expect( read_one( content ) ).to include( name: name, declarator: declarator )
        end
      end

      # An extern repeats the declarator. An attribute after it would draw a warning there, and an
      # asm label is kept apart.
      it "leaves a trailing attribute and an asm label out of the declarator" do
        expect( read_one( "void (* const vec[])(void) __attribute__ ((used)) = { 0 };" ) ).to include( name: 'vec', declarator: '(* const vec[])(void)' )
        expect( read_one( 'int (*fp)(int) __asm__("fp_label");' ) ).to include( name: 'fp', declarator: '(*fp)(int)' )
        expect( read_one( 'int (*g)(int) __attribute__((used)) __asm__("sym") = f;' ) ).to include( name: 'g', declarator: '(*g)(int)' )
        expect( read_one( 'int (*g_u)(int) MY_USED = f;' ) ).to include( name: 'g_u', declarator: '(*g_u)(int)' )
      end

      # Fallback preprocessing leaves comments in place, and a bracket in one doesn't count
      it "finds the initializer past a comment holding a bracket" do
        expect( read_one( 'int (*g_cb)(int) /* 1) */ = ticker_bump;' ) ).to include( name: 'g_cb', declarator: '(*g_cb)(int)' )
      end

      # The written text may open a different group than the stripped text does, as an attribute
      # whose argument opens with a star can. Then the stripped declarator stands.
      it "keeps the stripped declarator when the written text opens a different group" do
        expect( read_one( "void __attribute__((*odd)) (*fp)(int);" ) ).to include( name: 'fp', declarator: '(*fp)(int)' )
      end

      [
        ['int x, (*fp)(int);',                [['x', 'int', nil], ['fp', 'int', '(*fp)(int)']]],
        ['int (*fp)(int), x;',                [['fp', 'int', '(*fp)(int)'], ['x', 'int', nil]]],
        ['void (__cdecl *a)(int), (*b)(int);', [['a', 'void', '(__cdecl *a)(int)'], ['b', 'void', '(*b)(int)']]]
      ].each do |content, expected|
        it "splits the compound `#{content}` by declarator" do
          success, variables, _, _ = extract_variable.call( content )

          expect( success ).to be true
          expect( variables.map { |v| [v.name, v.type, v.declarator] } ).to eq expected
        end
      end

      it "gives a plain declaration no declarator" do
        expect( read_one( "static uint8_t buf[16];" ) ).to include( name: 'buf', declarator: nil )
      end

      # A macro's arguments ahead of the type are no declarator
      it "reads a declaration whose type a function-like macro precedes by its last word" do
        expect( read_one( "__ALIGNED(8) uint32_t x;" ) ).to include( name: 'x', declarator: nil )
      end

      # A pointer in a size, an initializer or a string is no declarator
      [
        ['size_t n = sizeof(*p);',   'n', ''],
        ['int a[sizeof(*p)];',       'a', '[sizeof(*p)]'],
        ['char *s = "(*x)";',        's', ''],
        ['int x[] = { (*a) };',      'x', '[]']
      ].each do |content, name, suffix|
        it "reads `#{content}` as a plain declaration of #{name}" do
          expect( read_one( content ) ).to include( name: name, array_suffix: suffix, declarator: nil )
        end
      end

      # A struct's function-pointer members belong to the struct, not to its variables
      it "reads a struct variable whose body declares a function pointer by the variable's name" do
        expect( read_one( "static struct ops { int (*open)(void); } s_ops;" ) ).to include( name: 's_ops', declarator: nil )
      end

      it "splits a compound declaration of struct variables whose body declares a function pointer" do
        success, variables, _, _ = extract_variable.call( "static struct ops { int (*open)(void); } s_ops, s_ops2;" )

        expect( success ).to be true
        expect( variables.map { |v| [v.name, v.text] } ).to eq [
          ['s_ops',  'struct ops { int (*open)(void); } s_ops;'],
          ['s_ops2', 'struct ops { int (*open)(void); } s_ops2;']
        ]
      end

      # A lookup table may run to many kilobytes, and its declaration must still read quickly. A
      # scan quadratic in its length would take minutes on this one.
      it "reads a declaration with a large initializer table within a time bound" do
        content = 'static const uint8_t table[] = { ' + ('0x5A, ' * 20_000) + '0 };'

        success, variables = nil
        Timeout.timeout( 2 ) { success, variables, _, _ = extract_variable.call( content ) }

        expect( success ).to be true
        expect( variables.first.name ).to eq( 'table' )
      end

      it "splits a compound declaration of function pointers into each one" do
        success, variables, _, _ = extract_variable.call( "static int (*a)(int), (*b)(int);" )

        expect( success ).to be true
        expect( variables.map { |v| [v.name, v.type, v.declarator, v.text] } ).to eq [
          ['a', 'int', '(*a)(int)', 'int (*a)(int);'],
          ['b', 'int', '(*b)(int)', 'int (*b)(int);']
        ]
      end
    end

    # Fallback preprocessing leaves comments in place, and a declaration's lines are joined into
    # one. A comment must not swallow what follows it on the joined line.
    context "comments inside a declaration" do
      def read(content)
        success, variables, pos, _rest = extract_variable.call( content )
        expect( success ).to be(true), "expected a declaration in #{content.inspect}"
        expect( pos ).to eq( content.length )
        return variables
      end

      it "reads past a line comment before the initializer" do
        content = "int g_n // count\n    = 3;"
        variable = read( content ).first
        expect( [variable.name, variable.type, variable.text] ).to eq ['g_n', 'int', 'int g_n = 3;']
        expect( variable.original ).to eq content
      end

      it "reads a declaration that ends in a block comment" do
        expect( read( "int g_m /* count */;" ).map { |v| [v.name, v.type] } ).to eq [['g_m', 'int']]
      end

      it "reads a function pointer with a line comment before its initializer" do
        variable = read( "int (*g_fp)(int) // cb\n    = 0;" ).first
        expect( [variable.name, variable.declarator, variable.text] ).to eq ['g_fp', '(*g_fp)(int)', 'int (*g_fp)(int) = 0;']
      end

      it "splits a compound declaration only at commas outside its comments" do
        expect( read( "int g_c1, // first, of two\n    g_c2;" ).map { |v| [v.name, v.text] } ).to eq [['g_c1', 'int g_c1;'], ['g_c2', 'int g_c2;']]
      end

      it "keeps what looks like a comment inside a literal" do
        expect( read( "char *g_lit = \"a // b /* c */\";" ).first.text ).to eq 'char *g_lit = "a // b /* c */";'
        expect( read( "char g_ch = '/';" ).first.text ).to eq "char g_ch = '/';"
      end

      # The buffer may end inside the comment, so the scan fails and the caller grows the buffer
      it "fails at a block comment that never closes" do
        success, variables, pos, _rest = extract_variable.call( "int x /* never closed; int y;" )
        expect( [success, variables, pos] ).to eq [false, nil, 0]
      end

      it "reads a declaration with a commented initializer table within a time bound" do
        content = 'static const uint8_t table[] = { ' + ('0x5A, /* v */ ' * 20_000) + '0 };'

        success, variables = nil
        Timeout.timeout( 2 ) { success, variables, _, _ = extract_variable.call( content ) }

        expect( success ).to be true
        expect( variables.first.name ).to eq( 'table' )
      end
    end

    context "comments and malformed input" do
      it "scans past a block comment mid-declaration and still finds the real terminator" do
        content = "int x /* note */ = 5;"
        success, variable, pos, rest = extract_variable.call(content)
        expect(success).to be true
        expect(variable).to be_an(Array)
        expect(variable.length).to eq 1
        expect(pos).to eq content.length
        expect(rest).to eq ''
      end

      it "scans past a line comment containing a ';' without treating it as the terminator" do
        content = "int x // ;\n = 5;"
        success, variable, pos, rest = extract_variable.call(content)
        expect(success).to be true
        expect(variable).to be_an(Array)
        expect(variable.length).to eq 1
        # If the ';' inside the comment had wrongly terminated the scan, pos would land
        # mid-string instead of consuming the real, later terminator.
        expect(pos).to eq content.length
        expect(rest).to eq ''
      end

      it "rejects an unbalanced closing paren with no matching open" do
        content = ");"
        success, variable, pos, rest = extract_variable.call(content)
        expect(success).to be false
        expect(variable).to be_nil
        expect(pos).to eq 0
        expect(rest).to eq content
      end

      it "rejects an unbalanced closing bracket with no matching open" do
        content = "];"
        success, variable, pos, rest = extract_variable.call(content)
        expect(success).to be false
        expect(variable).to be_nil
        expect(pos).to eq 0
        expect(rest).to eq content
      end

      it "rejects an unbalanced closing brace with no matching open" do
        content = "};"
        success, variable, pos, rest = extract_variable.call(content)
        expect(success).to be false
        expect(variable).to be_nil
        expect(pos).to eq 0
        expect(rest).to eq content
      end

      it "scans past a lone '/' that doesn't start a comment" do
        content = "int x /y;"
        success, variable, pos, rest = extract_variable.call(content)
        expect(success).to be true
        expect(variable).to be_an(Array)
        expect(variable.length).to eq 1
        expect(pos).to eq content.length
        expect(rest).to eq ''
      end

      it "rejects a bare semicolon that doesn't look like a valid declaration" do
        content = ";"
        success, variable, pos, rest = extract_variable.call(content)
        expect(success).to be false
        expect(variable).to be_nil
        expect(pos).to eq 0
        expect(rest).to eq content
      end
    end
  end
end
