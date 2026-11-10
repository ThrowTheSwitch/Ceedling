
# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ostruct'
require 'ceedling/constants'
require 'ceedling/partials/partials'
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
        result = @utils.matches_visibility?([], Partials::PRIVATE)
        expect(result).to be false
      end

      it "returns true when decorators contain 'static'" do
        result = @utils.matches_visibility?(['static'], Partials::PRIVATE)
        expect(result).to be true
      end

      it "returns true when decorators contain 'inline'" do
        result = @utils.matches_visibility?(['inline'], Partials::PRIVATE)
        expect(result).to be true
      end

      it "returns true when decorators contain '__inline'" do
        result = @utils.matches_visibility?(['__inline'], Partials::PRIVATE)
        expect(result).to be true
      end

      it "returns true when decorators contain '__inline__'" do
        result = @utils.matches_visibility?(['__inline__'], Partials::PRIVATE)
        expect(result).to be true
      end

      it "returns true when decorators contain multiple private keywords" do
        result = @utils.matches_visibility?(['static', 'inline'], Partials::PRIVATE)
        expect(result).to be true
      end

      it "returns false when decorators contain only 'extern'" do
        result = @utils.matches_visibility?(['extern'], Partials::PRIVATE)
        expect(result).to be false
      end

      it "returns false when decorators contain only 'const'" do
        result = @utils.matches_visibility?(['const'], Partials::PRIVATE)
        expect(result).to be false
      end

      it "returns true when mixed with non-private decorators" do
        result = @utils.matches_visibility?(['extern', 'static', 'const'], Partials::PRIVATE)
        expect(result).to be true
      end
    end

    context ":public visibility" do
      it "returns true when decorators array is empty" do
        result = @utils.matches_visibility?([], Partials::PUBLIC)
        expect(result).to be true
      end

      it "returns false when decorators contain 'static'" do
        result = @utils.matches_visibility?(['static'], Partials::PUBLIC)
        expect(result).to be false
      end

      it "returns false when decorators contain 'inline'" do
        result = @utils.matches_visibility?(['inline'], Partials::PUBLIC)
        expect(result).to be false
      end

      it "returns false when decorators contain '__inline'" do
        result = @utils.matches_visibility?(['__inline'], Partials::PUBLIC)
        expect(result).to be false
      end

      it "returns false when decorators contain '__inline__'" do
        result = @utils.matches_visibility?(['__inline__'], Partials::PUBLIC)
        expect(result).to be false
      end

      it "returns false when decorators contain multiple private keywords" do
        result = @utils.matches_visibility?(['static', 'inline'], Partials::PUBLIC)
        expect(result).to be false
      end

      it "returns true when decorators contain only 'extern'" do
        result = @utils.matches_visibility?(['extern'], Partials::PUBLIC)
        expect(result).to be true
      end

      it "returns true when decorators contain only 'const'" do
        result = @utils.matches_visibility?(['const'], Partials::PUBLIC)
        expect(result).to be true
      end

      it "returns false when mixed with private decorators" do
        result = @utils.matches_visibility?(['extern', 'static', 'const'], Partials::PUBLIC)
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
        decorators: ['__pragma__', 'static'],
        code_block: "__pragma__ static void testFunc(int x) {\n  return x * 2;\n}"
      )
    end

    context "when output_type is :impl" do
      # A selected function's callers rely on it never returning
      it "keeps _Noreturn on a testable function" do
        func = double('function', name: 'die', decorators: ['static'], source_filepath: 'src/m.c', line_num: 3,
                      code_block: "static _Noreturn void die(void) { for (;;) {} }")

        result = @utils.transform_function(func, '_Noreturn void die(void)', :impl)

        expect(result.code_block).to eq("_Noreturn void die(void) { for (;;) {} }")
      end

      it "returns a FunctionDefinition with source filepath, line number, signature, and code block" do
        signature = 'void testFunc(int x)'

        result = @utils.transform_function(mock_func, signature, :impl)

        expect(result).to be_a(Partials::FunctionDefinition)
        expect(result.signature).to eq(signature)
        expect(result.code_block).to eq("void testFunc(int x) {\n  return x * 2;\n}")
        # Decorators are inline (no leading newlines), so line_num is unchanged
        expect(result.line_num).to eq(34)
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

      # A mock always returns, so a mock declared never to return would contradict itself
      it "drops _Noreturn from a mockable signature" do
        result = @utils.transform_function(mock_func, '_Noreturn void testFunc(int x);', :interface)

        expect(result.signature).to eq('void testFunc(int x)')
      end

      it "drops the GNU and C23 noreturn attributes from a mockable signature" do
        gnu = @utils.transform_function(mock_func, '__attribute__((noreturn)) void testFunc(int x);', :interface)
        c23 = @utils.transform_function(mock_func, '[[noreturn]] void testFunc(int x);', :interface)

        expect(gnu.signature).to eq('void testFunc(int x)')
        expect(c23.signature).to eq('void testFunc(int x)')
      end

      it "keeps an attribute that says something else" do
        result = @utils.transform_function(mock_func, '__attribute__((warn_unused_result)) int testFunc(int x);', :interface)

        expect(result.signature).to eq('__attribute__((warn_unused_result)) int testFunc(int x)')
      end

      it "strips a trailing semicolon from a declaration-sourced signature" do
        # CFunctionDeclaration#signature_stripped always carries its own trailing
        # semicolon (it's a bare prototype); CFunctionDefinition#signature_stripped never
        # does. Callers render "#{signature};" uniformly, so this must not double up.
        signature = 'void testFunc(int x);'

        result = @utils.transform_function(mock_func, signature, :interface)

        expect(result.signature).to eq('void testFunc(int x)')
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
    it "strips a decorator on the signature's own line and counts no newlines" do
      code_block = "static void foo(void) {\n  return;\n}"
      result, newlines = @utils.send(:extract_code_block, code_block, ['static'], 'foo')

      expect(result).to eq("void foo(void) {\n  return;\n}")
      expect(newlines).to eq(0)
    end

    it "strips several decorators on the signature's own line and counts no newlines" do
      code_block = "static inline void foo(void) { return; }"
      result, newlines = @utils.send(:extract_code_block, code_block, ['static', 'inline'], 'foo')

      expect(result).to eq("void foo(void) { return; }")
      expect(newlines).to eq(0)
    end

    it "handles empty decorators array — no stripping, 0 leading newlines" do
      code_block = "void foo(void) { return; }"
      result, newlines = @utils.send(:extract_code_block, code_block, [], 'foo')

      expect(result).to eq(code_block)
      expect(newlines).to eq(0)
    end

    it "counts 1 leading newline when decorator occupies its own line" do
      code_block = "static\nint foo(void) { return 0; }"
      result, newlines = @utils.send(:extract_code_block, code_block, ['static'], 'foo')

      expect(result).to eq("int foo(void) { return 0; }")
      expect(newlines).to eq(1)
    end

    it "counts 2 leading newlines when two decorators each occupy their own line" do
      code_block = "static\ninline\nint foo(void) { return 0; }"
      result, newlines = @utils.send(:extract_code_block, code_block, ['static', 'inline'], 'foo')

      expect(result).to eq("int foo(void) { return 0; }")
      expect(newlines).to eq(2)
    end

    it "preserves body indentation and internal newlines" do
      code_block = "static void indented(void) {\n    int x = 1;\n    return x;\n}"
      result, _ = @utils.send(:extract_code_block, code_block, ['static'], 'indented')

      expect(result).to include("    int x = 1;")
      expect(result.count("\n")).to eq(3)
    end

    it "handles multi-line parameter list without relying on signature substring match" do
      code_block = "static int multiline(\n    int a,\n    int b) {\n  return a + b;\n}"
      result, newlines = @utils.send(:extract_code_block, code_block, ['static'], 'multiline')

      expect(result).to eq("int multiline(\n    int a,\n    int b) {\n  return a + b;\n}")
      expect(result).not_to include("static")
      expect(newlines).to eq(0)
    end

    it "is a no-op when decorator is not present in code_block" do
      code_block = "void foo(void) { }"
      result, newlines = @utils.send(:extract_code_block, code_block, ['extern'], 'foo')

      expect(result).to eq(code_block)
      expect(newlines).to eq(0)
    end

    it "leaves a decorator word in the body alone" do
      # 'static' in the body (e.g., a local static var) must not be touched
      code_block = "static int foo(void) {\n  static int x = 0;\n  return x;\n}"
      result, _ = @utils.send(:extract_code_block, code_block, ['static'], 'foo')

      expect(result).to start_with("int foo(void)")
      expect(result).to include("static int x = 0;")
    end

    # Only the text before the name is searched, so a body's own static stays when a macro
    # hides the signature's
    it "leaves a body's decorator word alone when the signature spells its decorator as a macro" do
      code_block = "PRIVATE int hidden(void) { static int n; return n; }"
      result, newlines = @utils.send(:extract_code_block, code_block, ['static'], 'hidden')

      expect(result).to eq(code_block)
      expect(newlines).to eq(0)
    end

    it "strips multiple decorators and counts newlines for inline+multiline mix" do
      code_block = "extern\nstatic int bar(int x) { return x; }"
      result, newlines = @utils.send(:extract_code_block, code_block, ['extern', 'static'], 'bar')

      expect(result).to eq("int bar(int x) { return x; }")
      expect(newlines).to eq(1)
    end

    # Only storage-class and inline keywords are stripped. A qualifier belongs to the return type.
    it "keeps a const return type when stripping static" do
      code_block = "static const char *name(void) { return \"n\"; }"
      result, newlines = @utils.send(:extract_code_block, code_block, ['static'], 'name')

      expect(result).to eq("const char *name(void) { return \"n\"; }")
      expect(newlines).to eq(0)
    end

    it "strips a storage class written after a qualifier" do
      code_block = "const static int *table(void) { return 0; }"
      result, _ = @utils.send(:extract_code_block, code_block, ['static'], 'table')

      expect(result).to eq("const int *table(void) { return 0; }")
    end

    # A decorator word inside the name or body is not a decorator
    it "leaves a decorator word that appears inside the function name" do
      code_block = "PRIVATE int is_static(void) { return 1; }"
      result, _ = @utils.send(:extract_code_block, code_block, ['static'], 'is_static')

      expect(result).to eq(code_block)
    end

    it "strips the decorator itself when an attribute string ahead of it holds the same word" do
      code_block = '__attribute__((section(".text.static"))) static int g(void) { return 0; }'
      result, _ = @utils.send(:extract_code_block, code_block, ['static'], 'g')

      expect(result).to eq('__attribute__((section(".text.static"))) int g(void) { return 0; }')
    end

    it "leaves the text alone when a decorator from the expanded copy is absent" do
      code_block = "PRIVATE int hidden(void) { return 0; }"
      result, newlines = @utils.send(:extract_code_block, code_block, ['static'], 'hidden')

      expect(result).to eq(code_block)
      expect(newlines).to eq(0)
    end
  end

  context "#adjust_line_num" do
    it "returns nil when line_num is nil" do
      expect(@utils.send(:adjust_line_num, nil, 3)).to be_nil
    end

    it "returns line_num unchanged when stripped_newlines is 0" do
      expect(@utils.send(:adjust_line_num, 10, 0)).to eq(10)
    end

    it "adds stripped_newlines to line_num" do
      expect(@utils.send(:adjust_line_num, 5, 2)).to eq(7)
    end

    it "handles a single stripped newline" do
      expect(@utils.send(:adjust_line_num, 1, 1)).to eq(2)
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

    # The statement comes from a function's body, whose comments are blanked to spaces, while a
    # code block under fallback preprocessing keeps them
    it "finds a statement whose code block copy holds a block comment" do
      text   = "int f(void) { static int x /* count */ = 0; return x; }"
      result = @utils.replace_compound_declaration_with_noops(text, "static int x   = 0;", "PH_X", 1)

      expect(result).to eq("int f(void) { (void)0; /* `PH_X` replaced with no-op plus variable renamed & promoted to module-scope */ return x; }")
    end

    it "finds a compound statement whose code block copy holds a line comment" do
      text   = "int f(void) {\n  static int a, // first\n    b;\n  return a + b;\n}"
      result = @utils.replace_compound_declaration_with_noops(text, "static int a,  b;", "PH_A", 2)

      expect(result.scan("(void)0;").length).to eq(2)
      expect(result).not_to include("static int a,")
      expect(result).to include("return a + b;")
    end

    it "finds a statement whose code block copy holds comments after earlier no-op comments" do
      text   = "int f(void) { (void)0; /* `PH_A` replaced */ static int x /* count */ = 0; return x; }"
      result = @utils.replace_compound_declaration_with_noops(text, "static int x   = 0;", "PH_X", 1)

      expect(result).to include("/* `PH_A` replaced */ (void)0; /* `PH_X`")
      expect(result).not_to include("static int x")
    end
  end

  context "#rename_c_identifiers" do
    it "replaces a single token-bounded occurrence" do
      result = @utils.rename_c_identifiers("count = 0;", { "count" => "partial_foo_count" })
      expect(result).to eq("partial_foo_count = 0;")
    end

    it "replaces all occurrences throughout the text (gsub)" do
      result = @utils.rename_c_identifiers("count = count + 1;", { "count" => "partial_foo_count" })
      expect(result).to eq("partial_foo_count = partial_foo_count + 1;")
    end

    it "does not replace left-bounded substrings" do
      result = @utils.rename_c_identifiers("recount = 0;", { "count" => "partial_foo_count" })
      expect(result).to eq("recount = 0;")
    end

    it "does not replace right-bounded substrings" do
      result = @utils.rename_c_identifiers("count_down = 0;", { "count" => "partial_foo_count" })
      expect(result).to eq("count_down = 0;")
    end

    it "does not replace interior substrings" do
      result = @utils.rename_c_identifiers("recount_down = 0;", { "count" => "partial_foo_count" })
      expect(result).to eq("recount_down = 0;")
    end

    it "replaces identifier in parentheses context" do
      result = @utils.rename_c_identifiers("foo(count)", { "count" => "partial_foo_count" })
      expect(result).to eq("foo(partial_foo_count)")
    end

    it "replaces pointer dereference context" do
      result = @utils.rename_c_identifiers("*count = 0;", { "count" => "partial_foo_count" })
      expect(result).to eq("*partial_foo_count = 0;")
    end

    it "replaces array subscript context" do
      result = @utils.rename_c_identifiers("count[0]", { "count" => "partial_foo_count" })
      expect(result).to eq("partial_foo_count[0]")
    end

    it "replaces comparison context without spaces" do
      result = @utils.rename_c_identifiers("count==5", { "count" => "partial_foo_count" })
      expect(result).to eq("partial_foo_count==5")
    end

    it "replaces compound assignment without spaces" do
      result = @utils.rename_c_identifiers("count+=1", { "count" => "partial_foo_count" })
      expect(result).to eq("partial_foo_count+=1")
    end

    it "replaces address-of context" do
      result = @utils.rename_c_identifiers("&count", { "count" => "partial_foo_count" })
      expect(result).to eq("&partial_foo_count")
    end

    it "returns empty string unchanged" do
      result = @utils.rename_c_identifiers("", { "count" => "partial_foo_count" })
      expect(result).to eq("")
    end

    it "returns unchanged text when old_name not present" do
      text   = "value = 5;"
      result = @utils.rename_c_identifiers(text, { "count" => "partial_foo_count" })
      expect(result).to eq(text)
    end

    # A literal's text is data the program uses, and a comment's is prose
    it "leaves the name alone inside a string literal, a character literal or a comment" do
      text   = "printf(\"count=%d\", count); c = 'count'; /* count */ // count\ncount++;"
      result = @utils.rename_c_identifiers(text, { "count" => "partial_foo_count" })
      expect(result).to eq("printf(\"count=%d\", partial_foo_count); c = 'count'; /* count */ // count\npartial_foo_count++;")
    end

    # A member and a tag live apart from variables, so they keep a name a variable shares
    it "leaves a member or a tag that shares the name alone" do
      text   = "struct count *p = &count; p->count = s.count; union count u; enum count e; f(.count = count);"
      result = @utils.rename_c_identifiers(text, { "count" => "partial_foo_count" })
      expect(result).to eq("struct count *p = &partial_foo_count; p->count = s.count; union count u; enum count e; f(.count = partial_foo_count);")
    end

    # C23 digit separators would otherwise open a character literal
    it "renames past a number written with digit separators" do
      result = @utils.rename_c_identifiers("m = 1'000 + count + 2'000;", { "count" => "partial_foo_count" })
      expect(result).to eq("m = 1'000 + partial_foo_count + 2'000;")
    end

    # An asm template refers to a named operand inside its string, and the name must follow
    it "renames an asm template's references to an operand named after the variable" do
      text   = '__asm__ volatile ("mov %[count], %w[count]" : [count] "+r" (count));'
      result = @utils.rename_c_identifiers(text, { "count" => "partial_foo_count" })
      expect(result).to eq('__asm__ volatile ("mov %[partial_foo_count], %w[partial_foo_count]" : [partial_foo_count] "+r" (partial_foo_count));')
    end

    # A body in the function is local to it, so a name it holds is renamed everywhere, member
    # access included, and its members and their uses keep agreeing. That holds for a member
    # declared any way and for a name the body only uses.
    it "renames a name a local struct or union body holds everywhere, member access included" do
      text   = "struct { int count; } s = {0}; union u { int count; } v; struct lc { int count; } t = { .count = count }; s.count = ++count; p->count = 1;"
      result = @utils.rename_c_identifiers(text, { "count" => "partial_foo_count" })
      expect(result).to eq("struct { int partial_foo_count; } s = {0}; union u { int partial_foo_count; } v; struct lc { int partial_foo_count; } t = { .partial_foo_count = partial_foo_count }; s.partial_foo_count = ++partial_foo_count; p->partial_foo_count = 1;")
    end

    it "finds the names a body holds past attributes, function-pointer members and braces in comments" do
      renames = { "hist" => "partial_foo_hist", "handler" => "partial_foo_handler", "size" => "partial_foo_size" }
      text    = "struct __attribute__((packed)) tag { char c[sizeof(hist[0])]; void (*handler)(void); /* { */ char q[sizeof(\"}\")]; } s; s.handler = handler; x.size = size;"
      result  = @utils.rename_c_identifiers(text, renames)
      expect(result).to eq("struct __attribute__((packed)) tag { char c[sizeof(partial_foo_hist[0])]; void (*partial_foo_handler)(void); /* { */ char q[sizeof(\"}\")]; } s; s.partial_foo_handler = partial_foo_handler; x.size = partial_foo_size;")
    end

    # A macro may open an asm template, so its string is recognized by the reference alone
    it "renames an operand reference in a template a macro opens" do
      text   = '__asm__ __volatile__( LOCK_PREFIX "incl %[count]" : [count] "+m" (count) );'
      result = @utils.rename_c_identifiers(text, { "count" => "partial_foo_count" })
      expect(result).to eq('__asm__ __volatile__( LOCK_PREFIX "incl %[partial_foo_count]" : [partial_foo_count] "+m" (partial_foo_count) );')
    end

    # A head may hold a C23 attribute, a macro or a comment ahead of the body's brace
    it "finds a body past a C23 attribute, a macro or a comment in its head" do
      text   = "struct [[gnu::packed]] { int a; } x; struct PACKED_ALIGN(4) { int b; } y; struct /* wire */ { int c; } z; x.a = a; y.b = b; z.c = c;"
      result = @utils.rename_c_identifiers(text, { "a" => "p_a", "b" => "p_b", "c" => "p_c" })
      expect(result).to eq("struct [[gnu::packed]] { int p_a; } x; struct PACKED_ALIGN(4) { int p_b; } y; struct /* wire */ { int p_c; } z; x.p_a = p_a; y.p_b = p_b; z.p_c = p_c;")
    end

    it "renames every name it maps in one pass" do
      result = @utils.rename_c_identifiers("a = b + ab;", { "a" => "x_a", "b" => "x_b" })
      expect(result).to eq("x_a = x_b + ab;")
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

  context "#locate_functions_in_source" do
    it "returns each function's line from one search of the source" do
      expect(@code_finder).to receive(:find_all_in_c_file)
        .with('/path/to/file.c', ['void foo(void) {}', 'void missing(void) {}']).once
        .and_return([42, nil])

      result = @utils.locate_functions_in_source(code_blocks: ['void foo(void) {}', 'void missing(void) {}'], filepath: '/path/to/file.c')
      expect(result).to eq([42, nil])
    end
  end

  context "#locate_declarations_in_text" do
    it "returns the line where each declaration appears in the text, in order" do
      text = "int a;\nint tick(void);\nint tock(void);\n"
      expect(@code_finder).to receive(:find_in_c_string).with(text, 'int tock(void);').and_return(3)
      expect(@code_finder).to receive(:find_in_c_string).with(text, 'int tick(void);').and_return(2)

      expect(@utils.locate_declarations_in_text(signatures: ['int tock(void);', 'int tick(void);'], text: text)).to eq([3, 2])
    end

    it "returns nil for a declaration not in the text" do
      allow(@code_finder).to receive(:find_in_c_string).and_return(nil)

      expect(@utils.locate_declarations_in_text(signatures: ['int tick(void);'], text: '')).to eq([nil])
    end

    # Blanking costs a pass over the whole file, so one blanked copy serves every declaration
    it "searches every declaration in one blanked copy of the text" do
      searched = []
      allow(@code_finder).to receive(:find_in_c_string) { |text, _signature| searched << text; nil }

      @utils.locate_declarations_in_text(signatures: ['int tick(void);', 'int tock(void);'], text: "/* c */\nint tick(void);\n")

      expect(searched.size).to eq(2)
      expect(searched.map(&:object_id).uniq.size).to eq(1)
    end

    # A commented-out copy of the declaration would otherwise be found first
    it "searches the text with its comments blanked and its lines kept" do
      line_comment  = '// int tick(void);'
      block_comment = '/* int tick(void); */'
      expect(@code_finder).to receive(:find_in_c_string)
        .with("#{' ' * line_comment.length}\n#{' ' * block_comment.length}\nint tick(void);\n", 'int tick(void);')
        .and_return(3)

      @utils.locate_declarations_in_text(signatures: ['int tick(void);'], text: "#{line_comment}\n#{block_comment}\nint tick(void);\n")
    end

    it "keeps a comment marker inside a string literal" do
      text = "int open(const char *url) __attribute__((deprecated(\"see http://x\")));\n"
      expect(@code_finder).to receive(:find_in_c_string).with(text, 'int open(void);').and_return(nil)

      @utils.locate_declarations_in_text(signatures: ['int open(void);'], text: text)
    end
  end

  context "#locate_functions_via_preprocessed" do
    let(:filepath)              { '/path/to/source.c' }
    let(:preprocessed_filepath) { '/build/preproc/source.i' }
    let(:blocks)                { ['void foo(void) {}', 'void bar(void) {}', 'void baz(void) {}'] }

    it "returns each function's line from the preprocessed file when found there" do
      expect(@code_finder).to receive(:find_all_in_preprocessed_file).with(preprocessed_filepath, blocks).once.and_return([10, 20, 30])
      expect(@code_finder).not_to receive(:find_all_in_c_file)

      result = @utils.locate_functions_via_preprocessed(code_blocks: blocks, filepath: filepath, preprocessed_filepath: preprocessed_filepath)
      expect(result).to eq([10, 20, 30])
    end

    # The source is searched once, and only for what the preprocessed file lacks
    it "falls back to the C source for just the functions the preprocessed file lacks" do
      allow(@code_finder).to receive(:find_all_in_preprocessed_file).and_return([nil, 20, nil])
      expect(@code_finder).to receive(:find_all_in_c_file).with(filepath, [blocks[0], blocks[2]]).once.and_return([25, nil])

      result = @utils.locate_functions_via_preprocessed(code_blocks: blocks, filepath: filepath, preprocessed_filepath: preprocessed_filepath)
      expect(result).to eq([25, 20, nil])
    end

    it "logs the fallback search once for each function that needs it" do
      allow(@code_finder).to receive(:find_all_in_preprocessed_file).and_return([10, nil, nil])
      allow(@code_finder).to receive(:find_all_in_c_file).and_return([25, nil])

      expect(@loginator).to receive(:log)
        .with("Using fallback C function location search for #{filepath}", Verbosity::OBNOXIOUS, LogLabels::WARNING).twice

      @utils.locate_functions_via_preprocessed(code_blocks: blocks, filepath: filepath, preprocessed_filepath: preprocessed_filepath)
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
