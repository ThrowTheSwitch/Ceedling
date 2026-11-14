
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
        hidden_decorators: [],
        code_block: "__pragma__ static void testFunc(int x) {\n  return x * 2;\n}"
      )
    end

    context "when output_type is :impl" do
      # A selected function's callers rely on it never returning
      it "keeps _Noreturn on a testable function" do
        func = double('function', name: 'die', decorators: ['static'], hidden_decorators: [], source_filepath: 'src/m.c', line_num: 3,
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

  # A macro the module's header defines, such as `#define PRIVATE static`, hides a decorator the
  # written head can't be stripped of. The implementation header declares the expanded,
  # stripped signature, so the definition takes the same one.
  context "#transform_function with decorators a macro hides" do
    def definition(code_block, hidden:, line_num: 10, name: 'helper', decorators: hidden)
      CExtractorTypes::CFunctionDefinition.new(
        name: name, code_block: code_block, line_num: line_num, decorators: decorators, hidden_decorators: hidden
      )
    end

    def transform(func, signature)
      @utils.transform_function( func, signature, :impl )
    end

    it "writes the head from the signature and keeps the body as written" do
      result = transform( definition( "PRIVATE int helper(void) {\n  return 41;\n}", hidden: ['static'] ), 'int helper(void)' )

      expect( result.code_block ).to eq( "int helper(void) {\n  return 41;\n}" )
      expect( result.line_num ).to eq( 10 )
    end

    it "rewrites a head a macro makes static and inline" do
      result = transform( definition( "STATICINLINE int twice(int v) { return v * 2; }", hidden: ['static', 'inline'], name: 'twice' ), 'int twice(int v)' )

      expect( result.code_block ).to eq( "int twice(int v) { return v * 2; }" )
    end

    # A macro that respells a keyword the head already names, as `#define inline __inline` does
    it "rewrites a head whose written decorator a macro turns into another" do
      func   = definition( "inline int tick(void) { return 1; }", hidden: ['__inline'], decorators: ['inline'], name: 'tick' )
      result = transform( func, 'int tick(void)' )

      expect( result.code_block ).to eq( "int tick(void) { return 1; }" )
    end

    # Coverage tools place a function at its name's line, and every body line keeps its own
    it "keeps the name's line and every body line of a head spread over several lines" do
      func   = definition( "PRIVATE int\nhelper(int a,\n       int b)\n{\n  return a + b;\n}", hidden: ['static'] )
      result = transform( func, "int helper(int a,\n       int b)" )

      expect( result.code_block ).to eq( "int helper(int a, int b)\n\n{\n  return a + b;\n}" )
      expect( result.line_num ).to eq( 11 )
    end

    it "keeps what follows the parameter list as written" do
      result = transform( definition( "PRIVATE int helper(void) /* note */ { return 1; }", hidden: ['static'] ), 'int helper(void)' )

      expect( result.code_block ).to eq( "int helper(void) /* note */ { return 1; }" )
    end

    # Fallback keeps comments, so a ';' in one after the list says nothing of K&R
    it "rewrites a head whose comment after the list holds a ';'" do
      result = transform( definition( "PRIVATE int helper(void) /* adds; */ { return 1; }", hidden: ['static'] ), 'int helper(void)' )

      expect( result.code_block ).to eq( "int helper(void) /* adds; */ { return 1; }" )
    end

    # Fallback keeps comments, so the name can sit apart from its list. The body's recursive
    # call must not pass for the name.
    it "finds the name in the head alone, past a comment ahead of the list" do
      code   = "PRIVATE int helper /* c */ (int a) { return a ? helper( a - 1 ) : 0; }"
      result = transform( definition( code, hidden: ['static'] ), 'int helper (int a)' )

      expect( result.code_block ).to eq( "int helper (int a) { return a ? helper( a - 1 ) : 0; }" )
    end

    # A multibyte character ahead of the name counts as one character but several bytes
    it "keeps the body intact behind a multibyte character ahead of the name" do
      code   = "__attribute__((section(\"région\"))) PRIVATE int\nhelper(void)\n{ return 1; }"
      result = transform( definition( code, hidden: ['static'] ), '__attribute__((section("région"))) int helper(void)' )

      expect( result.code_block ).to eq( "__attribute__((section(\"région\"))) int helper(void)\n{ return 1; }" )
      expect( result.line_num ).to eq( 11 )
    end

    # A K&R definition declares its parameters between the list and the body
    it "strips as written when a ';' follows the parameter list" do
      code   = "PRIVATE int helper(a)\n  int a;\n{ return a; }"
      result = transform( definition( code, hidden: ['static'] ), 'int helper(a)' )

      expect( result.code_block ).to eq( code )
    end

    it "strips as written when nothing is hidden" do
      result = transform( definition( "static int helper(void) { return 1; }", hidden: [], decorators: ['static'] ), 'int helper(void)' )

      expect( result.code_block ).to eq( "int helper(void) { return 1; }" )
    end

    it "keeps line breaks the head's CRLF endings hold" do
      result = transform( definition( "PRIVATE int\r\nhelper(void)\r\n{\r\n  return 1;\r\n}", hidden: ['static'] ), 'int helper(void)' )

      expect( result.code_block ).to eq( "int helper(void)\r\n{\r\n  return 1;\r\n}" )
      expect( result.line_num ).to eq( 11 )
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
