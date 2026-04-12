# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'strscan'
require 'ceedling/c_extractor/c_extractor_code_text'
require 'ceedling/c_extractor/c_extractor_preprocessing'

describe CExtractorPreprocessing do

  before(:each) do
    code_text      = CExtractorCodeText.new
    @preprocessing = described_class.new( { c_extractor_code_text: code_text } )
  end

  # Helper: scan `text` for FOO and BAR macro calls
  def scan(text, names = ['FOO', 'BAR'])
    @preprocessing.try_extract_macro_calls( StringScanner.new(text), names )
  end

  context "#try_extract_macro_calls" do

    it "returns empty array for empty input" do
      expect( scan('') ).to eq []
    end

    it "returns empty array when no matching macros are present" do
      expect( scan('int x = UNRELATED(42);') ).to eq []
    end

    # --- Basic single-macro extraction ---

    it "extracts a single-param macro call" do
      expect( scan('FOO(bar)') ).to eq ['FOO(bar)']
    end

    it "extracts a multi-param macro call" do
      expect( scan('FOO(a, b, c)') ).to eq ['FOO(a, b, c)']
    end

    it "extracts macros from both names in the list" do
      expect( scan('FOO(x) BAR(y)') ).to eq ['FOO(x)', 'BAR(y)']
    end

    it "extracts multiple calls of the same macro in order" do
      expect( scan('FOO(a) FOO(b)') ).to eq ['FOO(a)', 'FOO(b)']
    end

    it "extracts macro surrounded by unrelated C code" do
      input = "int x = 1;\nFOO(calc)\nvoid f(void) {}"
      expect( scan(input) ).to eq ['FOO(calc)']
    end

    # --- Whitespace normalisation ---

    it "collapses embedded newlines in a multiline macro call" do
      input = "FOO(a,\n  b,\n  c)"
      expect( scan(input) ).to eq ['FOO(a, b, c)']
    end

    it "collapses tabs and multiple spaces" do
      expect( scan("FOO(\t\ta\t\t)") ).to eq ['FOO( a )']
    end

    # --- Comment suppression (outer scan) ---

    it "does not extract a macro call inside a line comment" do
      input = "// FOO(ignored)\nBAR(found)"
      expect( scan(input) ).to eq ['BAR(found)']
    end

    it "does not extract a macro call inside a block comment" do
      input = "/* FOO(ignored) */ BAR(found)"
      expect( scan(input) ).to eq ['BAR(found)']
    end

    it "does not extract any macros when all input is inside a block comment" do
      expect( scan('/* FOO(a) BAR(b) */') ).to eq []
    end

    it "resumes extraction after a block comment ends" do
      input = "/* FOO(skip) */ FOO(keep)"
      expect( scan(input) ).to eq ['FOO(keep)']
    end

    # --- String literal suppression (outer scan) ---

    it "does not extract a macro name appearing inside a double-quoted string literal" do
      input = 'const char *s = "FOO(not_a_call)"; BAR(real)'
      expect( scan(input) ).to eq ['BAR(real)']
    end

    it "does not extract a macro name appearing inside a single-quoted char literal" do
      # 'F' followed immediately by OO(... — the single char literal ends after 'F'
      # so this test uses a longer string that resembles a macro name in char context
      input = "char c = 'x'; FOO(real)"
      expect( scan(input) ).to eq ['FOO(real)']
    end

    # --- String literals as macro parameters ---

    it "treats a string literal containing a comma as a single argument" do
      input = 'FOO("hello, world")'
      expect( scan(input) ).to eq ['FOO("hello, world")']
    end

    it "treats a string literal containing parentheses as a single argument" do
      input = 'FOO("f(x)")'
      expect( scan(input) ).to eq ['FOO("f(x)")']
    end

    it "treats a string literal containing a macro name as a single argument" do
      input = 'FOO("FOO(inner)")'
      expect( scan(input) ).to eq ['FOO("FOO(inner)")']
    end

    it "handles a string literal containing an escaped quote" do
      input = 'FOO("say \\"hi\\"")'
      expect( scan(input) ).to eq ['FOO("say \\"hi\\"")']
    end

    it "extracts a macro whose arguments mix string literals and plain args" do
      input = 'FOO(calc, "a,b", second)'
      expect( scan(input) ).to eq ['FOO(calc, "a,b", second)']
    end

    # --- Comments inside argument lists ---

    it "removes a block comment inside an argument list and collapses to space" do
      input = "FOO(a /* ignored */, b)"
      expect( scan(input) ).to eq ['FOO(a , b)']
    end

    it "removes a line comment inside an argument list" do
      input = "FOO(a, // comment\nb)"
      expect( scan(input) ).to eq ['FOO(a, b)']
    end

    # --- Nested parentheses ---

    it "handles nested parentheses in arguments" do
      input = 'FOO(func(x, y), z)'
      expect( scan(input) ).to eq ['FOO(func(x, y), z)']
    end

    it "handles multiply-nested parentheses" do
      input = 'FOO(f(g(h(1))))'
      expect( scan(input) ).to eq ['FOO(f(g(h(1))))']
    end

    # --- Mixed complexity ---

    it "handles a mix of string literals, comments, and nested parens in one call" do
      input = 'FOO("str(with,parens)", func(/* note */ x), y)'
      expect( scan(input) ).to eq ['FOO("str(with,parens)", func( x), y)']
    end

    # --- Malformed / edge cases ---

    it "returns empty array for an unbalanced macro call" do
      expect( scan('FOO(unbalanced') ).to eq []
    end

    it "does not confuse a word that ends with a macro name suffix" do
      # 'NOTFOO(x)' should not match 'FOO' due to word boundary
      expect( scan('NOTFOO(x)') ).to eq []
    end

  end

  context "#parse_macro_call" do

    def parse(str)
      @preprocessing.parse_macro_call(str)
    end

    it "returns macro name and single param" do
      expect( parse('FOO(bar)') ).to eq ['FOO', ['bar']]
    end

    it "returns macro name and multiple comma-separated params" do
      expect( parse('FOO(a, b, c)') ).to eq ['FOO', ['a', 'b', 'c']]
    end

    it "returns macro name and empty params array when no arguments" do
      expect( parse('FOO()') ).to eq ['FOO', []]
    end

    it "trims leading and trailing whitespace from each param" do
      expect( parse('FOO(  a  ,  b  )') ).to eq ['FOO', ['a', 'b']]
    end

    it "treats nested parens as a single param unit — inner comma is not a separator" do
      expect( parse('FOO(func(x, y), z)') ).to eq ['FOO', ['func(x, y)', 'z']]
    end

    it "treats square brackets as a single param unit — inner comma is not a separator" do
      expect( parse('FOO(calc, [add, subtract])') ).to eq ['FOO', ['calc', '[add, subtract]']]
    end

    it "treats curly braces as a single param unit — inner comma is not a separator" do
      expect( parse('FOO(name, {a, b})') ).to eq ['FOO', ['name', '{a, b}']]
    end

    it "treats a string literal as a single param unit — inner comma is not a separator" do
      expect( parse('FOO("hello, world")') ).to eq ['FOO', ['"hello, world"']]
    end

    it "handles a mix of string literals, brackets, and nested parens" do
      expect( parse('TEST_PARTIAL_CONFIG(calculator, test_public, [add, subtract])') ).to eq [
        'TEST_PARTIAL_CONFIG', ['calculator', 'test_public', '[add, subtract]']
      ]
    end

    it "returns [nil, []] for malformed input with no opening paren" do
      expect( parse('FOO_no_parens') ).to eq [nil, []]
    end

    it "returns [nil, []] for empty input" do
      expect( parse('') ).to eq [nil, []]
    end

  end

  context "#try_extract_directive" do

    def try_directive(text)
      scanner = StringScanner.new(text)
      result  = @preprocessing.try_extract_directive(scanner)
      [result, scanner.pos]
    end

    it "returns [false, nil] when scanner is not at #" do
      result, pos = try_directive('int x = 0;')
      expect(result).to eq [false, nil]
      expect(pos).to eq 0  # scanner not advanced
    end

    it "returns [false, nil] for empty input" do
      result, pos = try_directive('')
      expect(result).to eq [false, nil]
      expect(pos).to eq 0
    end

    it "extracts a simple #pragma directive" do
      result, pos = try_directive("#pragma once\n")
      expect(result).to eq [true, "#pragma once\n"]
      expect(pos).to eq "#pragma once\n".length
    end

    it "extracts a simple #include directive" do
      result, pos = try_directive("#include <stdio.h>\n")
      expect(result).to eq [true, "#include <stdio.h>\n"]
      expect(pos).to eq "#include <stdio.h>\n".length
    end

    it "extracts a simple single-line #define macro" do
      result, pos = try_directive("#define FOO 42\n")
      expect(result).to eq [true, "#define FOO 42\n"]
      expect(pos).to eq "#define FOO 42\n".length
    end

    it "extracts a #define with whitespace after #" do
      result, pos = try_directive("# define FOO\n")
      expect(result).to eq [true, "# define FOO\n"]
      expect(pos).to eq "# define FOO\n".length
    end

    it "extracts a directive without trailing newline (EOS)" do
      result, pos = try_directive("#define FOO")
      expect(result).to eq [true, "#define FOO"]
      expect(pos).to eq "#define FOO".length
    end

    it "extracts a multiline #define with single backslash continuation" do
      input = "#define MAX(a,b) \\\n  ((a)>(b)?(a):(b))\n"
      result, pos = try_directive(input)
      expect(result).to eq [true, input]
      expect(pos).to eq input.length
    end

    it "extracts a multiline #define with multiple backslash continuations" do
      input = "#define MULTI \\\n  line1 \\\n  line2\n"
      result, pos = try_directive(input)
      expect(result).to eq [true, input]
      expect(pos).to eq input.length
    end

    it "stops at end of directive and does not consume following code" do
      input = "#define FOO 1\nint x = 0;"
      result, pos = try_directive(input)
      expect(result).to eq [true, "#define FOO 1\n"]
      expect(pos).to eq "#define FOO 1\n".length
    end

    it "leaves scanner position unchanged on failure" do
      scanner = StringScanner.new("int x;")
      scanner.pos = 0
      @preprocessing.try_extract_directive(scanner)
      expect(scanner.pos).to eq 0
    end

  end

  context "#filter_directive" do

    it "returns the directive text for MACRO_DEFINITION when directive is #define" do
      text = "#define FOO 42\n"
      expect( @preprocessing.filter_directive(text, CExtractorPreprocessing::MACRO_DEFINITION) ).to eq text
    end

    it "returns the directive text for MACRO_DEFINITION when directive is multiline #define" do
      text = "#define MAX(a,b) \\\n  ((a)>(b)?(a):(b))\n"
      expect( @preprocessing.filter_directive(text, CExtractorPreprocessing::MACRO_DEFINITION) ).to eq text
    end

    it "returns the directive text for MACRO_DEFINITION when # define has whitespace after #" do
      text = "# define FOO\n"
      expect( @preprocessing.filter_directive(text, CExtractorPreprocessing::MACRO_DEFINITION) ).to eq text
    end

    it "returns nil for MACRO_DEFINITION when directive is #pragma" do
      expect( @preprocessing.filter_directive("#pragma once\n", CExtractorPreprocessing::MACRO_DEFINITION) ).to be_nil
    end

    it "returns nil for MACRO_DEFINITION when directive is #include" do
      expect( @preprocessing.filter_directive("#include <stdio.h>\n", CExtractorPreprocessing::MACRO_DEFINITION) ).to be_nil
    end

    it "returns nil for unknown type symbols" do
      expect( @preprocessing.filter_directive("#define FOO\n", :unknown_type) ).to be_nil
    end

  end

end
