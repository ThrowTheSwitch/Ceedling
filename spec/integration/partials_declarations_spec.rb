# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Declaration spellings in a Partial, proven with a real compiler.
#
# A Partial reads each of a module's declarations and writes it again. It must tell a type from a
# variable or a function, split a compound declaration, and read each name and type whole. Each
# case below is a spelling real modules use, and each must generate, compile and link. A case
# that defines a type also compiles the types header alone, since every generated file
# includes it.
#
# Generation runs through spec/support/integration/partials_generation_integration_helper.rb.

require 'spec_helper'
require 'spec_integration_helper'
require 'partials_generation_integration_helper'
require 'tempfile'

describe 'Declarations in a Partial' do

  include_context 'requires gcc'
  before { skip 'directives-only preprocessing is unavailable' unless directives_only_supported? }

  after(:each) { cleanup_partial( @result ) }

  def guarded(body)
    "#ifndef TICKER_H\n#define TICKER_H\n#{body}#endif\n"
  end

  def ticker(header:, source:)
    generate_partial(
      module_name: 'ticker', header: guarded( header ), source: "#include \"ticker.h\"\n#{source}",
      source_includes: ['ticker.h'], tests_expose: PartializerConfig::PUBLIC
    )
  end

  # `stubs` is C the stand-in test file holds after the headers, such as code reading a member
  def expect_link(result, references, stubs: '', flags: '')
    link = link_partial( result, references: references, stubs: stubs, flags: flags )
    expect( link.ok ).to be(true), "expected a clean link, got: #{link.first_error}"
  end

  def expect_types_header_compiles(result)
    compile = compile_types_header_alone( result )
    expect( compile.ok ).to be(true), "expected the types header to compile alone, got: #{compile.first_error}"
  end

  # ---------------------------------------------------------------------------
  context 'a struct, union or enum keyword leading a statement' do
  # ---------------------------------------------------------------------------

    # An initialized definition is never a common symbol, so a copy in the types header
    # collides in every translation unit that includes it
    it 'defines an initialized struct variable once, in the implementation source' do
      @result = ticker(
        header: "struct ops { int a; };\nint ticker_get(void);\n",
        source: "struct ops g_ops = { 1 };\nint ticker_get(void) { return g_ops.a; }\n"
      )

      expect( @result.types_h ).not_to include( 'g_ops' )
      expect( @result.impl_h ).to include( 'extern struct ops g_ops;' )
      expect_types_header_compiles( @result )
      expect_link( @result, ['g_ops', 'ticker_get'], stubs: "int read_ops(void) { return g_ops.a; }\n" )
    end

    it 'defines an initialized union variable once' do
      @result = ticker(
        header: "union u { int i; float f; };\nint ticker_get(void);\n",
        source: "union u g_u = { 0 };\nint ticker_get(void) { return g_u.i; }\n"
      )

      expect( @result.types_h ).not_to include( 'g_u' )
      expect_link( @result, ['g_u'] )
    end

    it 'defines an initialized array of struct pointers once' do
      @result = ticker(
        header: "struct ops { int a; };\nint ticker_get(void);\n",
        source: "struct ops a1 = { 1 };\nstruct ops b1 = { 2 };\nstruct ops *tbl[] = { &a1, &b1 };\n" \
                "int ticker_get(void) { return tbl[1]->a; }\n"
      )

      expect( @result.types_h ).not_to include( 'tbl' )
      expect( @result.impl_h ).to include( 'extern struct ops * tbl[];' )
      expect_link( @result, ['tbl', 'a1', 'b1'] )
    end

    # The usual way to write a driver's table of operations
    it 'defines a table of designated function pointers once' do
      @result = ticker(
        header: "struct drv_ops { int (*init)(void); int (*read)(void); };\nint drv_init(void);\nint drv_read(void);\n",
        source: "int drv_init(void) { return 1; }\nint drv_read(void) { return 2; }\n" \
                "struct drv_ops g_drv = { .init = drv_init, .read = drv_read };\n"
      )

      expect( @result.types_h ).not_to include( 'g_drv' )
      expect_types_header_compiles( @result )
      expect_link( @result, ['g_drv'], stubs: "int read_drv(void) { return g_drv.read(); }\n" )
    end

    it 'defines an initialized array of structs once' do
      @result = ticker(
        header: "struct ops { int a; };\nint ticker_get(void);\n",
        source: "struct ops g_arr[2] = { {1}, {2} };\nint ticker_get(void) { return g_arr[1].a; }\n"
      )

      expect( @result.impl_h ).to include( 'extern struct ops g_arr[2];' )
      expect_link( @result, ['g_arr'] )
    end

    # A ';' after a function's body is legal at file scope, and some generated code writes one
    it 'selects a function returning a struct pointer with a stray semicolon after its body' do
      @result = ticker(
        header: "struct ops { int a; };\nstruct ops *make_ops(void);\n",
        source: "static struct ops k = { 1 };\nstruct ops *make_ops(void) { return &k; };\n"
      )

      expect( @result.types_h ).not_to include( 'make_ops' )
      expect( @result.impl_h ).to include( 'struct ops *make_ops(void);' )
      expect_link( @result, ['make_ops'] )
    end

    it 'selects a function returning a struct with a stray semicolon after its body' do
      @result = ticker(
        header: "struct ops { int a; };\nstruct ops make_v(void);\n",
        source: "struct ops make_v(void) { struct ops o = { 1 }; return o; };\n"
      )

      expect( @result.types_h ).not_to include( 'make_v' )
      expect_link( @result, ['make_v'] )
    end

    # GCC accepts a type's attributes after its closing brace, as packed structs often have them
    it 'carries a type with an attribute after its body into the types header' do
      @result = ticker(
        header: "struct pk { char c; int i; } __attribute__((packed));\nint ticker_size(void);\n",
        source: "struct pk g_pk;\nint ticker_size(void) { return (int)sizeof(struct pk); }\n"
      )

      expect( @result.types_h ).to include( 'struct pk { char c; int i; } __attribute__((packed));' )
      expect_types_header_compiles( @result )
      expect_link( @result, ['g_pk', 'ticker_size'], stubs: "int read_pk(void) { return g_pk.c; }\n" )
    end

    # Zephyr and Linux spell the attribute through a macro their toolchain header defines
    it 'carries a type with an attribute macro after its body into the types header' do
      @result = generate_partial(
        module_name: 'ticker',
        header: guarded( "#include \"toolchain.h\"\nstruct pk { char c; int i; } __packed;\nint ticker_size(void);\n" ),
        source: "#include \"ticker.h\"\nstruct pk g_pk;\nint ticker_size(void) { return (int)sizeof(struct pk); }\n",
        header_includes: ['toolchain.h'], source_includes: ['ticker.h'], tests_expose: PartializerConfig::PUBLIC,
        extra: { 'toolchain.h' => "#ifndef TOOLCHAIN_H\n#define TOOLCHAIN_H\n#define __packed __attribute__((packed))\n#endif\n" }
      )

      expect( @result.types_h ).to include( 'struct pk { char c; int i; } __packed;' )
      expect_types_header_compiles( @result )
      expect_link( @result, ['g_pk', 'ticker_size'], stubs: "int read_pk(void) { return g_pk.c; }\n" )
    end
  end

  # ---------------------------------------------------------------------------
  context 'type specifiers and keywords' do
  # ---------------------------------------------------------------------------

    # An extern repeats a variable's type, which a specifier or keyword may spell. Every case
    # here compiles in GCC 13's default dialect, which CI's Linux job uses.
    it 'declares variables whose types a specifier taking parentheses spells' do
      @result = ticker(
        header: "int ticker_get(void);\n",
        source: "int *g_pp;\ntypeof(int) g_t;\n_Atomic(int) g_a;\n_Alignas(8) int g_al;\ntypeof(*g_pp) g_q;\n__typeof__(int) g_u;\n" \
                "_Alignas(8) static int s_as;\nint ticker_get(void) { return g_t + g_a + g_al + g_q + g_u + s_as; }\n"
      )

      expect( @result.impl_h ).to include( 'extern typeof(int) g_t;', 'extern _Atomic(int) g_a;', 'extern typeof(*g_pp) g_q;' )
      expect( @result.impl_h ).to include( 'extern _Alignas(8) int s_as;' )
      expect_link( @result, ['g_t', 'g_a', 'g_al', 'g_q', 'g_u', 's_as'] )
    end

    it 'declares variables whose types a keyword spells' do
      @result = ticker(
        header: "int ticker_get(void);\n",
        source: "_Bool g_f;\n_Atomic int g_ai;\n_Thread_local int g_tl;\n_Complex double g_c;\n" \
                "int ticker_get(void) { return g_f + g_ai + g_tl + (int)__real__ g_c; }\n"
      )

      expect( @result.impl_h ).to include( 'extern _Bool g_f;', 'extern _Atomic int g_ai;', 'extern _Thread_local int g_tl;', 'extern _Complex double g_c;' )
      expect_link( @result, ['g_f', 'g_ai', 'g_c'] )
    end

    # A weak definition of a struct never completed can't compile, whatever keyword leads its type.
    # Clang rejects `_Atomic` on an incomplete struct, so only a unit spec covers that keyword.
    it 'writes no weak definition for a thread-local extern of a struct never completed' do
      @result = ticker(
        header: "struct opaque;\nextern _Thread_local struct opaque g_o;\n" \
                "typedef struct opaque opaque_t;\nextern _Thread_local opaque_t g_t;\nint ticker_get(void);\n",
        source: "int ticker_get(void) { return 1; }\n"
      )

      expect( @result.impl_c ).not_to include( 'g_o', 'g_t' )
      compile = compile_objects( @result )
      expect( compile.ok ).to be(true), "expected a clean compile, got: #{compile.first_error}"
    end

    it 'selects a function whose return type a specifier spells' do
      @result = ticker(
        header: "typeof(int) tf(void);\n",
        source: "typeof(int) tf(void) { return 0; }\n"
      )

      expect( @result.impl_h ).to include( 'typeof(int) tf(void);' )
      expect_link( @result, ['tf'] )
    end
  end

  # ---------------------------------------------------------------------------
  context "names holding '$'" do
  # ---------------------------------------------------------------------------

    # GCC and Clang accept '$' in an identifier on most targets, and a case needs a compiler that does
    before do
      probe = Tempfile.new( ['dollar', '.c'] )
      probe.write( "int a$b;\n" ) && probe.close
      _out, _err, status = Open3.capture3( "#{partials_compiler} -fsyntax-only #{probe.path}" )
      probe.unlink
      skip "#{partials_compiler} rejects '$' in identifiers" unless status.success?
    end

    it "declares a variable and selects a function whose names hold '$'" do
      @result = ticker(
        header: "int f$1(void);\n",
        source: "static int hook$2;\nint g$v[2];\nint f$1(void) { return hook$2 + g$v[1]; }\n"
      )

      expect( @result.impl_h ).to include( 'extern int hook$2;', 'extern int g$v[2];', 'int f$1(void);' )
      expect_link( @result, ['hook$2', 'g$v', 'f$1'] )
    end

    it "promotes a function-scope static whose name holds '$'" do
      @result = ticker(
        header: "int ticker_get(void);\n",
        source: "int ticker_get(void) { static int c$1 = 0; c$1++; return c$1; }\n"
      )

      expect( @result.impl_h ).to include( 'extern int partial_ticker_get_c$1;' )
      expect_link( @result, ['ticker_get', 'partial_ticker_get_c$1'] )
    end

    # The source's prototype gives an inline function another header defines its external
    # definition, so the Partial must carry that prototype
    it "carries the prototype of an inline function another header defines, named with '$'" do
      @result = generate_partial(
        module_name: 'ticker', header: guarded( "int ticker_get(void);\n" ),
        source: "#include \"ticker.h\"\n#include \"engine_api.h\"\nextern int eng$twice(void);\nint ticker_get(void) { return 1; }\n",
        source_includes: ['ticker.h', 'engine_api.h'], tests_expose: PartializerConfig::PUBLIC,
        extra: { 'engine_api.h' => "#ifndef ENGINE_API_H\n#define ENGINE_API_H\ninline int eng$twice(void) { return 42; }\n#endif\n" }
      )

      expect( @result.impl_c ).to include( 'extern int eng$twice(void);' )
      link = link_partial( @result, references: ['eng$twice'], flags: '-O0' )
      expect( link.ok ).to be(true), "expected a clean link, got: #{link.first_error}"
    end

    # A weak definition of a struct never completed can't compile, so none is written
    it "writes no weak definition for an extern whose struct type, named with '$', is never completed" do
      @result = ticker(
        header: "struct h$s;\nextern struct h$s the$h;\ntypedef struct h$t h$t_t;\nextern h$t_t the$t;\nint ticker_get(void);\n",
        source: "int ticker_get(void) { return 1; }\n"
      )

      expect( @result.impl_c ).not_to include( 'the$h', 'the$t' )
      compile = compile_objects( @result )
      expect( compile.ok ).to be(true), "expected a clean compile, got: #{compile.first_error}"
    end
  end

  # ---------------------------------------------------------------------------
  context 'asm labels' do
  # ---------------------------------------------------------------------------

    # An asm label names a variable's symbol, so the test's extern must carry it to reach the definition
    it 'keeps each spelling of an asm label on a variable extern' do
      @result = ticker(
        header: "int ticker_get(void);\n",
        source: "int g_s __asm__(\"ticker_s_symbol\") = 1;\nint g_arr[2] __asm(\"ticker_arr_symbol\");\n" \
                "int g_b asm(\"ticker_b_symbol\");\nint ticker_get(void) { return g_s + g_arr[1] + g_b; }\n"
      )

      expect( @result.impl_h ).to include( 'extern int g_s __asm__("ticker_s_symbol");', 'extern int g_arr[2] __asm("ticker_arr_symbol");',
                                           'extern int g_b asm("ticker_b_symbol");' )
      expect_link( @result, ['g_s', 'g_arr', 'g_b', 'ticker_get'] )
    end

    # A compiler applies the label of a variable's first declaration to its definition
    it 'keeps an asm label the module header gives a variable' do
      @result = ticker(
        header: "extern int g_h __asm__(\"ticker_h_symbol\");\nint ticker_get(void);\n",
        source: "int g_h = 3;\nint ticker_get(void) { return g_h; }\n"
      )

      expect( @result.impl_h ).to include( 'extern int g_h __asm__("ticker_h_symbol");' )
      expect_link( @result, ['g_h', 'ticker_get'] )
    end

    # A weak definition stands in for a variable the module only declares, under the same symbol
    it 'keeps an asm label on the weak definition of a variable the module only declares' do
      @result = ticker(
        header: "extern int g_w asm(\"ticker_w_symbol\");\nint ticker_get(void);\n",
        source: "int ticker_get(void) { return g_w; }\n"
      )

      expect( @result.impl_h ).to include( 'extern int g_w asm("ticker_w_symbol");' )
      expect( @result.impl_c ).to include( 'int g_w asm("ticker_w_symbol");' )
      expect_link( @result, ['g_w', 'ticker_get'] )
    end

    it 'keeps an asm label on a promoted static' do
      @result = ticker(
        header: "int ticker_get(void);\n",
        source: "int ticker_get(void) { static int s asm(\"ticker_static_symbol\") = 2; return s; }\n"
      )

      expect( @result.impl_h ).to include( 'extern int partial_ticker_get_s asm("ticker_static_symbol");' )
      expect_link( @result, ['partial_ticker_get_s', 'ticker_get'] )
    end
  end

  # ---------------------------------------------------------------------------
  context 'compound declarations' do
  # ---------------------------------------------------------------------------

    # Every variable of a compound declaration needs its own extern, wherever the initializers sit
    it 'declares each variable when the first one has an initializer' do
      @result = ticker(
        header: "int ticker_get(void);\n",
        source: "int g_x = 0, g_y;\nint ticker_get(void) { return g_x + g_y; }\n"
      )

      expect( @result.impl_h ).to include( 'extern int g_x;', 'extern int g_y;' )
      expect_link( @result, ['g_x', 'g_y'] )
    end

    it 'declares each variable past commas inside initializers' do
      @result = ticker(
        header: "struct ops { int a; };\nint ticker_get(void);\n",
        source: "char *g_s = \"a,b\", *g_t;\nint g_a[2] = {1, 2}, g_b;\nstruct ops g_o = { 1 }, g_n = { 2 };\n" \
                "int ticker_get(void) { return g_a[1] + g_b + g_o.a + g_n.a + (g_t == g_s); }\n"
      )

      expect( @result.impl_h ).to include( 'extern int g_b;', 'extern struct ops g_n;' )
      expect_link( @result, ['g_s', 'g_t', 'g_a', 'g_b', 'g_o', 'g_n'] )
    end

    # A later variable takes only the base type. A qualifier after a star, an attribute after
    # the name and a line break belong to the first declarator.
    it 'gives each later variable only the base type' do
      @result = ticker(
        header: "int ticker_get(void);\n",
        source: "int *const g_a = 0, g_b;\nconst unsigned char\n  g_tbl[] = {1, 2}, g_after = 3;\n" \
                "int g_c __attribute__((aligned(4))) = 1, g_d;\n" \
                "int ticker_get(void) { g_b++; return g_b + g_after + g_d + (g_a == 0); }\n"
      )

      expect( @result.impl_h ).to include( 'extern int g_b;', 'extern const unsigned char g_after;', 'extern int g_d;' )
      expect_link( @result, ['g_a', 'g_b', 'g_tbl', 'g_after', 'g_c', 'g_d'], stubs: "int read_after(void) { return sizeof(g_after) == 1; }\n" )
    end

    # Partials promote a function's statics to file scope, renamed, so each one needs its own definition
    it 'promotes each static of a compound statement in a function' do
      @result = ticker(
        header: "int ticker_get(void);\n",
        source: "int ticker_get(void) { static int x = 0, y; static int a = 1, *p = &a; y++; return x + y + *p; }\n"
      )

      expect( @result.impl_h ).to include( 'extern int partial_ticker_get_y;', 'extern int * partial_ticker_get_p;' )
      expect( @result.impl_c ).to include( 'int *partial_ticker_get_p = &partial_ticker_get_a;' )
      expect_link( @result, ['ticker_get', 'partial_ticker_get_x', 'partial_ticker_get_y', 'partial_ticker_get_p'] )
    end

    # A qualifier macro between the type and the name is part of the base type
    it 'promotes each static of a compound statement whose type holds a qualifier macro' do
      @result = ticker(
        header: "int f1(void);\nint f2(void);\n",
        source: "#define MYQ\nint f1(void) { static int MYQ cnt, other; return cnt + other; }\n" \
                "int f2(void) { static int MYQ cnt, other; return cnt + other; }\n"
      )

      expect( @result.impl_h ).to include( 'extern int MYQ partial_f1_other;', 'extern int MYQ partial_f2_cnt;' )
      expect_link( @result, ['partial_f1_cnt', 'partial_f1_other', 'partial_f2_cnt', 'partial_f2_other'] )
    end

    # A local struct's member that a promoted static shares a name with is renamed alike, where declared and used
    it 'promotes a static that shares its name with a local struct member' do
      @result = ticker(
        header: "int ticker_get(void);\n",
        source: "int ticker_get(void) { static int count; struct { int count; } s = {0}; s.count = ++count; return s.count; }\n"
      )

      expect( @result.impl_c ).to include( 'struct { int partial_ticker_get_count; } s = {0}; s.partial_ticker_get_count = ++partial_ticker_get_count;' )
      expect_link( @result, ['ticker_get', 'partial_ticker_get_count'] )
    end

    # A name a local struct's body uses is still the promoted static's
    it 'promotes a static that a local struct body names' do
      @result = ticker(
        header: "int ticker_get(void);\n",
        source: "int ticker_get(void) { static int hist[4]; struct { char c[sizeof(hist)]; /* { */ } s; return (int)sizeof(s.c) + hist[0]; }\n"
      )

      expect( @result.impl_c ).to include( 'char c[sizeof(partial_ticker_get_hist)];' )
      expect_link( @result, ['ticker_get', 'partial_ticker_get_hist'] )
    end

    it 'promotes statics that local struct bodies hold past attributes and function-pointer members' do
      @result = ticker(
        header: "void tick(void);\nint f1(void);\nint f2(void);\n",
        source: "void tick(void) { }\n" \
                "int f1(void) { static int hist[4]; struct __attribute__((packed)) { char c[sizeof(hist[0])]; int hist; } s = {{0}, 1}; return s.hist + hist[0]; }\n" \
                "int f2(void) { static void (*handler)(void) = tick; struct { void (*handler)(void); } s = { handler }; s.handler(); return 0; }\n"
      )

      expect_link( @result, ['f1', 'f2', 'partial_f1_hist', 'partial_f2_handler'] )
    end

    it 'promotes statics that name one another across statements and in array sizes' do
      @result = ticker(
        header: "int ticker_get(void);\n",
        source: "int ticker_get(void) { static int n = 4, m[sizeof(n)]; static int *q = &n; " \
                "static const char *s = \"n and m\"; return m[0] + *q + s[0]; }\n"
      )

      expect( @result.impl_h ).to include( 'extern int partial_ticker_get_m[sizeof(partial_ticker_get_n)];' )
      expect( @result.impl_c ).to include( 'int *partial_ticker_get_q = &partial_ticker_get_n;', '"n and m"' )
      expect_link( @result, ['ticker_get', 'partial_ticker_get_m', 'partial_ticker_get_q', 'partial_ticker_get_s'] )
    end
  end

  # ---------------------------------------------------------------------------
  context 'C23 attributes' do
  # ---------------------------------------------------------------------------

    # The oldest spelling of the standard that GCC and Clang accept with these attributes
    def c23 = '-std=c2x'

    before do
      probe = Tempfile.new( ['c23', '.c'] ).tap { |file| file.write( "[[maybe_unused]] static int probe;\n" ) }.tap( &:close )
      _out, _err, status = Open3.capture3( "#{partials_compiler} #{c23} -fsyntax-only #{probe.path}" )
      skip "#{partials_compiler} does not accept C23 attributes" unless status.success?
    end

    it 'declares a variable an attribute leads without its storage class' do
      @result = ticker( header: "int ticker_get(void);\n", source: "[[maybe_unused]] static int count;\nint ticker_get(void) { return count; }\n" )

      expect( @result.impl_h ).to include( 'extern int count;' )
      expect_link( @result, ['count', 'ticker_get'], flags: c23 )
    end

    it 'declares each variable of a compound declaration an attribute leads' do
      @result = ticker( header: "int ticker_get(void);\n", source: "[[maybe_unused]] static int a, b;\nint ticker_get(void) { return a + b; }\n" )

      expect( @result.impl_h ).to include( 'extern int a;', 'extern int b;' )
      expect_link( @result, ['a', 'b', 'ticker_get'], flags: c23 )
    end

    it 'declares a variable whose name an attribute follows' do
      @result = ticker( header: "int ticker_get(void);\n", source: "static int buf [[maybe_unused]] [4];\nint ticker_get(void) { return buf[0]; }\n" )

      expect( @result.impl_h ).to include( 'extern int buf[4];' )
      expect_link( @result, ['buf', 'ticker_get'], flags: c23 )
    end

    it 'reads a function an attribute leads, and the functions after it' do
      @result = ticker(
        header: "int ticker_peek(void);\nint ticker_get(void);\n",
        source: "[[nodiscard]] int ticker_peek(void) { return 1; }\nint ticker_get(void) { return ticker_peek(); }\n"
      )

      expect_link( @result, ['ticker_peek', 'ticker_get'], flags: c23 )
    end
  end

  # ---------------------------------------------------------------------------
  context 'a declaration that defines its type' do
  # ---------------------------------------------------------------------------

    # The type is written once, in the types header, and each variable names it. Two copies of
    # one tagged body are a redefinition, and two anonymous bodies are two different types.
    it 'declares a static of an anonymous struct by the name the Partial gives its type' do
      @result = ticker( header: "int ticker_get(void);\n", source: "static struct { int count; } s_ctx;\nint ticker_get(void) { return s_ctx.count; }\n" )

      expect( @result.types_h ).to include( 'typedef struct { int count; } ceedling_partial_ticker_s_ctx_t;' )
      expect( @result.impl_h ).to include( 'extern ceedling_partial_ticker_s_ctx_t s_ctx;' )
      expect_types_header_compiles( @result )
      expect_link( @result, ['s_ctx', 'ticker_get'], stubs: "void reset(void) { s_ctx.count = 0; }\n" )
    end

    # The test sees an anonymous enum's values, since the types header defines them
    it 'declares a static of an anonymous enum whose values the test can name' do
      @result = ticker( header: "int ticker_get(void);\n", source: "static enum { IDLE, RUN } s_state;\nint ticker_get(void) { return s_state == RUN; }\n" )

      expect_link( @result, ['s_state', 'ticker_get'], stubs: "void start(void) { s_state = RUN; }\n" )
    end

    it 'defines a tagged type once for a variable with an initializer' do
      @result = ticker( header: "int ticker_get(void);\n", source: "struct ops { int a; } g_ops = { 1 };\nint ticker_get(void) { return g_ops.a; }\n" )

      expect( @result.impl_c ).to include( 'ceedling_partial_ticker_g_ops_t g_ops = { 1 };' )
      expect_link( @result, ['g_ops', 'ticker_get'], stubs: "int copy(void) { struct ops o = g_ops; return o.a; }\n" )
    end

    # A member's array size belongs to the type, and every variable of the statement shares it
    it 'shares one type among the variables of a compound declaration' do
      @result = ticker(
        header: "int ticker_get(void);\n",
        source: "struct pair { int a[2]; } g_p1, g_p2;\nint ticker_get(void) { return g_p1.a[1] + g_p2.a[0]; }\n"
      )

      expect( @result.impl_h ).to include( 'extern ceedling_partial_ticker_g_p1_t g_p1;', 'extern ceedling_partial_ticker_g_p1_t g_p2;' )
      expect_link( @result, ['g_p1', 'g_p2'], stubs: "_Static_assert( sizeof( g_p2.a ) == 2 * sizeof( int ), \"member size\" );\n" )
    end

    # An attribute after the body belongs to the type, so the layout stays the module's
    it 'keeps an attribute after the body on the type' do
      @result = ticker(
        header: "int ticker_get(void);\n",
        source: "static struct { char c; int i; } __attribute__((packed)) s_pk;\nint ticker_get(void) { return s_pk.i; }\n"
      )

      expect_link( @result, ['s_pk'], stubs: "_Static_assert( sizeof( s_pk ) == 5, \"packed\" );\n" )
    end

    it 'declares a const variable and a pointer of one type' do
      @result = ticker(
        header: "int ticker_get(void);\n",
        source: "static const struct { int a; } k = { 3 }, *kp = &k;\nint ticker_get(void) { return kp->a; }\n"
      )

      expect( @result.impl_h ).to include( 'extern const ceedling_partial_ticker_k_t k;', 'extern const ceedling_partial_ticker_k_t * kp;' )
      expect_link( @result, ['k', 'kp', 'ticker_get'] )
    end

    # A header's extern of an anonymous type matches its definition in another module, since a
    # typedef leaves the type anonymous. The weak definition yields to it.
    it 'links a header extern of an anonymous struct against its definition in another module' do
      @result = ticker( header: "extern struct { int a; } g_x;\nint ticker_get(void);\n", source: "int ticker_get(void) { return g_x.a; }\n" )
      board = File.join( @result.dir, 'board.c' )
      File.write( board, "struct { int a; } g_x = { 5 };\n" )

      expect( @result.impl_c ).to include( '__attribute__((weak)) ceedling_partial_ticker_g_x_t g_x;' )
      expect_link( @result, ['g_x', 'ticker_get'], flags: board )
    end

    it 'writes a forward declaration to the types header as written' do
      @result = ticker(
        header: "struct node;\ntypedef struct node *node_ref_t;\nint ticker_get(void);\n",
        source: "struct node { int value; };\nstatic node_ref_t head;\nint ticker_get(void) { return head ? head->value : 0; }\n"
      )

      expect( @result.types_h ).to include( "struct node;\n" )
      expect( @result.impl_h ).not_to include( 'extern struct node;' )
      expect_link( @result, ['head', 'ticker_get'] )
    end
  end

  # ---------------------------------------------------------------------------
  context 'a function-scope static that defines its type' do
  # ---------------------------------------------------------------------------

    # Promotion moves the static to module scope, so its type moves too, named for the function
    # and the variable
    it 'promotes a static of an anonymous struct with its type' do
      @result = ticker( header: "int ticker_get(void);\n", source: "int ticker_get(void) { static struct { int n; } st; return ++st.n; }\n" )

      expect( @result.types_h ).to include( 'typedef struct { int n; } ceedling_partial_ticker_ticker_get_st_t;' )
      expect( @result.impl_h ).to include( 'extern ceedling_partial_ticker_ticker_get_st_t partial_ticker_get_st;' )
      expect_link( @result, ['ticker_get', 'partial_ticker_get_st'], stubs: "void reset(void) { partial_ticker_get_st.n = 0; }\n" )
    end

    it 'promotes a static of an anonymous enum whose values the test can name' do
      @result = ticker( header: "int ticker_get(void);\n", source: "int ticker_get(void) { static enum { IDLE, RUN } mode; mode = RUN; return mode; }\n" )

      expect_link( @result, ['ticker_get', 'partial_ticker_get_mode'], stubs: "int idle(void) { return partial_ticker_get_mode == IDLE; }\n" )
    end

    # A tag local to a function may shadow a file-scope tag, so the promoted type takes the name
    # the Partial gives it, and the function's later uses of the tag follow
    it 'renames a local tag that shadows a file-scope one' do
      @result = ticker(
        header: "struct st { int a; };\nint ticker_get(void);\n",
        source: "int ticker_get(void) { static struct st { int n; } s; struct st *p = &s; return p->n; }\n"
      )

      expect( @result.types_h ).to include( 'struct st { int a; };', 'typedef struct ceedling_partial_ticker_ticker_get_s_t { int n; } ceedling_partial_ticker_ticker_get_s_t;' )
      expect( @result.impl_c ).to include( 'struct ceedling_partial_ticker_ticker_get_s_t *p = &partial_ticker_get_s;' )
      expect_link( @result, ['ticker_get', 'partial_ticker_get_s'] )
    end

    it 'renames the same local tag in two functions apart' do
      @result = ticker(
        header: "int f1(void);\nint f2(void);\n",
        source: "int f1(void) { static struct state { int a; } s; return s.a; }\nint f2(void) { static struct state { char c; } s; return s.c; }\n"
      )

      expect_link( @result, ['f1', 'f2', 'partial_f1_s', 'partial_f2_s'] )
    end

    # A member sharing a promoted static's name is renamed alike in the type and in its uses
    it 'promotes a static whose type has a member sharing another static name' do
      @result = ticker(
        header: "int ticker_get(void);\n",
        source: "int ticker_get(void) {\n  static int count;\n  static struct st { int count; } s;\n  s.count++;\n  return count + s.count;\n}\n"
      )

      expect_link( @result, ['ticker_get', 'partial_ticker_get_count', 'partial_ticker_get_s'] )
    end

    # Each no-op stands on the line its statement did, and a statement over several lines keeps
    # them. On Windows the source is written with CRLF endings, as a Windows checkout has them.
    it 'keeps the function to its line count' do
      source = "int ticker_get(void) {\n  static struct {\n    int n;\n  } st;\n  return st.n;\n}\n"
      @result = ticker( header: "int ticker_get(void);\n", source: source )

      body = @result.impl_c[/int ticker_get\(void\) \{.*?\n\}/m]
      expect( body.count( "\n" ) ).to eq( source.count( "\n" ) - 1 ), "the function as generated: #{body.inspect}"
    end
  end

  # ---------------------------------------------------------------------------
  context "ceedling.h's names for a Partial's types" do
  # ---------------------------------------------------------------------------

    # The macros need ceedling.h and the prefix a test build defines with Partials enabled
    let(:ceedling_h) { "-I#{File.expand_path( '../../lib/ceedling', __dir__ )} -DCEEDLING_PARTIALS_PREFIX=ceedling_partial_" }

    it 'names the type of a variable declared together with its type' do
      @result = ticker( header: "int ticker_get(void);\n", source: "static struct { int count; } s_ctx;\nint ticker_get(void) { return s_ctx.count; }\n" )

      expect_link( @result, ['s_ctx'], flags: ceedling_h,
                   stubs: "#include \"ceedling.h\"\nint saved(void) { PARTIAL_TYPE(ticker, s_ctx) copy = s_ctx; return copy.count; }\n" )
    end

    it 'names the type of a promoted static declared together with its type' do
      @result = ticker( header: "int ticker_get(void);\n", source: "int ticker_get(void) { static struct st { int n; } st; return st.n; }\n" )

      expect_link( @result, ['partial_ticker_get_st'], flags: ceedling_h,
                   stubs: "#include \"ceedling.h\"\nint saved(void) { PARTIAL_LOCAL_TYPE(ticker, ticker_get, st) copy = PARTIAL_LOCAL_VAR(ticker_get, st); return copy.n; }\n" )
    end
  end

end
