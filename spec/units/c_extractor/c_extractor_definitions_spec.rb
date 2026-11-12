# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'strscan'
require 'ceedling/c_extractor/c_extractor_code_text'
require 'ceedling/c_extractor/c_extractor_definitions'

describe CExtractorDefinitions do

  before(:each) do
    code_text    = CExtractorCodeText.new
    @definitions = described_class.new( { c_extractor_code_text: code_text } )
  end

  # ---------------------------------------------------------------------------
  context "#try_extract_typedef" do

    def try_typedef(text)
      scanner = StringScanner.new(text)
      result  = @definitions.try_extract_typedef(scanner)
      [result, scanner.pos]
    end

    # --- Failure cases ---

    # GCC and Clang accept '$' in an identifier, so a longer name only starts like the keyword
    it "returns [false, nil] for a name that only starts with typedef or struct" do
      result, pos = try_typedef('typedef$init(a);')
      expect(result).to eq [false, nil]
      expect(pos).to eq 0
      expect(@definitions.try_extract_aggregate_definition(StringScanner.new('struct$x(a) { 1; };'))).to eq [false, nil]
    end

    it "returns [false, nil] when scanner is not at typedef" do
      result, pos = try_typedef('int x;')
      expect(result).to eq [false, nil]
      expect(pos).to eq 0
    end

    it "returns [false, nil] for empty input" do
      result, pos = try_typedef('')
      expect(result).to eq [false, nil]
      expect(pos).to eq 0
    end

    it "does not advance scanner on failure" do
      scanner = StringScanner.new('int x;')
      @definitions.try_extract_typedef(scanner)
      expect(scanner.pos).to eq 0
    end

    it "returns [false, nil] when typedef has no terminating semicolon (EOF)" do
      result, _pos = try_typedef('typedef int MyInt')
      expect(result).to eq [false, nil]
    end

    # --- Simple scalar and pointer typedefs ---

    it "extracts a simple scalar typedef" do
      input = "typedef int MyInt;\n"
      result, pos = try_typedef(input)
      expect(result).to eq [true, input.chomp]
      expect(pos).to eq input.length
    end

    it "extracts a pointer typedef" do
      input = "typedef char* StringPtr;\n"
      result, pos = try_typedef(input)
      expect(result).to eq [true, input.chomp]
      expect(pos).to eq input.length
    end

    it "extracts a const pointer typedef" do
      input = "typedef const char* CStringPtr;\n"
      result, pos = try_typedef(input)
      expect(result).to eq [true, input.chomp]
      expect(pos).to eq input.length
    end

    it "extracts a typedef without trailing newline (EOS)" do
      input = "typedef int MyInt;"
      result, pos = try_typedef(input)
      expect(result).to eq [true, input]
      expect(pos).to eq input.length
    end

    # --- Function-pointer typedef ---

    it "extracts a function pointer typedef" do
      input = "typedef int (*Fn)(int, char*);\n"
      result, pos = try_typedef(input)
      expect(result).to eq [true, input.chomp]
      expect(pos).to eq input.length
    end

    it "extracts a void function pointer typedef with no parameters" do
      input = "typedef void (*Callback)(void);\n"
      result, pos = try_typedef(input)
      expect(result).to eq [true, input.chomp]
      expect(pos).to eq input.length
    end

    # --- Struct / union / enum with brace bodies ---

    it "extracts a single-line struct typedef" do
      input = "typedef struct { int x; int y; } Point;\n"
      result, pos = try_typedef(input)
      expect(result).to eq [true, input.chomp]
      expect(pos).to eq input.length
    end

    it "extracts a multiline struct typedef" do
      input = "typedef struct {\n  int x;\n  int y;\n} Point;\n"
      result, pos = try_typedef(input)
      expect(result).to eq [true, input.chomp]
      expect(pos).to eq input.length
    end

    it "extracts a struct typedef with a tag name" do
      input = "typedef struct Foo { int x; } Foo;\n"
      result, pos = try_typedef(input)
      expect(result).to eq [true, input.chomp]
      expect(pos).to eq input.length
    end

    it "extracts an enum typedef" do
      input = "typedef enum { RED, GREEN, BLUE } Color;\n"
      result, pos = try_typedef(input)
      expect(result).to eq [true, input.chomp]
      expect(pos).to eq input.length
    end

    it "extracts a multiline enum typedef" do
      input = "typedef enum {\n  RED,\n  GREEN,\n  BLUE\n} Color;\n"
      result, pos = try_typedef(input)
      expect(result).to eq [true, input.chomp]
      expect(pos).to eq input.length
    end

    it "extracts a union typedef" do
      input = "typedef union { int i; float f; } Number;\n"
      result, pos = try_typedef(input)
      expect(result).to eq [true, input.chomp]
      expect(pos).to eq input.length
    end

    it "extracts a forward-declaration struct typedef" do
      input = "typedef struct Foo Foo;\n"
      result, pos = try_typedef(input)
      expect(result).to eq [true, input.chomp]
      expect(pos).to eq input.length
    end

    it "extracts a struct with nested brace initializer in a member" do
      input = "typedef struct { int flags; struct { int a; int b; } nested; } Outer;\n"
      result, pos = try_typedef(input)
      expect(result).to eq [true, input.chomp]
      expect(pos).to eq input.length
    end

    # --- Comments replaced with a single space (not preserved verbatim) ---

    it "replaces a line comment inside the typedef body with a space" do
      input    = "typedef struct {\n  int x; // x coordinate\n  int y; // y coordinate\n} Point;\n"
      # Line comment (including its trailing \n) is replaced by one space;
      # following two-space indent is preserved, so 4 chars between x; and int y
      expected = "typedef struct {\n  int x;    int y;  } Point;"
      result, pos = try_typedef(input)
      expect(result).to eq [true, expected]
      expect(pos).to eq input.length
    end

    it "replaces a block comment inside the typedef body with a space" do
      input    = "typedef struct { int x; /* width */ int y; /* height */ } Rect;\n"
      # Each block comment → one space; the surrounding spaces are preserved
      # so 3 chars between x; and int y (original space + comment space + space-after-comment)
      expected = "typedef struct { int x;   int y;   } Rect;"
      result, pos = try_typedef(input)
      expect(result).to eq [true, expected]
      expect(pos).to eq input.length
    end

    it "replaces a block comment containing a semicolon with a space — does not terminate early" do
      input    = "typedef int /* looks; like; semicolons */ MyInt;\n"
      # original space before comment + comment space + space after comment = 3 spaces
      expected = "typedef int   MyInt;"
      result, pos = try_typedef(input)
      expect(result).to eq [true, expected]
      expect(pos).to eq input.length
    end

    # --- String literals: still preserved verbatim ---

    it "handles a string literal containing a semicolon" do
      input = "typedef char Delim[sizeof(\";\")];\n"
      result, pos = try_typedef(input)
      expect(result).to eq [true, input.chomp]
      expect(pos).to eq input.length
    end

    # --- Scanner position / boundary behaviour ---

    it "stops at the semicolon and does not consume following code" do
      input = "typedef int MyInt;\nint x = 0;"
      result, pos = try_typedef(input)
      expect(result).to eq [true, "typedef int MyInt;"]
      expect(pos).to eq "typedef int MyInt;\n".length
    end

    it "keeps a literal whole after text that isn't ASCII" do
      input = "typedef struct { char d[sizeof(\"é;\")]; } T;"
      scanner = StringScanner.new(input)
      expect(@definitions.try_extract_typedef(scanner)).to eq [true, input]
      expect(scanner.pos).to eq input.bytesize
    end

    it "leaves scanner position unchanged on failure" do
      scanner = StringScanner.new("int x;")
      scanner.pos = 0
      @definitions.try_extract_typedef(scanner)
      expect(scanner.pos).to eq 0
    end

  end  # #try_extract_typedef

  # ---------------------------------------------------------------------------
  context "#try_extract_aggregate_definition" do

    def try_aggregate(text)
      scanner = StringScanner.new(text)
      result  = @definitions.try_extract_aggregate_definition(scanner)
      [result, scanner.pos]
    end

    # --- Failure cases ---

    it "returns [false, nil] when scanner is not at struct/enum/union" do
      result, pos = try_aggregate('int x;')
      expect(result).to eq [false, nil]
      expect(pos).to eq 0
    end

    it "returns [false, nil] for empty input" do
      result, pos = try_aggregate('')
      expect(result).to eq [false, nil]
      expect(pos).to eq 0
    end

    it "does not advance scanner on failure" do
      scanner = StringScanner.new('int x;')
      @definitions.try_extract_aggregate_definition(scanner)
      expect(scanner.pos).to eq 0
    end

    # A tag alone declares a struct or union type, so it reads as one rather than as a variable
    it "extracts a forward declaration without body (struct Foo;)" do
      result, pos = try_aggregate('struct Foo;')
      expect(result).to eq [true, 'struct Foo;']
      expect(pos).to eq 11
    end

    it "extracts a forward declaration without body (union Word;)" do
      expect( try_aggregate('union Word;')[0] ).to eq [true, 'union Word;']
    end

    # C has no forward declaration of an enum
    it "returns [false, nil] for a forward declaration without body (enum Color;)" do
      result, pos = try_aggregate('enum Color;')
      expect(result).to eq [false, nil]
      expect(pos).to eq 0
    end

    it "returns [false, nil] and rolls scanner back to start when declarator follows '}'" do
      result, pos = try_aggregate('struct Foo { int x; } instance;')
      expect(result).to eq [false, nil]
      expect(pos).to eq 0
    end

    it "returns [false, nil] and rolls back for a pointer declarator after '}'" do
      result, pos = try_aggregate('struct Foo { int x; } *ptr;')
      expect(result).to eq [false, nil]
      expect(pos).to eq 0
    end

    it "returns [false, nil] when the body is missing a closing '}' (EOF)" do
      result, pos = try_aggregate('struct Foo { int x;')
      expect(result).to eq [false, nil]
      expect(pos).to eq 0
    end

    # --- struct ---

    it "extracts a named struct with a single-line body" do
      input = "struct Foo { int x; int y; };\n"
      result, pos = try_aggregate(input)
      expect(result).to eq [true, input.chomp]
      expect(pos).to eq input.length
    end

    it "extracts a named struct without trailing newline (EOS)" do
      input = "struct Foo { int x; };"
      result, pos = try_aggregate(input)
      expect(result).to eq [true, input]
      expect(pos).to eq input.length
    end

    it "extracts a named struct with a multiline body" do
      input = "struct Point {\n  int x;\n  int y;\n};\n"
      result, pos = try_aggregate(input)
      expect(result).to eq [true, input.chomp]
      expect(pos).to eq input.length
    end

    it "extracts a named struct when the closing '}' and terminating ';' fall on separate lines" do
      input = "struct Point {\n  int x;\n}\n;\n"
      result, pos = try_aggregate(input)
      expect(result).to eq [true, input.chomp]
      expect(pos).to eq input.length
    end

    it "extracts an anonymous struct (no tag name)" do
      input = "struct { int x; int y; };\n"
      result, pos = try_aggregate(input)
      expect(result).to eq [true, input.chomp]
      expect(pos).to eq input.length
    end

    # --- enum ---

    it "extracts a named enum with a single-line body" do
      input = "enum Color { RED, GREEN, BLUE };\n"
      result, pos = try_aggregate(input)
      expect(result).to eq [true, input.chomp]
      expect(pos).to eq input.length
    end

    it "extracts a named enum with a multiline body" do
      input = "enum Direction {\n  NORTH,\n  SOUTH,\n  EAST,\n  WEST\n};\n"
      result, pos = try_aggregate(input)
      expect(result).to eq [true, input.chomp]
      expect(pos).to eq input.length
    end

    it "extracts an anonymous enum" do
      input = "enum { A, B, C };\n"
      result, pos = try_aggregate(input)
      expect(result).to eq [true, input.chomp]
      expect(pos).to eq input.length
    end

    # --- union ---

    it "extracts a named union with a single-line body" do
      input = "union Data { int i; float f; };\n"
      result, pos = try_aggregate(input)
      expect(result).to eq [true, input.chomp]
      expect(pos).to eq input.length
    end

    # --- Nested bodies ---

    it "extracts a struct with a nested struct member body" do
      input = "struct Outer { struct Inner { int n; } inner; };\n"
      result, pos = try_aggregate(input)
      expect(result).to eq [true, input.chomp]
      expect(pos).to eq input.length
    end

    it "extracts deeply nested struct bodies" do
      input = "struct A { struct B { struct C { int x; } c; } b; };\n"
      result, pos = try_aggregate(input)
      expect(result).to eq [true, input.chomp]
      expect(pos).to eq input.length
    end

    # --- Comments replaced with a single space (not preserved verbatim) ---

    it "replaces a line comment inside the body with a space" do
      input    = "struct Foo {\n  int x; // x field\n  int y; // y field\n};\n"
      # Same space-count logic as typedef: orig space + comment space + 2-space indent = 4 before int y
      expected = "struct Foo {\n  int x;    int y;  };"
      result, pos = try_aggregate(input)
      expect(result).to eq [true, expected]
      expect(pos).to eq input.length
    end

    it "replaces a block comment inside the body with a space" do
      input    = "struct Foo { int x; /* width */ int y; /* height */ };\n"
      # Same as typedef: 3 chars between x; and int y (orig + comment + space-after-comment)
      expected = "struct Foo { int x;   int y;   };"
      result, pos = try_aggregate(input)
      expect(result).to eq [true, expected]
      expect(pos).to eq input.length
    end

    it "handles a block comment between '}' and ';' — still collects as standalone" do
      # Whitespace/comment in the lookahead region is committed verbatim (sliced from original string)
      input = "struct Foo { int x; } /* comment */;\n"
      result, pos = try_aggregate(input)
      expect(result[0]).to be true
      expect(pos).to eq input.length
    end

    # --- String literals: verbatim (';' inside does not terminate) ---

    it "handles a string literal containing ';' in a member" do
      input = "struct Foo { char delim[sizeof(\";\")]; };\n"
      result, pos = try_aggregate(input)
      expect(result).to eq [true, input.chomp]
      expect(pos).to eq input.length
    end

    # --- Whitespace between '}' and ';' ---

    it "handles whitespace between '}' and ';'" do
      input = "struct Foo { int x; }   ;\n"
      result, pos = try_aggregate(input)
      expect(result[0]).to be true
      expect(pos).to eq input.length
    end

    # --- The head ahead of the body ---

    # A variable's initializer and a function's body are braced too. The text ahead of the brace
    # tells them from a type's body.
    [
      "struct ops g_ops = { 1 };",
      "union u g_u = { 0 };",
      "struct ops *tbl[] = { &a1, &b1 };",
      "struct ops g_arr[2] = { {1}, {2} };",
      "struct ops g_a = { 1 }, g_b = { 2 };",
      "struct ops *make_ops(void) { return &k; };",
      "struct ops make_v(void) { struct ops o = { 1 }; return o; };",
      "struct ops (*get_ops(void)) { return 0; };",
      "struct ops (__stdcall *get_cb(void)) { return 0; };",
      "struct ops *make_q(const char *s, int n) { return &k; };",
      "struct ops __wrap_make(void) { return o; };",
      "struct ops *__wrap_make2(int a) { return &k; };"
    ].each do |input|
      it "rolls back for a variable or function with a braced body: #{input}" do
        result, pos = try_aggregate(input)
        expect(result).to eq [false, nil]
        expect(pos).to eq 0
      end
    end

    [
      "struct __attribute__((packed)) pk { char c; int i; };",
      "struct __attribute__((aligned(sizeof(int) == 4 ? 4 : 8))) al { int a; };",
      "struct __attribute__((section(\"a=b)\"))) sec { int a; };",
      "struct __declspec(align(16)) ds { int a; };",
      "struct [[gnu::packed]] c23 { char c; int i; };",
      "struct PACKED pm { char c; };",
      "struct ALIGNED(4) fm { int a; };",
      "struct FOO_TYPE(bar) { int baz; };",
      "struct __attribute__((packed)) FOO_TYPE(bar) { int baz; };",
      "struct PACKED FOO_TYPE(bar) { int baz; };",
      "struct ALIGN(4) FOO_TYPE(bar, 2) { int baz; };",
      "struct ALIGN_T(4) FOO_TYPE(bar, (2)) { int a; };",
      "struct FOO_TYPE(bar, 2 * N) { int a; };",
      "struct FOO_TYPE(\"name\") { int a; };",
      "enum ENUM_ATTR(sizeof(int)) { EA, EB };",
      "enum __attribute((packed)) { HA, HB };",
      "struct __attribute((packed)) gp { char c; int i; };",
      "enum Color ENUM_BASE(unsigned char) { RED };",
      "enum PACKED_ATTR(N*2) { X1 };",
      "struct ALIGNED_T(N * 2) { int a; };",
      "struct STACK_OF(char *) { int a; };",
      "enum ATTR_PACKED() { AP1 };",
      "enum e : typeof(unsigned char) { EA = 1 };",
      "enum mode : unsigned char { M_A = 1, M_B = 2 };",
      "struct __attribute__((packed)) { int a; };"
    ].each do |input|
      it "extracts a type whose head holds attributes, macros or an enum base: #{input}" do
        result, pos = try_aggregate(input)
        expect(result).to eq [true, input]
        expect(pos).to eq input.length
      end
    end

    # A macro can spell a tag the way these spell a function's name and parameters, so the head
    # reads as a type's. Only the stray ';' after the body makes the function look like one.
    [
      "struct ops make_p(int a, int b) { return o; };",
      "struct ops make_u(VOID) { return o; };"
    ].each do |input|
      it "reads a function with a stray ';' as a type when its head could spell a tag: #{input}" do
        result, _pos = try_aggregate(input)
        expect(result).to eq [true, input]
      end
    end

    # --- Attributes after the body ---

    [
      "struct pk2 { char c; int i; } __attribute__((packed));",
      "union pu { char c; int i; } __attribute__((aligned(8)));",
      "enum big { BA, BB } __attribute__((packed)) /* small */ ;",
      "struct two { char c; } __attribute__((packed)) __attribute__((aligned(4)));",
      "struct zp { char c; int i; } __packed;",
      "struct za { char c; } __aligned(8);",
      "struct zg { char c; } __attribute((packed));"
    ].each do |input|
      it "extracts a type with attributes after its body: #{input}" do
        result, pos = try_aggregate(input)
        expect(result).to eq [true, input]
        expect(pos).to eq input.length
      end
    end

    it "rolls back for a declarator after the body's attributes" do
      result, pos = try_aggregate("struct pk3 { char c; } __attribute__((packed)) g_pk3;")
      expect(result).to eq [false, nil]
      expect(pos).to eq 0
    end

    # A word C doesn't reserve may name a variable, so it reads as one
    it "rolls back for a plain word after the body, which may be a variable or a macro" do
      result, pos = try_aggregate("struct pm2 { char c; } PACKED;")
      expect(result).to eq [false, nil]
      expect(pos).to eq 0
    end

    # A file-scope statement of its own can follow a function the head misreads
    [
      "struct ops make_v2(VOID) { return o; }\n__asm__(\".symver make_v2,make_v2@V1\");",
      "struct ops make_v3(VOID) { return o; }\n__FBSDID(\"$FreeBSD$\");"
    ].each do |input|
      it "rolls back rather than take a following statement for an extension: #{input.lines.last}" do
        result, pos = try_aggregate(input)
        expect(result).to eq [false, nil]
        expect(pos).to eq 0
      end
    end

    # --- Text that isn't ASCII ---

    it "keeps a literal whole after text that isn't ASCII" do
      input = "struct M { char d[sizeof(\"é;\")]; } __attribute__((packed));"
      result, pos = try_aggregate(input)
      expect(result).to eq [true, input]
      expect(pos).to eq input.bytesize
    end

    it "passes an extension's arguments after text that isn't ASCII" do
      input = "struct M2 { /* #{'é' * 20} */ int a; } __attribute__((section(\"x\")));"
      result, pos = try_aggregate(input)
      expect(result[0]).to be true
      expect(pos).to eq input.bytesize
    end

    # --- A buffer that ends early ---

    # The extractor sees a growing buffer, so text cut short must fail rather than succeed
    it "rolls back when an extension's arguments are cut off" do
      result, pos = try_aggregate("struct cut { char c; } __attribute__((section(\";\"")
      expect(result).to eq [false, nil]
      expect(pos).to eq 0
    end

    # --- Boundary behaviour ---

    it "stops at ';' and does not consume following code" do
      input = "struct Foo { int x; };\nint global = 0;"
      result, pos = try_aggregate(input)
      expect(result[0]).to be true
      expect(pos).to eq "struct Foo { int x; };\n".length
    end

    it "leaves scanner at start_pos after rollback so the variable extractor can retry" do
      scanner = StringScanner.new("struct Foo { int x; } instance;\nstruct Bar { int y; };")
      result  = @definitions.try_extract_aggregate_definition(scanner)
      expect(result).to eq [false, nil]
      expect(scanner.pos).to eq 0
    end

  end  # #try_extract_aggregate_definition

end
