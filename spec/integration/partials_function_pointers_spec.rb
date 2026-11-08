# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Function pointers in a Partial, proven with a real compiler.
#
# A function pointer's name sits inside parentheses, and its type wraps around the name. A
# Partial has to read each declaration whole, tell a function from a pointer to one, and write
# each variable's extern with its whole declarator. Each case below is a spelling a real module
# uses, and each must generate, compile and link.
#
# Generation runs through spec/support/integration/partials_generation_integration_helper.rb.

require 'spec_helper'
require 'spec_integration_helper'
require 'partials_generation_integration_helper'

describe 'Function pointers in a Partial' do

  include_context 'requires gcc'
  before { skip 'directives-only preprocessing is unavailable' unless directives_only_supported? }

  after(:each) { cleanup_partial( @result ) }

  def guarded(body)
    "#ifndef TICKER_H\n#define TICKER_H\n#{body}#endif\n"
  end

  def ticker(header:, source:, tests: PartializerConfig::PUBLIC, mocks: nil)
    generate_partial(
      module_name: 'ticker', header: guarded( header ), source: "#include \"ticker.h\"\n#{source}",
      source_includes: ['ticker.h'], tests_expose: tests, mocks_expose: mocks
    )
  end

  def expect_link(result, references, stubs: '', flags: '')
    link = link_partial( result, references: references, stubs: stubs, flags: flags )
    expect( link.ok ).to be(true), "expected a clean link, got: #{link.first_error}"
  end

  # The mocked interface compiles the way the mock CMock generates from it includes it
  def expect_interface_compile(result)
    probe = File.join( result.dir, "probe_#{result.module_name}_interface.c" )
    File.write( probe, "#include \"ceedling_partial_#{result.module_name}_interface.h\"\nint main(void) { return 0; }\n" )

    compile = syntax_only( result, probe )
    expect( compile.ok ).to be(true), "expected a clean compile, got: #{compile.first_error}"
  end

  # ---------------------------------------------------------------------------
  context 'functions' do
  # ---------------------------------------------------------------------------

    it 'selects a function taking a function pointer' do
      @result = ticker(
        header: "void ticker_register(int (*cb)(int));\nint ticker_count(void);\n",
        source: "static int calls;\nvoid ticker_register(int (*cb)(int)) { calls = cb(calls); }\nint ticker_count(void) { return calls; }\n"
      )

      expect( @result.impl_h ).to include( 'void ticker_register(int (*cb)(int));' )
      expect_link( @result, ['ticker_register', 'ticker_count'] )
    end

    it 'selects a function returning a function pointer' do
      @result = ticker(
        header: "int ticker_bump(int n);\nint (*ticker_get(void))(int);\n",
        source: "int ticker_bump(int n) { return n + 1; }\nint (*ticker_get(void))(int) { return ticker_bump; }\n"
      )

      expect( @result.impl_h ).to include( 'int (*ticker_get(void))(int);' )
      expect_link( @result, ['ticker_get'] )
    end

    # The source declares a function another module defines, so its prototype is carried
    it 'carries the prototype of an external function taking a function pointer' do
      @result = ticker(
        header: "int ticker_bump(int n);\nint ticker_fire(int n);\n",
        source: "int board_apply(int (*fn)(int), int n);\nint ticker_bump(int n) { return n + 1; }\n" \
                "int ticker_fire(int n) { return board_apply(ticker_bump, n); }\n"
      )

      expect( @result.impl_c ).to include( 'int board_apply(int (*fn)(int), int n);' )
      expect_link( @result, ['ticker_fire'], stubs: "int board_apply(int (*fn)(int), int n) { return fn(n); }\n" )
    end

    it 'mocks a function taking a function pointer' do
      @result = ticker(
        header: "void ticker_register(int (*cb)(int));\nint ticker_count(void);\n",
        source: "static int calls;\nvoid ticker_register(int (*cb)(int)) { calls = cb(calls); }\nint ticker_count(void) { return calls; }\n",
        tests: nil, mocks: PartializerConfig::PUBLIC
      )

      expect( @result.interface_h ).to include( 'void ticker_register(int (*cb)(int));' )
      expect_interface_compile( @result )
    end

    # A mock needs only a prototype, so a function the module declares without a body is mocked too
    it 'mocks functions the header only declares, taking or returning a function pointer' do
      @result = ticker(
        header: "void ticker_register(int (*cb)(int));\nint (*ticker_getter(void))(int);\nint ticker_count(void);\n",
        source: "int ticker_count(void) { return 0; }\n",
        tests: nil, mocks: PartializerConfig::PUBLIC
      )

      expect( @result.interface_h ).to include( 'void ticker_register(int (*cb)(int));', 'int (*ticker_getter(void))(int);' )
      expect_interface_compile( @result )
    end
  end

  # ---------------------------------------------------------------------------
  context 'variables' do
  # ---------------------------------------------------------------------------

    it 'declares a file-scope static function pointer with its whole declarator' do
      @result = ticker(
        header: "typedef int (*ticker_cb_t)(int);\nvoid ticker_register(ticker_cb_t cb);\nint ticker_fire(int n);\n",
        source: "static int (*s_hook)(int);\nvoid ticker_register(ticker_cb_t cb) { s_hook = cb; }\n" \
                "int ticker_fire(int n) { return s_hook ? s_hook(n) : -1; }\n"
      )

      expect( @result.impl_h ).to include( 'extern int (*s_hook)(int);' )
      expect_link( @result, ['s_hook', 'ticker_fire'] )
    end

    it 'declares a function pointer the header declares and the source defines once' do
      @result = ticker(
        header: "extern int (*g_hook)(int);\nint ticker_fire(int n);\n",
        source: "int (*g_hook)(int) = 0;\nint ticker_fire(int n) { return g_hook ? g_hook(n) : -1; }\n"
      )

      expect( @result.impl_h.scan( 'extern int (*g_hook)(int);' ).size ).to eq(1)
      expect( @result.impl_c ).to include( 'int (*g_hook)(int) = 0;' )
      expect_link( @result, ['g_hook'] )
    end

    # A variable the module only declares is defined elsewhere. A weak definition stands in for
    # it, and a real definition overrides that.
    it 'gives a function pointer only the header declares a weak definition' do
      @result = ticker(
        header: "extern int (*g_hook)(int);\nint ticker_fire(int n);\n",
        source: "int ticker_fire(int n) { return g_hook ? g_hook(n) : -1; }\n"
      )

      expect( @result.impl_c ).to include( '__attribute__((weak)) int (*g_hook)(int);' )
      expect_link( @result, ['g_hook', 'ticker_fire'], flags: '-fno-common' )
      expect_link( @result, ['g_hook', 'ticker_fire'], stubs: "int (*g_hook)(int) = 0;\n", flags: '-fno-common' )
    end

    # A pointer to a function returning a struct is a complete type, even when the struct isn't
    it 'gives a function pointer returning an incomplete struct a weak definition' do
      @result = ticker(
        header: "extern struct ticker_state (*ticker_make)(void);\nint ticker_ready(void);\n",
        source: "int ticker_ready(void) { return ticker_make != 0; }\n"
      )

      expect( @result.impl_c ).to include( '__attribute__((weak)) struct ticker_state (*ticker_make)(void);' )
      expect_link( @result, ['ticker_make', 'ticker_ready'], flags: '-fno-common' )
    end

    it 'declares an array of function pointers with its size' do
      @result = ticker(
        header: "int ticker_one(int n);\nint ticker_two(int n);\nint ticker_fire(int i, int n);\n",
        source: "int ticker_one(int n) { return n + 1; }\nint ticker_two(int n) { return n + 2; }\n" \
                "static int (*s_table[2])(int) = { ticker_one, ticker_two };\nint ticker_fire(int i, int n) { return s_table[i](n); }\n"
      )

      expect( @result.impl_h ).to include( 'extern int (*s_table[2])(int);' )
      expect_link( @result, ['s_table', 'ticker_fire'] )
    end

    it 'declares a constant function pointer' do
      @result = ticker(
        header: "int ticker_bump(int n);\nextern int (*const k_hook)(int);\n",
        source: "int ticker_bump(int n) { return n + 1; }\nint (*const k_hook)(int) = ticker_bump;\n"
      )

      expect( @result.impl_h ).to include( 'extern int (*const k_hook)(int);' )
      expect_link( @result, ['k_hook'] )
    end

    it 'declares a pointer to an array' do
      @result = ticker(
        header: "extern int (*g_row)[4];\nint ticker_sum(void);\n",
        source: "static int s_rows[2][4] = { { 1, 2, 3, 4 }, { 5, 6, 7, 8 } };\nint (*g_row)[4] = s_rows;\n" \
                "int ticker_sum(void) { return (*g_row)[0] + (*g_row)[3]; }\n"
      )

      expect( @result.impl_h ).to include( 'extern int (*g_row)[4];' )
      expect_link( @result, ['g_row', 'ticker_sum'] )
    end

    it 'declares a function pointer whose name sits in redundant parentheses' do
      @result = ticker(
        header: "int ticker_fire(int n);\n",
        source: "static int (*(s_paren))(int);\nint ticker_fire(int n) { return s_paren ? s_paren(n) : -1; }\n"
      )

      expect( @result.impl_h ).to include( 'extern int (*(s_paren))(int);' )
      expect_link( @result, ['s_paren', 'ticker_fire'] )
    end

    # An attribute after a declarator would draw a warning on the extern, which needs none
    it 'leaves a trailing attribute off a function-pointer table extern' do
      @result = ticker(
        header: "int ticker_one(void);\nint ticker_fire(int i);\n",
        source: "int ticker_one(void) { return 1; }\n" \
                "static int (* const s_vec[1])(void) __attribute__((used)) = { ticker_one };\n" \
                "int ticker_fire(int i) { return s_vec[i](); }\n"
      )

      expect( @result.impl_h ).to include( 'extern int (* const s_vec[1])(void);' )
      expect_link( @result, ['s_vec', 'ticker_fire'], flags: '-Werror=attributes' )
    end

    # An asm label names the symbol, so the extern has to carry it to reach the definition
    it 'keeps an asm label on a function pointer extern' do
      @result = ticker(
        header: "int ticker_bump(int n);\nint ticker_fire(int n);\n",
        source: "int ticker_bump(int n) { return n + 1; }\n" \
                "int (*g_lbl)(int) __asm__(\"ticker_hook_symbol\") = ticker_bump;\n" \
                "int ticker_fire(int n) { return g_lbl(n); }\n"
      )

      expect( @result.impl_h ).to include( 'extern int (*g_lbl)(int) __asm__("ticker_hook_symbol");' )
      expect_link( @result, ['g_lbl', 'ticker_fire'] )
    end

    it 'declares each function pointer of a compound declaration' do
      @result = ticker(
        header: "int ticker_fire(int n);\n",
        source: "static int (*s_a)(int), (*s_b)(int);\nint ticker_fire(int n) { return (s_a ? s_a(n) : 0) + (s_b ? s_b(n) : 0); }\n"
      )

      expect( @result.impl_h ).to include( 'extern int (*s_a)(int);', 'extern int (*s_b)(int);' )
      expect_link( @result, ['s_a', 's_b'] )
    end

    # A function-scope static moves to file scope under a name prefixed with its function's name
    it 'promotes a function-scope static function pointer with its whole declarator' do
      @result = ticker(
        header: "int ticker_bump(int n);\nint ticker_fire(int n);\n",
        source: "int ticker_bump(int n) { return n + 1; }\n" \
                "int ticker_fire(int n) { static int (*cache)(int) = 0; if (!cache) { cache = ticker_bump; } return cache(n); }\n"
      )

      expect( @result.impl_h ).to include( 'extern int (*partial_ticker_fire_cache)(int);' )
      expect_link( @result, ['partial_ticker_fire_cache', 'ticker_fire'] )
    end
  end

  # ---------------------------------------------------------------------------
  context 'a function whose name a Partial cannot read' do
  # ---------------------------------------------------------------------------

    # GCC accepts '$' in an identifier, and the extractor reads no name from one
    it 'stops the build with the definition the extractor could not name' do
      c_module = extract_c( "int count$all(void) { return 0; }\nint count_one(void);\n" )

      expect( c_module.function_definitions.map( &:name ) ).to eq( [nil] )
      expect { partials_helper.validate_function_names_readable( c_module, 'test_ticker', 'ticker' ) }
        .to raise_error( CeedlingException, /test_ticker::ticker .* declared by `int count\$all\(void\)`\./ )
    end
  end

end
