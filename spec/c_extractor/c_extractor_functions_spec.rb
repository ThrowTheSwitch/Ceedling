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
      ->(content, type, max_line_length=1000) do
        scanner = StringScanner.new(content)
        functions = CExtractorFunctions.new(
          CExtractorCodeText.new(),
          max_line_length
        )
        signature = functions.send( :extract_function_signature, scanner, type )
        return [signature, scanner.pos, scanner.rest]
      end
    end

    context "simple function signatures" do
      it "extracts void function signature with void parameters" do
        content = "void foo(void){"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("void foo(void)")
        expect(pos).to eq(14)
        expect(rest).to eq("{")
      end

      it "extracts void function signature with no parameters" do
        content = "void foo(){"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("void foo()")
        expect(pos).to eq(10)
        expect(rest).to eq("{")
      end

      it "extracts void function signature with no parameters and brace after newline" do
        content = "void foo()\n{"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("void foo()")
        expect(pos).to eq(11)
        expect(rest).to eq("{")
      end

      it "extracts int function signature with no parameters and whitespace between signature and function body brace" do
        content = "int bar(void)    {"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("int bar(void)")
        expect(pos).to eq(17)
        expect(rest).to eq("{")
      end

      it "extracts signature followed by line comment" do
        content = "void foo(void) // comment\n{"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("void foo(void)")
        expect(pos).to eq(26)
        expect(rest).to eq("{")
      end
      
      it "extracts function signature with single parameter and comment between signature and function body brace" do
        content = "int add(int x)/* */{ int a;"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("int add(int x)")
        expect(pos).to eq(19)
        expect(rest).to eq("{ int a;")
      end

      it "extracts function signature with multiple parameters" do
        content = "int multiply(int a, int b){"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("int multiply(int a, int b)")
        expect(pos).to eq(26)
        expect(rest).to eq("{")
      end

      it "extracts function signature returning pointer" do
        content = "char* getString(void){"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("char* getString(void)")
        expect(pos).to eq(21)
        expect(rest).to eq("{")
      end

      it "extracts function signature with pointer parameter" do
        content = "void process(int* ptr){"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("void process(int* ptr)")
        expect(pos).to eq(22)
        expect(rest).to eq("{")
      end
    end

    context "function declarations" do    
      it "does not extract signature from declaration" do
        content = "void process(int* ptr);"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to be_nil
        expect(pos).to eq(0)
        expect(rest).to eq("void process(int* ptr);")
      end

      it "does not extract signature from declaration with whitespace" do
        content = "void process(int* ptr)     ;"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to be_nil
        expect(pos).to eq(0)
        expect(rest).to eq("void process(int* ptr)     ;")
      end

      it "does not extract signature from declaration with comment" do
        content = "void process(int* ptr)/***/;"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to be_nil
        expect(pos).to eq(0)
        expect(rest).to eq("void process(int* ptr)/***/;")
      end

      it "does not extract signature from declaration with newline" do
        content = "void process(int* ptr)\n;"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to be_nil
        expect(pos).to eq(0)
        expect(rest).to eq("void process(int* ptr)\n;")
      end
    end

    context "function signatures with whitespace variations" do
      it "extracts signature with extra spaces" do
        content = "int    foo   (  int   x  ){"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("int foo ( int x )")
        expect(pos).to eq(26)
        expect(rest).to eq("{")
      end

      it "extracts clean signature from one with tabs" do
        content = "int\tfoo\t(\tint\tx\t){"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("int foo ( int x )")
        expect(pos).to eq(17)
        expect(rest).to eq("{")
      end

      it "extracts clean signature from one with newlines" do
        content = "int\nfoo\n(\nint x\n){"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("int foo ( int x )")
        expect(pos).to eq(17)
        expect(rest).to eq("{")
      end

      it "extracts clean signature from one with mixed whitespace" do
        content = "int \t\n foo \t\n ( \t\n int x \t\n ){"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("int foo ( int x )")
        expect(pos).to eq(29)
        expect(rest).to eq("{")
      end
    end

    context "complex return types" do
      it "extracts function returning struct" do
        content = "struct point getPoint(void){"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("struct point getPoint(void)")
        expect(pos).to eq(27)
        expect(rest).to eq("{")
      end

      it "extracts function returning pointer to struct" do
        content = "struct node* getNode(void){"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("struct node* getNode(void)")
        expect(pos).to eq(26)
        expect(rest).to eq("{")
      end

      it "extracts function returning const pointer" do
        content = "const char* getMessage(void){"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("const char* getMessage(void)")
        expect(pos).to eq(28)
        expect(rest).to eq("{")
      end

      it "extracts function returning pointer to const" do
        content = "char* const getBuffer(void){"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("char* const getBuffer(void)")
        expect(pos).to eq(27)
        expect(rest).to eq("{")
      end

      it "extracts function returning unsigned type" do
        content = "unsigned int getValue(void){"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("unsigned int getValue(void)")
        expect(pos).to eq(27)
        expect(rest).to eq("{")
      end

      it "extracts function returning long long" do
        content = "long long getBigValue(void){"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("long long getBigValue(void)")
        expect(pos).to eq(27)
        expect(rest).to eq("{")
      end

      it "extracts function returning enum" do
        content = "enum status getStatus(void){"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("enum status getStatus(void)")
        expect(pos).to eq(27)
        expect(rest).to eq("{")
      end

      it "extracts function returning typedef'd type" do
        content = "size_t getSize(void){"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("size_t getSize(void)")
        expect(pos).to eq(20)
        expect(rest).to eq("{")
      end

      it "extracts function returning double pointer" do
        content = "char** getStringArray(void){"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("char** getStringArray(void)")
        expect(pos).to eq(27)
        expect(rest).to eq("{")
      end
    end

    context "complex parameter types" do
      it "extracts function with array parameter" do
        content = "void process(int arr[]){"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("void process(int arr[])")
        expect(pos).to eq(23)
        expect(rest).to eq("{")
      end

      it "extracts function with sized array parameter" do
        content = "void process(int arr[10]){"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("void process(int arr[10])")
        expect(pos).to eq(25)
        expect(rest).to eq("{")
      end

      it "extracts function with const parameter" do
        content = "void print(const char* str){"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("void print(const char* str)")
        expect(pos).to eq(27)
        expect(rest).to eq("{")
      end

      it "extracts function with struct parameter" do
        content = "void update(struct data d){"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("void update(struct data d)")
        expect(pos).to eq(26)
        expect(rest).to eq("{")
      end

      it "extracts function with pointer to struct parameter" do
        content = "void modify(struct node* n){"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("void modify(struct node* n)")
        expect(pos).to eq(27)
        expect(rest).to eq("{")
      end

      it "extracts function with multiple complex parameters" do
        content = "int compare(const char* s1, const char* s2, size_t len){"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("int compare(const char* s1, const char* s2, size_t len)")
        expect(pos).to eq(55)
        expect(rest).to eq("{")
      end

      it "extracts function with function pointer parameter" do
        content = "void callback(void (*func)(int)){"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("void callback(void (*func)(int))")
        expect(pos).to eq(32)
        expect(rest).to eq("{")
      end

      it "extracts function with complex function pointer parameter" do
        content = "void register(int (*compare)(const void*, const void*)){"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("void register(int (*compare)(const void*, const void*))")
        expect(pos).to eq(55)
        expect(rest).to eq("{")
      end

      it "extracts function with double pointer parameter" do
        content = "void allocate(char** buffer){"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("void allocate(char** buffer)")
        expect(pos).to eq(28)
        expect(rest).to eq("{")
      end

      it "extracts function with enum parameter" do
        content = "void setState(enum state s){"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("void setState(enum state s)")
        expect(pos).to eq(27)
        expect(rest).to eq("{")
      end
    end

    context "function signatures with storage class specifiers" do
      it "extracts static function" do
        content = "static int helper(void){"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("static int helper(void)")
        expect(pos).to eq(23)
        expect(rest).to eq("{")
      end

      it "extracts inline function" do
        content = "inline int fast(void){"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("inline int fast(void)")
        expect(pos).to eq(21)
        expect(rest).to eq("{")
      end

      it "extracts extern function" do
        content = "extern void external(void){"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("extern void external(void)")
        expect(pos).to eq(26)
        expect(rest).to eq("{")
      end

      it "extracts static inline function" do
        content = "static inline int optimize(void){"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("static inline int optimize(void)")
        expect(pos).to eq(32)
        expect(rest).to eq("{")
      end
    end

    context "function signatures with qualifiers" do
      it "extracts function with const qualifier" do
        content = "const int getValue(void){"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("const int getValue(void)")
        expect(pos).to eq(24)
        expect(rest).to eq("{")
      end

      it "extracts function with volatile qualifier" do
        content = "volatile int getRegister(void){"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("volatile int getRegister(void)")
        expect(pos).to eq(30)
        expect(rest).to eq("{")
      end

      it "extracts function with restrict qualifier" do
        content = "void copy(char* restrict dest, const char* restrict src){"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("void copy(char* restrict dest, const char* restrict src)")
        expect(pos).to eq(56)
        expect(rest).to eq("{")
      end

      it "extracts function with multiple qualifiers" do
        content = "static const volatile int getSpecial(void){"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("static const volatile int getSpecial(void)")
        expect(pos).to eq(42)
        expect(rest).to eq("{")
      end
    end

    context "function signatures with variadic parameters" do
      it "extracts function with variadic parameters" do
        content = "int printf(const char* format, ...){"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("int printf(const char* format, ...)")
        expect(pos).to eq(35)
        expect(rest).to eq("{")
      end

      it "extracts function with only variadic parameters" do
        content = "void log(...){"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("void log(...)")
        expect(pos).to eq(13)
        expect(rest).to eq("{")
      end

      it "extracts function with multiple parameters and variadic" do
        content = "int sprintf(char* buffer, const char* format, ...){"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("int sprintf(char* buffer, const char* format, ...)")
        expect(pos).to eq(50)
        expect(rest).to eq("{")
      end
    end

    context "function signatures with nested parentheses" do
      it "extracts signature with function pointer return type" do
        content = "int (*getFunction(void))(int, int){"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("int (*getFunction(void))(int, int)")
        expect(pos).to eq(34)
        expect(rest).to eq("{")
      end

      it "extracts signature with complex function pointer parameter" do
        content = "void sort(int* array, int (*compare)(int, int)){"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("void sort(int* array, int (*compare)(int, int))")
        expect(pos).to eq(47)
        expect(rest).to eq("{")
      end

      it "extracts signature with multiple function pointer parameters" do
        content = "void process(void (*init)(void), void (*cleanup)(void)){"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("void process(void (*init)(void), void (*cleanup)(void))")
        expect(pos).to eq(55)
        expect(rest).to eq("{")
      end

      it "extracts signature with nested function pointers" do
        content = "void register(void (*callback)(int (*)(void))){"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("void register(void (*callback)(int (*)(void)))")
        expect(pos).to eq(46)
        expect(rest).to eq("{")
      end

      it "extracts signature with array of function pointers" do
        content = "void dispatch(void (*handlers[])(int)){"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("void dispatch(void (*handlers[])(int))")
        expect(pos).to eq(38)
        expect(rest).to eq("{")
      end
    end

    context "function signatures with strings and comments" do
      it "extracts signature with string in default parameter (C++ style, but testing robustness)" do
        content = 'void log(const char* msg = "default"){'
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq('void log(const char* msg = "default")')
        expect(pos).to eq(37)
        expect(rest).to eq("{")
      end

      it "extracts signature with parentheses in string" do
        content = 'void print(const char* format = "value: (%d)"){'
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq('void print(const char* format = "value: (%d)")')
        expect(pos).to eq(46)
        expect(rest).to eq("{")
      end

      it "extracts signature with character literal containing parenthesis" do
        content = "void process(char c = ')'){"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("void process(char c = ')')")
        expect(pos).to eq(26)
        expect(rest).to eq("{")
      end
    end

    context "edge cases and boundary conditions" do
      it "extracts very long signature" do
        params = (1..50).map { |i| "int param#{i}" }.join(", ")
        content = "void longFunction(#{params})"
        signature, pos, rest = extract_signature.call(content + '{}', :definition)
        
        expect(signature).to eq(content)
        expect(pos).to eq(content.length)
        expect(rest).to eq("{}")
      end

      it "extracts signature with deeply nested parentheses" do
        content = "void complex(int (*(*(*f)(int))(int))(int)){"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("void complex(int (*(*(*f)(int))(int))(int))")
        expect(pos).to eq(43)
        expect(rest).to eq("{")
      end
    end

    context "real-world C function patterns" do
      it "extracts main function signature" do
        content = "int main(int argc, char* argv[]){"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("int main(int argc, char* argv[])")
        expect(pos).to eq(32)
        expect(rest).to eq("{")
      end

      it "extracts signal handler signature" do
        content = "void signal_handler(int signum){"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("void signal_handler(int signum)")
        expect(pos).to eq(31)
        expect(rest).to eq("{")
      end

      it "extracts qsort compare function signature" do
        content = "int compare(const void* a, const void* b){"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("int compare(const void* a, const void* b)")
        expect(pos).to eq(41)
        expect(rest).to eq("{")
      end

      it "extracts pthread function signature" do
        content = "void* thread_function(void* arg){"
        signature, pos, rest = extract_signature.call(content, :definition)
        
        expect(signature).to eq("void* thread_function(void* arg)")
        expect(pos).to eq(32)
        expect(rest).to eq("{")
      end

      it "extracts interrupt handler signature" do
        content = "void __attribute__((interrupt)) ISR_Handler(void){"
        signature, pos, rest = extract_signature.call(content, :definition)
        
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
        functions = CExtractorFunctions.new(
          CExtractorCodeText.new(),
          1000
        )
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

  ###
  ### try_extract_function_definition()
  ###

  describe "#try_extract_function_definition" do
    # Helper to access private method and extract function from content
    let(:try_extract) do
      ->(content) do
        scanner = StringScanner.new(content)
        functions = CExtractorFunctions.new(
          CExtractorCodeText.new(),
          1000
        )
        success, func = functions.try_extract_function_definition( scanner )
        return [success, func, scanner.pos, scanner.rest]
      end
    end

    context "successful function extraction" do
      it "extracts simple void function" do
        content = "void foo(void) { int a = 1; }"
        success, func, pos, rest = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("foo")
        expect(func.signature).to eq("void foo(void)")
        expect(func.body).to eq("{ int a = 1; }")
        expect(func.code_block).to eq(content)
        expect(func.line_count).to eq(1)
        expect(pos).to eq(content.length)
        expect(rest).to eq("")
      end

      it "extracts function with return value" do
        content = "int add(int a, int b) { return a + b; }"
        success, func, _, _ = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("add")
        expect(func.signature).to eq("int add(int a, int b)")
        expect(func.body).to eq("{ return a + b; }")
        expect(func.code_block).to eq(content)
        expect(func.line_count).to eq(1)
      end

      it "extracts multi-line function" do
        content = <<~CONTENT
        void process(void) {
          int x = 1;
          int y = 2;
          return x + y;
        }
        CONTENT
        
        success, func, _, _ = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("process")
        expect(func.signature).to eq("void process(void)")
        expect(func.body).to eq("{\n  int x = 1;\n  int y = 2;\n  return x + y;\n}")
        expect(func.code_block).to eq(content.strip())
        expect(func.line_count).to eq(5)
      end

      it "extracts function with nested braces" do
        content = "void nested(void) { if (x) { do_something(); } }"
        success, func, _, _ = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("nested")
        expect(func.signature).to eq("void nested(void)")
        expect(func.code_block).to eq(content)
        expect(func.body).to eq("{ if (x) { do_something(); } }")
      end

      it "extracts function with complex parameters" do
        content = "void callback(void (*func)(int), int* data) { func(*data); }"
        success, func, _, _ = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("callback")
        expect(func.signature).to eq("void callback(void (*func)(int), int* data)")
        expect(func.body).to eq("{ func(*data); }")
        expect(func.code_block).to eq(content)
      end

      it "extracts function with pointer return type" do
        content = "char* getString(void) { return \"hello\"; }"
        success, func, _, _ = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("getString")
        expect(func.signature).to eq("char* getString(void)")
        expect(func.body).to eq("{ return \"hello\"; }")
        expect(func.code_block).to eq(content)
      end

      it "extracts function with struct return type" do
        content = "struct point getPoint(void) { struct point p = {0, 0}; return p; }"
        success, func, _, _ = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("getPoint")
        expect(func.signature).to eq("struct point getPoint(void)")
        expect(func.body).to eq("{ struct point p = {0, 0}; return p; }")
        expect(func.code_block).to eq(content)
      end

      it "extracts static function" do
        content = "static int helper(void) { return 42; }"
        success, func, _, _ = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("helper")
        expect(func.signature).to eq("static int helper(void)")
        expect(func.body).to eq("{ return 42; }")
        expect(func.code_block).to eq(content)
      end

      it "extracts inline function" do
        content = "inline int fast(void) { return 1; }"
        success, func, _, _ = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("fast")
        expect(func.signature).to eq("inline int fast(void)")
        expect(func.body).to eq("{ return 1; }")
        expect(func.code_block).to eq(content)
      end

      it "extracts function with attributes" do
        content = "void __attribute__((interrupt)) ISR(void) { handle_interrupt(); }"
        success, func, _, _ = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("ISR")
        expect(func.signature).to eq("void __attribute__((interrupt)) ISR(void)")
        expect(func.body).to eq("{ handle_interrupt(); }")
        expect(func.code_block).to eq(content)
      end

      it "extracts function with whitespace before opening brace" do
        content = "void foo(void)   \n\t  { return; }"
        success, func, _, _ = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("foo")
        expect(func.signature).to eq("void foo(void)")
        expect(func.body).to eq("{ return; }")
        expect(func.code_block).to eq(content)
      end

      it "extracts function with array parameters" do
        content = "void process(int arr[10]) { arr[0] = 1; }"
        success, func, _, _ = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("process")
        expect(func.signature).to eq("void process(int arr[10])")
        expect(func.body).to eq("{ arr[0] = 1; }")
        expect(func.code_block).to eq(content)
      end

      it "extracts function with variadic parameters" do
        content = "int printf(const char* fmt, ...) { return 0; }"
        success, func, _, _ = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("printf")
        expect(func.signature).to eq("int printf(const char* fmt, ...)")
        expect(func.body).to eq("{ return 0; }")
        expect(func.code_block).to eq(content)
      end

      it "extracts function with const parameters" do
        content = "void print(const char* str) { puts(str); }"
        success, func, _, _ = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("print")
        expect(func.signature).to eq("void print(const char* str)")
        expect(func.body).to eq("{ puts(str); }")
        expect(func.code_block).to eq(content)
      end

      it "extracts function with volatile parameters" do
        content = "int read(volatile int* reg) { return *reg; }"
        success, func, _, _ = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("read")
        expect(func.signature).to eq("int read(volatile int* reg)")
        expect(func.body).to eq("{ return *reg; }")
        expect(func.code_block).to eq(content)
      end

      it "extracts function with restrict qualifier" do
        content = "void copy(char* restrict dst, const char* restrict src) { strcpy(dst, src); }"
        success, func, _, _ = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("copy")
        expect(func.signature).to eq("void copy(char* restrict dst, const char* restrict src)")
        expect(func.body).to eq("{ strcpy(dst, src); }")
        expect(func.code_block).to eq(content)
      end

      it "extracts function with deeply nested braces" do
        content = "void deep(void) { if (a) { while (b) { for (;;) { break; } } } }"
        success, func, _, _ = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("deep")
        expect(func.body).to eq("{ if (a) { while (b) { for (;;) { break; } } } }")
      end

      it "extracts function with string literals containing braces" do
        content = 'void print(void) { printf("{ } braces"); }'
        success, func, _, _ = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("print")
        expect(func.body).to eq('{ printf("{ } braces"); }')
      end

      it "extracts function with character literals containing braces" do
        content = "void check(void) { char c = '{'; }"
        success, func, _, _ = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("check")
        expect(func.body).to eq("{ char c = '{'; }")
      end

      it "extracts function with comments containing braces" do
        content = "void func(void) { /* { comment } */ int x = 1; }"
        success, func, _, _ = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("func")
        expect(func.body).to eq("{ /* { comment } */ int x = 1; }")
      end

      it "extracts function with line comments containing braces" do
        content = "void func(void) { // { comment }\nint x = 1; }"
        success, func, _, _ = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("func")
        expect(func.body).to eq("{ // { comment }\nint x = 1; }")
      end

      it "extracts function with struct initialization" do
        content = "void init(void) { struct point p = {1, 2}; }"
        success, func, _, _ = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("init")
        expect(func.body).to eq("{ struct point p = {1, 2}; }")
      end

      it "extracts function with array initialization" do
        content = "void setup(void) { int arr[] = {1, 2, 3}; }"
        success, func, _, _ = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("setup")
        expect(func.body).to eq("{ int arr[] = {1, 2, 3}; }")
      end

      it "extracts function with compound literal" do
        content = "void use(void) { process((struct point){1, 2}); }"
        success, func, _, _ = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("use")
        expect(func.body).to eq("{ process((struct point){1, 2}); }")
      end

      it "extracts function with designated initializers" do
        content = "void init(void) { struct point p = {.x = 1, .y = 2}; }"
        success, func, _, _ = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("init")
        expect(func.body).to eq("{ struct point p = {.x = 1, .y = 2}; }")
      end
    end

    context "function extraction with various body styles" do
      it "extracts function with empty body" do
        content = "void empty(void) {}"
        success, func, _, _ = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("empty")
        expect(func.body).to eq("{}")
        expect(func.line_count).to eq(1)
      end

      it "extracts function with only whitespace in body" do
        content = "void whitespace(void) {   \n\t  }"
        success, func, _, _ = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("whitespace")
        expect(func.body).to eq("{   \n\t  }")
      end

      it "extracts function with single statement" do
        content = "void single(void) { return; }"
        success, func, _, _ = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("single")
        expect(func.body).to eq("{ return; }")
      end

      it "extracts function with multiple statements" do
        content = "void multi(void) { int a = 1; int b = 2; return; }"
        success, func, _, _ = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("multi")
        expect(func.body).to eq("{ int a = 1; int b = 2; return; }")
      end

      it "extracts function with switch statement" do
        content = "void switcher(int x) { switch(x) { case 1: break; default: break; } }"
        success, func, _, _ = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("switcher")
        expect(func.body).to eq("{ switch(x) { case 1: break; default: break; } }")
      end

      it "extracts function with do-while loop" do
        content = "void loop(void) { do { work(); } while(condition); }"
        success, func, _, _ = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("loop")
        expect(func.body).to eq("{ do { work(); } while(condition); }")
      end

      it "extracts function with for loop" do
        content = "void iterate(void) { for(int i = 0; i < 10; i++) { process(i); } }"
        success, func, _, _ = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("iterate")
        expect(func.body).to eq("{ for(int i = 0; i < 10; i++) { process(i); } }")
      end

      it "extracts function with while loop" do
        content = "void wait(void) { while(ready()) { check(); } }"
        success, func, _, _ = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("wait")
        expect(func.body).to eq("{ while(ready()) { check(); } }")
      end

      it "extracts function with if-else chain" do
        content = "void decide(int x) { if(x > 0) { pos(); } else if(x < 0) { neg(); } else { zero(); } }"
        success, func, _, _ = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("decide")
        expect(func.body).to eq("{ if(x > 0) { pos(); } else if(x < 0) { neg(); } else { zero(); } }")
      end

      it "extracts function with ternary operator" do
        content = "int max(int a, int b) { return a > b ? a : b; }"
        success, func, _, _ = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("max")
        expect(func.body).to eq("{ return a > b ? a : b; }")
      end

      it "extracts function with goto statement" do
        content = "void jump(void) { goto label; label: return; }"
        success, func, _, _ = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("jump")
        expect(func.body).to eq("{ goto label; label: return; }")
      end

      it "extracts function with labeled statement" do
        content = "void labeled(void) { start: process(); goto start; }"
        success, func, _, _ = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("labeled")
        expect(func.body).to eq("{ start: process(); goto start; }")
      end
    end

    context "function extraction with preprocessor directives in body" do
      it "extracts function with #ifdef in body" do
        content = "void conditional(void) { #ifdef DEBUG\nlog();\n#endif\n }"
        success, func, _, _ = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("conditional")
        expect(func.body).to eq("{ #ifdef DEBUG\nlog();\n#endif\n }")
      end

      it "extracts function with #define in body" do
        content = "void macro(void) { #define LOCAL 1\nint x = LOCAL; }"
        success, func, _, _ = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("macro")
        expect(func.body).to eq("{ #define LOCAL 1\nint x = LOCAL; }")
      end

      it "extracts function with #include in body" do
        content = "void include(void) { #include \"local.h\"\nuse_local(); }"
        success, func, _, _ = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("include")
        expect(func.body).to eq("{ #include \"local.h\"\nuse_local(); }")
      end

      it "extracts function with #pragma in body" do
        content = "void pragma(void) { #pragma pack(1)\nstruct s { int x; }; }"
        success, func, _, _ = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("pragma")
        expect(func.body).to eq("{ #pragma pack(1)\nstruct s { int x; }; }")
      end

      it "extracts function with #error in body" do
        content = "void error(void) { #error \"Not implemented\"\n }"
        success, func, _, _ = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("error")
        expect(func.body).to eq("{ #error \"Not implemented\"\n }")
      end

      it "extracts function with #warning in body" do
        content = "void warning(void) { #warning \"Deprecated\"\nold_api(); }"
        success, func, _, _ = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("warning")
        expect(func.body).to eq("{ #warning \"Deprecated\"\nold_api(); }")
      end

      it "extracts function with multi-line macro in body" do
        content = "void multiline(void) { #define MACRO(x) \\\n  do { \\\n    work(x); \\\n  } while(0)\nMACRO(1); }"
        success, func, _, _ = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("multiline")
      end
    end

    context "function extraction with special characters and literals" do
      it "extracts function with escaped quotes in string" do
        content = 'void quotes(void) { printf("He said \"hello\""); }'
        success, func, _, _ = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("quotes")
        expect(func.body).to eq('{ printf("He said \"hello\""); }')
      end

      it "extracts function with escaped backslash in string" do
        content = 'void backslash(void) { printf("path\\\\file"); }'
        success, func, _, _ = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("backslash")
        expect(func.body).to eq('{ printf("path\\\\file"); }')
      end

      it "extracts function with newline in string" do
        content = 'void newline(void) { printf("line1\\nline2"); }'
        success, func, _, _ = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("newline")
        expect(func.body).to eq('{ printf("line1\\nline2"); }')
      end

      it "extracts function with tab in string" do
        content = 'void tab(void) { printf("col1\\tcol2"); }'
        success, func, _, _ = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("tab")
        expect(func.body).to eq('{ printf("col1\\tcol2"); }')
      end

      it "extracts function with hex escape in string" do
        content = 'void hex(void) { char c = "\\x41"; }'
        success, func, _, _ = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("hex")
        expect(func.body).to eq('{ char c = "\\x41"; }')
      end

      it "extracts function with octal escape in string" do
        content = 'void octal(void) { char c = "\\101"; }'
        success, func, _, _ = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("octal")
        expect(func.body).to eq('{ char c = "\\101"; }')
      end

      it "extracts function with raw string literal (C++11)" do
        content = 'void raw(void) { const char* s = R"(raw { } string)"; }'
        success, func, _, _ = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("raw")
        expect(func.body).to eq('{ const char* s = R"(raw { } string)"; }')
      end

      it "extracts function with multi-line string literal" do
        content = "void multiline(void) { printf(\"line1\"\n\"line2\"); }"
        success, func, _, _ = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("multiline")
        expect(func.body).to eq("{ printf(\"line1\"\n\"line2\"); }")
      end

      it "extracts function with character literal" do
        content = "void character(void) { char c = 'A'; }"
        success, func, _, _ = try_extract.call(content)
        
        expect(success).to be true
        expect(func.name).to eq("character")
        expect(func.body).to eq("{ char c = 'A'; }")
      end
    end

    context "extracting multiple functions from same content" do
      it "extracts two simple functions in sequence" do
        content = "void first(void) { int a = 1; }\nvoid second(void) { int b = 2; }"
        scanner = StringScanner.new(content)
        functions = CExtractorFunctions.new(
          CExtractorCodeText.new(),
          1000
        )
        
        success1, func1 = functions.try_extract_function_definition(scanner)
        expect(success1).to be true
        expect(func1.name).to eq("first")
        expect(func1.body).to eq("{ int a = 1; }")
                
        success2, func2 = functions.try_extract_function_definition(scanner)
        expect(success2).to be true
        expect(func2.name).to eq("second")
        expect(func2.body).to eq("{ int b = 2; }")
        
        expect(scanner.eos?).to be true
      end

      it "extracts three functions with different signatures" do
        content = <<~CONTENT
        int add(int a, int b) { return a + b; }

        void print(const char* msg) { printf("%s", msg); }

        static inline bool check(void) { return true; }

        CONTENT
        
        scanner = StringScanner.new(content)
        code_text = CExtractorCodeText.new()
        functions = CExtractorFunctions.new( code_text, 1000 )
        
        success1, func1 = functions.try_extract_function_definition(scanner)
        expect(success1).to be true
        expect(func1.name).to eq("add")
        expect(func1.signature).to eq("int add(int a, int b)")
                
        success2, func2 = functions.try_extract_function_definition(scanner)
        expect(success2).to be true
        expect(func2.name).to eq("print")
        expect(func2.signature).to eq("void print(const char* msg)")
                
        success3, func3 = functions.try_extract_function_definition(scanner)
        expect(success3).to be true
        expect(func3.name).to eq("check")
        expect(func3.signature).to eq("static inline bool check(void)")

        code_text.skip_deadspace(scanner)

        expect(scanner.eos?).to be true
      end

      it "extracts functions separated by comments" do
        content = <<~CONTENT
        void first(void) { work(); }
        // Comment between functions
        void second(void) { more_work(); }
        /* Multi-line comment
         * between functions
         */
        void third(void) { final_work(); }
        CONTENT
        
        scanner = StringScanner.new(content)
        functions = CExtractorFunctions.new(
          CExtractorCodeText.new(),
          1000
        )
        
        success1, func1 = functions.try_extract_function_definition(scanner)
        expect(success1).to be true
        expect(func1.name).to eq("first")
                
        success2, func2 = functions.try_extract_function_definition(scanner)
        expect(success2).to be true
        expect(func2.name).to eq("second")
                
        success3, func3 = functions.try_extract_function_definition(scanner)
        expect(success3).to be true
        expect(func3.name).to eq("third")
      end
    end
  end

end