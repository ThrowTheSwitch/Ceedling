
# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/partializer_helper'

describe PartializerHelper do
  before(:each) do
    @partializer_helper = described_class.new
  end

  context "#matches_visibility?" do
    context ":private visibility" do
      it "returns false when decorators array is empty" do
        result = @partializer_helper.matches_visibility?([], :private)
        expect(result).to be false
      end

      it "returns true when decorators contain 'static'" do
        result = @partializer_helper.matches_visibility?(['static'], :private)
        expect(result).to be true
      end

      it "returns true when decorators contain 'inline'" do
        result = @partializer_helper.matches_visibility?(['inline'], :private)
        expect(result).to be true
      end

      it "returns true when decorators contain '__inline'" do
        result = @partializer_helper.matches_visibility?(['__inline'], :private)
        expect(result).to be true
      end

      it "returns true when decorators contain '__inline__'" do
        result = @partializer_helper.matches_visibility?(['__inline__'], :private)
        expect(result).to be true
      end

      it "returns true when decorators contain multiple private keywords" do
        result = @partializer_helper.matches_visibility?(['static', 'inline'], :private)
        expect(result).to be true
      end

      it "returns false when decorators contain only 'extern'" do
        result = @partializer_helper.matches_visibility?(['extern'], :private)
        expect(result).to be false
      end

      it "returns false when decorators contain only 'const'" do
        result = @partializer_helper.matches_visibility?(['const'], :private)
        expect(result).to be false
      end

      it "returns true when mixed with non-private decorators" do
        result = @partializer_helper.matches_visibility?(['extern', 'static', 'const'], :private)
        expect(result).to be true
      end
    end

    context ":public visibility" do
      it "returns true when decorators array is empty" do
        result = @partializer_helper.matches_visibility?([], :public)
        expect(result).to be true
      end

      it "returns false when decorators contain 'static'" do
        result = @partializer_helper.matches_visibility?(['static'], :public)
        expect(result).to be false
      end

      it "returns false when decorators contain 'inline'" do
        result = @partializer_helper.matches_visibility?(['inline'], :public)
        expect(result).to be false
      end

      it "returns false when decorators contain '__inline'" do
        result = @partializer_helper.matches_visibility?(['__inline'], :public)
        expect(result).to be false
      end

      it "returns false when decorators contain '__inline__'" do
        result = @partializer_helper.matches_visibility?(['__inline__'], :public)
        expect(result).to be false
      end

      it "returns false when decorators contain multiple private keywords" do
        result = @partializer_helper.matches_visibility?(['static', 'inline'], :public)
        expect(result).to be false
      end

      it "returns true when decorators contain only 'extern'" do
        result = @partializer_helper.matches_visibility?(['extern'], :public)
        expect(result).to be true
      end

      it "returns true when decorators contain only 'const'" do
        result = @partializer_helper.matches_visibility?(['const'], :public)
        expect(result).to be true
      end

      it "returns false when mixed with private decorators" do
        result = @partializer_helper.matches_visibility?(['extern', 'static', 'const'], :public)
        expect(result).to be false
      end
    end

    context "when `visibility` parameter is invalid" do
      it "raises for invalid symbol" do
        expect {
          @partializer_helper.matches_visibility?(['static'], :invalid)
        }.to raise_error(ArgumentError, /Invalid visibility.*:invalid/)
      end

      it "raises for nil" do
        expect {
          @partializer_helper.matches_visibility?(['static'], nil)
        }.to raise_error(ArgumentError, /Invalid visibility.*nil/)
      end

      it "raises for string" do
        expect {
          @partializer_helper.matches_visibility?(['static'], "public")
        }.to raise_error(ArgumentError, /Invalid visibility.*"public"/)
      end
    end
  end

  context "#parse_signature_decorators" do
    it "extracts single decorator from simple signature" do
      signature = "static int foo(void)"
      decorators, shortened = @partializer_helper.parse_signature_decorators(signature, 'foo')
      
      expect(decorators).to eq(['static'])
      expect(shortened).to eq('int foo(void)')
    end

    it "extracts multiple decorators from signature" do
      signature = "static inline int foo(void)"
      decorators, shortened = @partializer_helper.parse_signature_decorators(signature, 'foo')
      
      expect(decorators).to eq(['static', 'inline'])
      expect(shortened).to eq('int foo(void)')
    end

    it "handles signature with no decorators" do
      signature = "void bar(void)"
      decorators, shortened = @partializer_helper.parse_signature_decorators(signature, 'bar')
      
      expect(decorators).to eq([])
      expect(shortened).to eq('void bar(void)')
    end

    it "handles signature with only return type" do
      signature = "int baz(void)"
      decorators, shortened = @partializer_helper.parse_signature_decorators(signature, 'baz')
      
      expect(decorators).to eq([])
      expect(shortened).to eq('int baz(void)')
    end

    it "preserves single space between return type and function name" do
      signature = "static int foo(void)"
      decorators, shortened = @partializer_helper.parse_signature_decorators(signature, 'foo')
      
      expect(shortened).to eq('int foo(void)')
    end

    it "preserves multiple spaces between return type and function name" do
      signature = "static int  foo(void)"
      decorators, shortened = @partializer_helper.parse_signature_decorators(signature, 'foo')
      
      expect(shortened).to eq('int  foo(void)')
    end

    it "handles pointer return types" do
      signature = "static char* get_string(void)"
      decorators, shortened = @partializer_helper.parse_signature_decorators(signature, 'get_string')
      
      expect(decorators).to eq(['static'])
      expect(shortened).to eq('char* get_string(void)')
    end

    it "handles pointer return types with space" do
      signature = "static char * get_string(void)"
      decorators, shortened = @partializer_helper.parse_signature_decorators(signature, 'get_string')
      
      expect(decorators).to eq(['static'])
      expect(shortened).to eq('char * get_string(void)')
    end

    it "handles multiline signature with newline before return type" do
      signature = "static inline\nint\nfoo(void)"
      decorators, shortened = @partializer_helper.parse_signature_decorators(signature, 'foo')
      
      expect(decorators).to eq(['static', 'inline'])
      expect(shortened).to eq("int\nfoo(void)")
    end

    it "handles multiline signature with newline and indentation" do
      signature = "extern const char*\n  bar(int x)"
      decorators, shortened = @partializer_helper.parse_signature_decorators(signature, 'bar')
      
      expect(decorators).to eq(['extern', 'const'])
      expect(shortened).to eq("char*\n  bar(int x)")
    end

    it "handles signature with function parameters" do
      signature = "static int calculate(int x, int y)"
      decorators, shortened = @partializer_helper.parse_signature_decorators(signature, 'calculate')
      
      expect(decorators).to eq(['static'])
      expect(shortened).to eq('int calculate(int x, int y)')
    end

    it "handles complex return type with const" do
      signature = "static const int* get_value(void)"
      decorators, shortened = @partializer_helper.parse_signature_decorators(signature, 'get_value')
      
      expect(decorators).to eq(['static', 'const'])
      expect(shortened).to eq('int* get_value(void)')
    end

    it "returns original signature when function name not found" do
      signature = "static int foo(void)"
      decorators, shortened = @partializer_helper.parse_signature_decorators(signature, 'nonexistent')
      
      expect(decorators).to eq([])
      expect(shortened).to eq('static int foo(void)')
    end

    it "handles extern decorator" do
      signature = "extern void initialize(void)"
      decorators, shortened = @partializer_helper.parse_signature_decorators(signature, 'initialize')
      
      expect(decorators).to eq(['extern'])
      expect(shortened).to eq('void initialize(void)')
    end

    it "handles multiple decorators with const" do
      signature = "static inline const int get_constant(void)"
      decorators, shortened = @partializer_helper.parse_signature_decorators(signature, 'get_constant')
      
      expect(decorators).to eq(['static', 'inline', 'const'])
      expect(shortened).to eq('int get_constant(void)')
    end

    it "handles signature with tabs" do
      signature = "static\tinline\tint\tfoo(void)"
      decorators, shortened = @partializer_helper.parse_signature_decorators(signature, 'foo')
      
      expect(decorators).to eq(['static', 'inline'])
      expect(shortened).to eq("int\tfoo(void)")
    end

    it "handles signature with mixed whitespace" do
      signature = "static  inline\n\tint  foo(void)"
      decorators, shortened = @partializer_helper.parse_signature_decorators(signature, 'foo')
      
      expect(decorators).to eq(['static', 'inline'])
      expect(shortened).to eq("int  foo(void)")
    end

    it "handles unsigned return type" do
      signature = "static unsigned int get_count(void)"
      decorators, shortened = @partializer_helper.parse_signature_decorators(signature, 'get_count')
      
      expect(decorators).to eq(['static'])
      expect(shortened).to eq('unsigned int get_count(void)')
    end

    it "handles long return type" do
      signature = "static long long get_timestamp(void)"
      decorators, shortened = @partializer_helper.parse_signature_decorators(signature, 'get_timestamp')
      
      expect(decorators).to eq(['static'])
      expect(shortened).to eq('long long get_timestamp(void)')
    end

    it "handles struct return type" do
      signature = "static struct data_t get_data(void)"
      decorators, shortened = @partializer_helper.parse_signature_decorators(signature, 'get_data')
      
      expect(decorators).to eq(['static'])
      expect(shortened).to eq('struct data_t get_data(void)')
    end

    it "handles function with no parameters" do
      signature = "static void cleanup()"
      decorators, shortened = @partializer_helper.parse_signature_decorators(signature, 'cleanup')
      
      expect(decorators).to eq(['static'])
      expect(shortened).to eq('void cleanup()')
    end
  end

end