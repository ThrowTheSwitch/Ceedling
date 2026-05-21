# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
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

    it "returns [false, nil] for a forward declaration without body (struct Foo;)" do
      result, pos = try_aggregate('struct Foo;')
      expect(result).to eq [false, nil]
      expect(pos).to eq 0
    end

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
