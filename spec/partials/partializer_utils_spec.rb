
# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ostruct'
require 'ceedling/constants'
require 'ceedling/partials/partializer_utils'

describe PartializerUtils do
  before(:each) do
    @code_finder = double("PreprocessinatorCodeFinder")
    @loginator   = double("Loginator").as_null_object

    @utils = described_class.new(
      {
        :preprocessinator_code_finder => @code_finder,
        :loginator                    => @loginator
      }
    )
  end

  context "#matches_visibility?" do
    context ":private visibility" do
      it "returns false when decorators array is empty" do
        result = @utils.matches_visibility?([], :private)
        expect(result).to be false
      end

      it "returns true when decorators contain 'static'" do
        result = @utils.matches_visibility?(['static'], :private)
        expect(result).to be true
      end

      it "returns true when decorators contain 'inline'" do
        result = @utils.matches_visibility?(['inline'], :private)
        expect(result).to be true
      end

      it "returns true when decorators contain '__inline'" do
        result = @utils.matches_visibility?(['__inline'], :private)
        expect(result).to be true
      end

      it "returns true when decorators contain '__inline__'" do
        result = @utils.matches_visibility?(['__inline__'], :private)
        expect(result).to be true
      end

      it "returns true when decorators contain multiple private keywords" do
        result = @utils.matches_visibility?(['static', 'inline'], :private)
        expect(result).to be true
      end

      it "returns false when decorators contain only 'extern'" do
        result = @utils.matches_visibility?(['extern'], :private)
        expect(result).to be false
      end

      it "returns false when decorators contain only 'const'" do
        result = @utils.matches_visibility?(['const'], :private)
        expect(result).to be false
      end

      it "returns true when mixed with non-private decorators" do
        result = @utils.matches_visibility?(['extern', 'static', 'const'], :private)
        expect(result).to be true
      end
    end

    context ":public visibility" do
      it "returns true when decorators array is empty" do
        result = @utils.matches_visibility?([], :public)
        expect(result).to be true
      end

      it "returns false when decorators contain 'static'" do
        result = @utils.matches_visibility?(['static'], :public)
        expect(result).to be false
      end

      it "returns false when decorators contain 'inline'" do
        result = @utils.matches_visibility?(['inline'], :public)
        expect(result).to be false
      end

      it "returns false when decorators contain '__inline'" do
        result = @utils.matches_visibility?(['__inline'], :public)
        expect(result).to be false
      end

      it "returns false when decorators contain '__inline__'" do
        result = @utils.matches_visibility?(['__inline__'], :public)
        expect(result).to be false
      end

      it "returns false when decorators contain multiple private keywords" do
        result = @utils.matches_visibility?(['static', 'inline'], :public)
        expect(result).to be false
      end

      it "returns true when decorators contain only 'extern'" do
        result = @utils.matches_visibility?(['extern'], :public)
        expect(result).to be true
      end

      it "returns true when decorators contain only 'const'" do
        result = @utils.matches_visibility?(['const'], :public)
        expect(result).to be true
      end

      it "returns false when mixed with private decorators" do
        result = @utils.matches_visibility?(['extern', 'static', 'const'], :public)
        expect(result).to be false
      end
    end

    context "when `visibility` parameter is invalid" do
      # Non-exhaustive validation -- just a spot check``
      it "raises for invalid symbol" do
        expect {
          @utils.matches_visibility?(['static'], :invalid)
        }.to raise_error(ArgumentError, /Invalid.*:invalid/)
      end
    end
  end

  context "#transform_function" do
    let(:mock_func) do
      double('function',
        name: 'testFunc',
        signature: 'void testFunc(int x)',
        source_filepath: 'src/code/myfile.c',
        line_num: 34,
        code_block: "__pragma__ static void testFunc(int x) {\n  return x * 2;\n}"
      )
    end

    context "when output_type is :impl" do
      it "returns a FunctionDefinition with source filepath, line number, signature, and code block" do
        signature = 'void testFunc(int x)'

        result = @utils.transform_function(mock_func, signature, :impl)

        expect(result).to be_a(Partials::FunctionDefinition)
        expect(result.signature).to eq(signature)
        expect(result.code_block).to eq("void testFunc(int x) {\n  return x * 2;\n}")
      end
    end

    context "when output_type is :interface" do
      it "returns a FunctionDeclaration with only signature" do
        signature = 'void testFunc(int x)'

        result = @utils.transform_function(mock_func, signature, :interface)

        expect(result).to be_a(Partials::FunctionDeclaration)
        expect(result.signature).to eq(signature)
        expect(result).not_to respond_to(:code_block)
      end
    end

    context "when output_type is invalid" do
      it "raises exception for unknown output type" do
        signature = 'void testFunc(void)'

        expect {
          @utils.transform_function(mock_func, signature, :unknown)
        }.to raise_error(ArgumentError, /unknown/i)
      end
    end
  end

  # Test private method for code block manipulation used by `transform_function()`
  context "#extract_code_block" do
    it "extracts code block starting from signature" do
      code_block = "static inline void foo(void) {\n  return;\n}"
      signature = "void foo(void)"

      result = @utils.send(:extract_code_block, code_block, signature)

      expect(result).to eq("void foo(void) {\n  return;\n}")

      code_block = "extern static const int bar(int x) { return x; }"
      signature = "int bar(int x)"

      result = @utils.send(:extract_code_block, code_block, signature)

      expect(result).to eq("int bar(int x) { return x; }")
      expect(result).not_to include("extern")
      expect(result).not_to include("static")
    end

    it "preserves indentation and newlines" do
      code_block = "static void indented(void) {\n    int x = 1;\n    return x;\n}"
      signature = "void indented(void)"

      result = @utils.send(:extract_code_block, code_block, signature)

      expect(result).to include("    int x = 1;")
      expect(result.count("\n")).to eq(3)
    end

    it "handles signature at the immediate beginning of code block" do
      code_block = "void noDecorators(void) { }"
      signature = "void noDecorators(void)"

      result = @utils.send(:extract_code_block, code_block, signature)

      expect(result).to eq(code_block)
    end

    it "handles multiline signatures" do
      code_block = "static int multiline(\n    int a,\n    int b) {\n  return a + b;\n}"
      signature = "int multiline(\n    int a,\n    int b)"

      result = @utils.send(:extract_code_block, code_block, signature)

      expect(result).to start_with(signature)
      expect(result).not_to include("static")
    end

    it "handles empty body" do
      code_block = "inline void empty(void) {}"
      signature = "void empty(void)"

      result = @utils.send(:extract_code_block, code_block, signature)

      expect(result).to eq("void empty(void) {}")
    end

    it "raises error when signature not found" do
      code_block = "void foo(void) { }"
      signature = "void bar(void)"

      expect {
        @utils.send(:extract_code_block, code_block, signature)
      }.to raise_error(ArgumentError, /Signature.*not found/)
    end
  end

  context "#replace_declaration_with_noop" do
    it "replaces first occurrence of declaration with noop containing placeholder in comment" do
      text   = "  static int count;\n  count = 0;"
      result = @utils.replace_declaration_with_noop(text, "static int count", "MYPLACEHOLDER")

      expect(result).to include("(void)0;")
      expect(result).to include("`MYPLACEHOLDER`")
      expect(result).not_to start_with("  static int count;")
    end

    it "only replaces the first occurrence (sub, not gsub)" do
      text   = "static int x; static int x;"
      result = @utils.replace_declaration_with_noop(text, "static int x", "PH")

      expect(result.scan("(void)0;").length).to eq(1)
      # Second occurrence is preserved
      expect(result).to include("static int x")
    end

    it "works when declaration appears mid-string with surrounding context" do
      text   = "/* leading comment */\n  static int val;\n  val = 5;"
      result = @utils.replace_declaration_with_noop(text, "static int val", "TOKEN")

      expect(result).to include("(void)0;")
      expect(result).to include("/* leading comment */")
    end

    it "returns unchanged text when declaration is not found" do
      text   = "int x = 0;"
      result = @utils.replace_declaration_with_noop(text, "static int y", "PH")

      expect(result).to eq(text)
    end

    it "handles declaration text that ends with a semicolon" do
      text   = "static int count;"
      result = @utils.replace_declaration_with_noop(text, "static int count;", "PH")

      expect(result).to include("(void)0;")
    end
  end

  context "#replace_compound_declaration_with_noops" do
    it "produces a single noop with comment for count=1" do
      text   = "  static int count;\n  count = 0;"
      result = @utils.replace_compound_declaration_with_noops(text, "static int count", "PH_COUNT", 1)

      expect(result.scan("(void)0;").length).to eq(1)
      expect(result).to include("`PH_COUNT`")
    end

    it "produces two noops for count=2 with single comment containing placeholder" do
      text   = "void f(void) { static int a, b; a = 0; b = 1; }"
      result = @utils.replace_compound_declaration_with_noops(text, "static int a, b;", "PH_A", 2)

      expect(result.scan("(void)0;").length).to eq(2)
      expect(result).to include("`PH_A`")
      # Only one comment
      expect(result.scan("/*").length).to eq(1)
    end

    it "produces three noops for count=3 with a single comment" do
      text   = "static int x, y, z;"
      result = @utils.replace_compound_declaration_with_noops(text, "static int x, y, z;", "PH_X", 3)

      expect(result.scan("(void)0;").length).to eq(3)
      expect(result).to include("`PH_X`")
      expect(result.scan("/*").length).to eq(1)
    end

    it "replaces only the first occurrence of the declaration (sub, not gsub)" do
      text   = "static int a, b; static int a, b;"
      result = @utils.replace_compound_declaration_with_noops(text, "static int a, b;", "PH_A", 2)

      expect(result.scan("(void)0;").length).to eq(2)     # two noops from one replacement
      expect(result).to include("static int a, b;")       # second occurrence unchanged
    end

    it "returns unchanged text when declaration is not found" do
      text   = "int x = 0;"
      result = @utils.replace_compound_declaration_with_noops(text, "static int y, z;", "PH_Y", 2)

      expect(result).to eq(text)
    end

    it "placeholder token appears verbatim in the single comment" do
      text   = "static int val1, val2;"
      result = @utils.replace_compound_declaration_with_noops(text, "static int val1, val2;", "TOKEN_1", 2)

      expect(result).to include("`TOKEN_1`")
      expect(result).not_to include("static int val1, val2;")
    end
  end

  context "#rename_c_identifier" do
    it "replaces a single token-bounded occurrence" do
      result = @utils.rename_c_identifier("count = 0;", "count", "partial_foo_count")
      expect(result).to eq("partial_foo_count = 0;")
    end

    it "replaces all occurrences throughout the text (gsub)" do
      result = @utils.rename_c_identifier("count = count + 1;", "count", "partial_foo_count")
      expect(result).to eq("partial_foo_count = partial_foo_count + 1;")
    end

    it "does not replace left-bounded substrings" do
      result = @utils.rename_c_identifier("recount = 0;", "count", "partial_foo_count")
      expect(result).to eq("recount = 0;")
    end

    it "does not replace right-bounded substrings" do
      result = @utils.rename_c_identifier("count_down = 0;", "count", "partial_foo_count")
      expect(result).to eq("count_down = 0;")
    end

    it "does not replace interior substrings" do
      result = @utils.rename_c_identifier("recount_down = 0;", "count", "partial_foo_count")
      expect(result).to eq("recount_down = 0;")
    end

    it "replaces identifier in parentheses context" do
      result = @utils.rename_c_identifier("foo(count)", "count", "partial_foo_count")
      expect(result).to eq("foo(partial_foo_count)")
    end

    it "replaces pointer dereference context" do
      result = @utils.rename_c_identifier("*count = 0;", "count", "partial_foo_count")
      expect(result).to eq("*partial_foo_count = 0;")
    end

    it "replaces array subscript context" do
      result = @utils.rename_c_identifier("count[0]", "count", "partial_foo_count")
      expect(result).to eq("partial_foo_count[0]")
    end

    it "replaces comparison context without spaces" do
      result = @utils.rename_c_identifier("count==5", "count", "partial_foo_count")
      expect(result).to eq("partial_foo_count==5")
    end

    it "replaces compound assignment without spaces" do
      result = @utils.rename_c_identifier("count+=1", "count", "partial_foo_count")
      expect(result).to eq("partial_foo_count+=1")
    end

    it "replaces address-of context" do
      result = @utils.rename_c_identifier("&count", "count", "partial_foo_count")
      expect(result).to eq("&partial_foo_count")
    end

    it "returns empty string unchanged" do
      result = @utils.rename_c_identifier("", "count", "partial_foo_count")
      expect(result).to eq("")
    end

    it "returns unchanged text when old_name not present" do
      text   = "value = 5;"
      result = @utils.rename_c_identifier(text, "count", "partial_foo_count")
      expect(result).to eq(text)
    end
  end

  context "#stamp_source_filepaths" do
    it "does nothing for empty array without error" do
      expect { @utils.stamp_source_filepaths([], '/path/to/file.c') }.not_to raise_error
    end

    it "sets source_filepath on a single func" do
      func = double('func')
      expect(func).to receive(:source_filepath=).with('/path/to/file.c')
      @utils.stamp_source_filepaths([func], '/path/to/file.c')
    end

    it "sets source_filepath on all funcs in a collection" do
      funcs = [double('f1'), double('f2'), double('f3')]
      funcs.each { |f| expect(f).to receive(:source_filepath=).with('/path/to/file.c') }
      @utils.stamp_source_filepaths(funcs, '/path/to/file.c')
    end

    it "overwrites a pre-existing source_filepath" do
      func = OpenStruct.new(source_filepath: '/old/path.c')
      @utils.stamp_source_filepaths([func], '/new/path.c')
      expect(func.source_filepath).to eq('/new/path.c')
    end
  end

  context "#locate_function_in_source" do
    it "returns the line number when function is found" do
      expect(@code_finder).to receive(:find_in_c_file)
        .with('/path/to/file.c', 'void foo(void) {}')
        .and_return(42)

      result = @utils.locate_function_in_source(code_block: 'void foo(void) {}', filepath: '/path/to/file.c')
      expect(result).to eq(42)
    end

    it "returns nil when function is not found" do
      allow(@code_finder).to receive(:find_in_c_file).and_return(nil)

      result = @utils.locate_function_in_source(code_block: 'void missing(void) {}', filepath: '/path/to/file.c')
      expect(result).to be_nil
    end

    it "forwards exact arguments to code_finder" do
      expect(@code_finder).to receive(:find_in_c_file)
        .with('/exact/path.c', 'exact code block')
        .and_return(nil)

      @utils.locate_function_in_source(code_block: 'exact code block', filepath: '/exact/path.c')
    end
  end

  context "#locate_function_via_preprocessed" do
    let(:filepath)              { '/path/to/source.c' }
    let(:preprocessed_filepath) { '/build/preproc/source.i' }
    let(:code_block)            { 'void foo(void) {}' }

    it "returns line number from preprocessed file when found there" do
      expect(@code_finder).to receive(:find_in_preprpocessed_file)
        .with(preprocessed_filepath, code_block)
        .and_return(10)
      expect(@code_finder).not_to receive(:find_in_c_file)

      result = @utils.locate_function_via_preprocessed(
        code_block:            code_block,
        filepath:              filepath,
        preprocessed_filepath: preprocessed_filepath
      )
      expect(result).to eq(10)
    end

    it "falls back to C source when not found in preprocessed file" do
      allow(@code_finder).to receive(:find_in_preprpocessed_file).and_return(nil)
      expect(@code_finder).to receive(:find_in_c_file).with(filepath, code_block).and_return(25)

      result = @utils.locate_function_via_preprocessed(
        code_block:            code_block,
        filepath:              filepath,
        preprocessed_filepath: preprocessed_filepath
      )
      expect(result).to eq(25)
    end

    it "returns nil when found in neither preprocessed nor C source" do
      allow(@code_finder).to receive(:find_in_preprpocessed_file).and_return(nil)
      allow(@code_finder).to receive(:find_in_c_file).and_return(nil)

      result = @utils.locate_function_via_preprocessed(
        code_block:            code_block,
        filepath:              filepath,
        preprocessed_filepath: preprocessed_filepath
      )
      expect(result).to be_nil
    end

    it "forwards correct arguments to both code_finder methods" do
      expect(@code_finder).to receive(:find_in_preprpocessed_file)
        .with('/exact/preproc.i', 'exact block')
        .and_return(nil)
      expect(@code_finder).to receive(:find_in_c_file)
        .with('/exact/source.c', 'exact block')
        .and_return(nil)

      @utils.locate_function_via_preprocessed(
        code_block:            'exact block',
        filepath:              '/exact/source.c',
        preprocessed_filepath: '/exact/preproc.i'
      )
    end
  end

  context "#format_line_number_list" do
    it "returns empty array for empty input" do
      result = @utils.format_line_number_list([])
      expect(result).to eq([])
    end

    it "formats functions with resolved line numbers correctly" do
      funcs = [
        OpenStruct.new(name: 'foo', line_num: 5),
        OpenStruct.new(name: 'bar', line_num: 12)
      ]
      result = @utils.format_line_number_list(funcs)
      expect(result).to eq(["foo(): 5", "bar(): 12"])
    end

    it "renders N/A for function with nil line_num" do
      funcs = [OpenStruct.new(name: 'baz', line_num: nil)]
      result = @utils.format_line_number_list(funcs)
      expect(result).to eq(["baz(): N/A"])
    end

    it "handles mix of found and missing line numbers" do
      funcs = [
        OpenStruct.new(name: 'found',   line_num: 42),
        OpenStruct.new(name: 'missing', line_num: nil)
      ]
      result = @utils.format_line_number_list(funcs)
      expect(result).to eq(["found(): 42", "missing(): N/A"])
    end
  end

end
