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
        
        expect(signature).to eq(nil)
        expect(pos).to eq(23)
        expect(rest).to eq("")
      end

      it "does not extract signature from declaration with whitespace" do
        content = "void process(int* ptr)     ;"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq(nil)
        expect(pos).to eq(28)
        expect(rest).to eq("")
      end

      it "does not extract signature from declaration with comment" do
        content = "void process(int* ptr)/***/;"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq(nil)
        expect(pos).to eq(28)
        expect(rest).to eq("")
      end

      it "does not extract signature from declaration with newline" do
        content = "void process(int* ptr)\n;"
        signature, pos, rest = extract_signature.call(content)
        
        expect(signature).to eq(nil)
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

end