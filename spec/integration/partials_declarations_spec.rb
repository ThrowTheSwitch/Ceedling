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
  def expect_link(result, references, stubs: '')
    link = link_partial( result, references: references, stubs: stubs )
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

end
