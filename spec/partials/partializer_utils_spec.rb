
# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/partials/partializer_utils'

describe PartializerUtils do
  before(:each) do
    @utils = described_class.new
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
end
