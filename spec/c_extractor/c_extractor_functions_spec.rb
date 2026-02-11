# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/c_extractor/c_extractor_code_text'
require 'ceedling/c_extractor/c_extractor_functions'
require 'stringio'

describe CExtractorFunctions do

  ###
  ### extract_function_signature()
  ###

  describe "#extract_function_signature (private method testing)" do
    # Helper to access private method
    let(:extract_signature) do
      ->(content, max_line_length=1000) do
        scanner = StringScanner.new(content)
        functions = CExtractorFunctions.new( CExtractorCodeText.new(), max_line_length )
        signature = functions.send( :extract_function_signature, scanner )
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
        
        expect(signature).to be_nil
        expect(pos).to eq(23)
        expect(rest).to eq("")
      end

      it "does not extract signature from declaration with whitespace" do
        content = "void process(int* ptr)     ;"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to be_nil
        expect(pos).to eq(28)
        expect(rest).to eq("")
      end

      it "does not extract signature from declaration with comment" do
        content = "void process(int* ptr)/***/;"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to be_nil
        expect(pos).to eq(28)
        expect(rest).to eq("")
      end

      it "does not extract signature from declaration with newline" do
        content = "void process(int* ptr)\n;"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to be_nil
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

  ###
  ### extract_function_name()
  ###

  describe "#extract_function_name (private method testing)" do
    # Helper to access private method
    let(:parse_name) do
      ->(signature) do
        functions = CExtractorFunctions.new( CExtractorCodeText.new(), 1000 )
        name = functions.send( :extract_function_name, signature )
        return name
      end
    end

    context "simple function names" do
      it "extracts name from void function with void parameters" do
        signature = "void foo(void)"
        name = parse_name.call(signature)
        
        expect(name).to eq("foo")
      end

      it "extracts name from int function with no parameters" do
        signature = "int bar()"
        name = parse_name.call(signature)
        
        expect(name).to eq("bar")
      end

      it "extracts name from function with single parameter" do
        signature = "int add(int x)"
        name = parse_name.call(signature)
        
        expect(name).to eq("add")
      end

      it "extracts name from function with multiple parameters" do
        signature = "int multiply(int a, int b)"
        name = parse_name.call(signature)
        
        expect(name).to eq("multiply")
      end

      it "extracts name from function returning pointer" do
        signature = "char* getString(void)"
        name = parse_name.call(signature)
        
        expect(name).to eq("getString")
      end

      it "extracts name from function with pointer parameter" do
        signature = "void process(int* ptr)"
        name = parse_name.call(signature)
        
        expect(name).to eq("process")
      end
    end

    context "function names with whitespace variations" do
      it "extracts name with extra spaces before parenthesis" do
        signature = "int foo   (int x)"
        name = parse_name.call(signature)
        
        expect(name).to eq("foo")
      end

      it "extracts name with tabs before parenthesis" do
        signature = "int\tfoo\t(int x)"
        name = parse_name.call(signature)
        
        expect(name).to eq("foo")
      end

      it "extracts name with newlines before parenthesis" do
        signature = "int\nfoo\n(int x)"
        name = parse_name.call(signature)
        
        expect(name).to eq("foo")
      end

      it "extracts name with mixed whitespace" do
        signature = "int \t\n foo \t\n (int x)"
        name = parse_name.call(signature)
        
        expect(name).to eq("foo")
      end
    end

    context "complex return types" do
      it "extracts name from function returning struct" do
        signature = "struct point getPoint(void)"
        name = parse_name.call(signature)
        
        expect(name).to eq("getPoint")
      end

      it "extracts name from function returning pointer to struct" do
        signature = "struct node* getNode(void)"
        name = parse_name.call(signature)
        
        expect(name).to eq("getNode")
      end

      it "extracts name from function returning const pointer" do
        signature = "const char* getMessage(void)"
        name = parse_name.call(signature)
        
        expect(name).to eq("getMessage")
      end

      it "extracts name from function returning pointer to const" do
        signature = "char* const getBuffer(void)"
        name = parse_name.call(signature)
        
        expect(name).to eq("getBuffer")
      end

      it "extracts name from function returning unsigned type" do
        signature = "unsigned int getValue(void)"
        name = parse_name.call(signature)
        
        expect(name).to eq("getValue")
      end

      it "extracts name from function returning long long" do
        signature = "long long getBigValue(void)"
        name = parse_name.call(signature)
        
        expect(name).to eq("getBigValue")
      end

      it "extracts name from function returning enum" do
        signature = "enum status getStatus(void)"
        name = parse_name.call(signature)
        
        expect(name).to eq("getStatus")
      end

      it "extracts name from function returning typedef'd type" do
        signature = "size_t getSize(void)"
        name = parse_name.call(signature)
        
        expect(name).to eq("getSize")
      end

      it "extracts name from function returning double pointer" do
        signature = "char** getStringArray(void)"
        name = parse_name.call(signature)
        
        expect(name).to eq("getStringArray")
      end
    end

    context "function names with storage class specifiers" do
      it "extracts name from static function" do
        signature = "static int helper(void)"
        name = parse_name.call(signature)
        
        expect(name).to eq("helper")
      end

      it "extracts name from inline function" do
        signature = "inline int fast(void)"
        name = parse_name.call(signature)
        
        expect(name).to eq("fast")
      end

      it "extracts name from extern function" do
        signature = "extern void external(void)"
        name = parse_name.call(signature)
        
        expect(name).to eq("external")
      end

      it "extracts name from static inline function" do
        signature = "static inline int optimize(void)"
        name = parse_name.call(signature)
        
        expect(name).to eq("optimize")
      end
    end

    context "function names with qualifiers" do
      it "extracts name from function with const qualifier" do
        signature = "const int getValue(void)"
        name = parse_name.call(signature)
        
        expect(name).to eq("getValue")
      end

      it "extracts name from function with volatile qualifier" do
        signature = "volatile int getRegister(void)"
        name = parse_name.call(signature)
        
        expect(name).to eq("getRegister")
      end

      it "extracts name from function with multiple qualifiers" do
        signature = "static const volatile int getSpecial(void)"
        name = parse_name.call(signature)
        
        expect(name).to eq("getSpecial")
      end
    end

    context "function names with nested parentheses" do
      it "extracts name from function pointer return type" do
        signature = "int (*getFunction(void))(int, int)"
        name = parse_name.call(signature)
        
        expect(name).to eq("getFunction")
      end

      it "extracts name from function with function pointer parameter" do
        signature = "void sort(int* array, int (*compare)(int, int))"
        name = parse_name.call(signature)
        
        expect(name).to eq("sort")
      end

      it "extracts name from function with multiple function pointer parameters" do
        signature = "void process(void (*init)(void), void (*cleanup)(void))"
        name = parse_name.call(signature)
        
        expect(name).to eq("process")
      end

      it "extracts name from function with nested function pointers" do
        signature = "void register(void (*callback)(int (*)(void)))"
        name = parse_name.call(signature)
        
        expect(name).to eq("register")
      end

      it "extracts name from function with array of function pointers" do
        signature = "void dispatch(void (*handlers[])(int))"
        name = parse_name.call(signature)
        
        expect(name).to eq("dispatch")
      end
    end

    context "function names with underscores and naming conventions" do
      it "extracts name with leading underscore" do
        signature = "void _internal(void)"
        name = parse_name.call(signature)
        
        expect(name).to eq("_internal")
      end

      it "extracts name with double leading underscore" do
        signature = "void __private(void)"
        name = parse_name.call(signature)
        
        expect(name).to eq("__private")
      end

      it "extracts name with trailing underscore" do
        signature = "void function_(void)"
        name = parse_name.call(signature)
        
        expect(name).to eq("function_")
      end

      it "extracts name with multiple underscores" do
        signature = "void my_long_function_name(void)"
        name = parse_name.call(signature)
        
        expect(name).to eq("my_long_function_name")
      end

      it "extracts camelCase name" do
        signature = "void myFunctionName(void)"
        name = parse_name.call(signature)
        
        expect(name).to eq("myFunctionName")
      end

      it "extracts PascalCase name" do
        signature = "void MyFunctionName(void)"
        name = parse_name.call(signature)
        
        expect(name).to eq("MyFunctionName")
      end

      it "extracts UPPER_CASE name" do
        signature = "void MY_FUNCTION(void)"
        name = parse_name.call(signature)
        
        expect(name).to eq("MY_FUNCTION")
      end
    end

    context "function names with numbers" do
      it "extracts name with trailing number" do
        signature = "void function1(void)"
        name = parse_name.call(signature)
        
        expect(name).to eq("function1")
      end

      it "extracts name with embedded numbers" do
        signature = "void func2tion3(void)"
        name = parse_name.call(signature)
        
        expect(name).to eq("func2tion3")
      end

      it "extracts name with multiple numbers" do
        signature = "void test123(void)"
        name = parse_name.call(signature)
        
        expect(name).to eq("test123")
      end
    end

    context "real-world C function patterns" do
      it "extracts name from main function" do
        signature = "int main(int argc, char* argv[])"
        name = parse_name.call(signature)
        
        expect(name).to eq("main")
      end

      it "extracts name from signal handler" do
        signature = "void signal_handler(int signum)"
        name = parse_name.call(signature)
        
        expect(name).to eq("signal_handler")
      end

      it "extracts name from qsort compare function" do
        signature = "int compare(const void* a, const void* b)"
        name = parse_name.call(signature)
        
        expect(name).to eq("compare")
      end

      it "extracts name from pthread function" do
        signature = "void* thread_function(void* arg)"
        name = parse_name.call(signature)
        
        expect(name).to eq("thread_function")
      end

      it "extracts name from interrupt handler with attributes" do
        signature = "void __attribute__((interrupt)) ISR_Handler(void)"
        name = parse_name.call(signature)
        
        expect(name).to eq("ISR_Handler")
      end

      it "extracts name from constructor function" do
        signature = "void __attribute__((constructor)) init_module(void)"
        name = parse_name.call(signature)
        
        expect(name).to eq("init_module")
      end

      it "extracts name from destructor function" do
        signature = "void __attribute__((destructor)) cleanup_module(void)"
        name = parse_name.call(signature)
        
        expect(name).to eq("cleanup_module")
      end
    end

    context "edge cases" do
      it "extracts name from very long signature" do
        params = (1..50).map { |i| "int param#{i}" }.join(", ")
        signature = "void longFunctionName(#{params})"
        name = parse_name.call(signature)
        
        expect(name).to eq("longFunctionName")
      end

      it "extracts name with deeply nested parentheses in parameters" do
        signature = "void complex(int (*(*f)(int (*)(void)))(void))"
        name = parse_name.call(signature)
        
        expect(name).to eq("complex")
      end

      it "extracts name from function with array parameters with sizes" do
        signature = "void matrix(int arr[10][20][30])"
        name = parse_name.call(signature)
        
        expect(name).to eq("matrix")
      end

      it "extracts name from function with variadic parameters" do
        signature = "int printf(const char* format, ...)"
        name = parse_name.call(signature)
        
        expect(name).to eq("printf")
      end

      it "extracts name from function with restrict qualifier" do
        signature = "void copy(char* restrict dest, const char* restrict src)"
        name = parse_name.call(signature)
        
        expect(name).to eq("copy")
      end

      it "extracts name from function with _Noreturn specifier" do
        signature = "_Noreturn void exit_program(int code)"
        name = parse_name.call(signature)
        
        expect(name).to eq("exit_program")
      end

      it "extracts name from function with __declspec" do
        signature = "__declspec(dllexport) void exported_function(void)"
        name = parse_name.call(signature)
        
        expect(name).to eq("exported_function")
      end

      it "extracts name from function with multiple pointer levels" do
        signature = "void*** getTriplePointer(void)"
        name = parse_name.call(signature)
        
        expect(name).to eq("getTriplePointer")
      end

      it "extracts name from function with const pointer to const" do
        signature = "const char* const getConstString(void)"
        name = parse_name.call(signature)
        
        expect(name).to eq("getConstString")
      end

      it "extracts name from function with volatile pointer" do
        signature = "volatile int* getVolatilePtr(void)"
        name = parse_name.call(signature)
        
        expect(name).to eq("getVolatilePtr")
      end

      it "extracts name from function with struct tag and pointer" do
        signature = "struct my_struct* create_struct(void)"
        name = parse_name.call(signature)
        
        expect(name).to eq("create_struct")
      end

      it "extracts name from function with union return type" do
        signature = "union data getData(void)"
        name = parse_name.call(signature)
        
        expect(name).to eq("getData")
      end

      it "extracts name from function with typedef'd struct" do
        signature = "MyStruct_t createMyStruct(void)"
        name = parse_name.call(signature)
        
        expect(name).to eq("createMyStruct")
      end

      it "extracts name from function with anonymous struct parameter" do
        signature = "void process(struct { int x; int y; } point)"
        name = parse_name.call(signature)
        
        expect(name).to eq("process")
      end

      it "extracts name from function with bit field in struct parameter" do
        signature = "void setBits(struct flags { unsigned int a:1; unsigned int b:1; } f)"
        name = parse_name.call(signature)
        
        expect(name).to eq("setBits")
      end

      it "extracts name from function with complex spacing around asterisks" do
        signature = "char * * * getMultiPointer(void)"
        name = parse_name.call(signature)
        
        expect(name).to eq("getMultiPointer")
      end

      it "extracts name from function with register storage class" do
        signature = "register int fastFunction(void)"
        name = parse_name.call(signature)
        
        expect(name).to eq("fastFunction")
      end

      it "extracts name from function with auto storage class" do
        signature = "auto void localFunction(void)"
        name = parse_name.call(signature)
        
        expect(name).to eq("localFunction")
      end

      it "extracts name from function with _Thread_local specifier" do
        signature = "_Thread_local int getThreadLocal(void)"
        name = parse_name.call(signature)
        
        expect(name).to eq("getThreadLocal")
      end

      it "extracts name from function with _Atomic qualifier" do
        signature = "_Atomic int getAtomic(void)"
        name = parse_name.call(signature)
        
        expect(name).to eq("getAtomic")
      end

      it "extracts name from function with _Bool return type" do
        signature = "_Bool isValid(void)"
        name = parse_name.call(signature)
        
        expect(name).to eq("isValid")
      end

      it "extracts name from function with _Complex type" do
        signature = "double _Complex getComplex(void)"
        name = parse_name.call(signature)
        
        expect(name).to eq("getComplex")
      end

      it "extracts name from function with _Imaginary type" do
        signature = "double _Imaginary getImaginary(void)"
        name = parse_name.call(signature)
        
        expect(name).to eq("getImaginary")
      end

      it "extracts name from function with GCC __attribute__ before name" do
        signature = "void __attribute__((always_inline)) inlineFunc(void)"
        name = parse_name.call(signature)
        
        expect(name).to eq("inlineFunc")
      end

      it "extracts name from function with multiple __attribute__ specifiers" do
        signature = "void __attribute__((noreturn)) __attribute__((cold)) exitFunc(void)"
        name = parse_name.call(signature)
        
        expect(name).to eq("exitFunc")
      end

      it "extracts name from function with __asm__ label" do
        signature = "void myFunction(void) __asm__(\"_myFunction\")"
        name = parse_name.call(signature)
        
        expect(name).to eq("myFunction")
      end

      it "extracts name from function with Windows calling convention" do
        signature = "void __stdcall WindowsFunc(void)"
        name = parse_name.call(signature)
        
        expect(name).to eq("WindowsFunc")
      end

      it "extracts name from function with __cdecl calling convention" do
        signature = "void __cdecl CFunc(void)"
        name = parse_name.call(signature)
        
        expect(name).to eq("CFunc")
      end

      it "extracts name from function with __fastcall calling convention" do
        signature = "void __fastcall FastFunc(void)"
        name = parse_name.call(signature)
        
        expect(name).to eq("FastFunc")
      end

      it "extracts name from function with mixed qualifiers and specifiers" do
        signature = "static inline const volatile unsigned long long int complexFunc(void)"
        name = parse_name.call(signature)
        
        expect(name).to eq("complexFunc")
      end

      it "extracts name from function with array of pointers parameter" do
        signature = "void processArray(int* arr[10])"
        name = parse_name.call(signature)
        
        expect(name).to eq("processArray")
      end

      it "extracts name from function with pointer to array parameter" do
        signature = "void processPointerToArray(int (*arr)[10])"
        name = parse_name.call(signature)
        
        expect(name).to eq("processPointerToArray")
      end

      it "extracts name from function with array of function pointers" do
        signature = "void dispatch(void (*handlers[10])(int))"
        name = parse_name.call(signature)
        
        expect(name).to eq("dispatch")
      end

      it "extracts name from function returning pointer to array" do
        signature = "int (*getArray(void))[10]"
        name = parse_name.call(signature)
        
        expect(name).to eq("getArray")
      end

      it "extracts name from function with VLA parameter" do
        signature = "void processVLA(int n, int arr[n])"
        name = parse_name.call(signature)
        
        expect(name).to eq("processVLA")
      end

      it "extracts name from function with static array parameter" do
        signature = "void processStatic(int arr[static 10])"
        name = parse_name.call(signature)
        
        expect(name).to eq("processStatic")
      end

      it "extracts name from function with restrict and const" do
        signature = "void copy(char* restrict const dest, const char* restrict src)"
        name = parse_name.call(signature)
        
        expect(name).to eq("copy")
      end
    end

    context "malformed or unusual signatures" do
      it "returns nil for empty signature" do
        signature = ""
        name = parse_name.call(signature)
        
        expect(name).to be_nil
      end

      it "returns nil for signature with no parentheses" do
        signature = "void foo"
        name = parse_name.call(signature)
        
        expect(name).to be_nil
      end

      it "returns nil for signature with only return type" do
        signature = "int"
        name = parse_name.call(signature)
        
        expect(name).to be_nil
      end

      it "returns nil for signature with only opening parenthesis" do
        signature = "void foo("
        name = parse_name.call(signature)
        
        expect(name).to be_nil
      end

      it "return nil for signature with unbalanced parentheses" do
        signature = "void foo(int x"
        name = parse_name.call(signature)
        
        expect(name).to be_nil
      end
    end
  end
end