# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Selected functions and file-scope variables whose storage class or inline specifier a macro
# supplies.
#
# A project can hide `static` behind a macro of its own, such as `#define PRIVATE static`. A
# Partial strips `static` from every function and variable it exposes, so each links from the
# test. The implementation header declares the expanded, stripped declaration. The
# implementation source must define the same one, or the macro, carried in with the module's
# header, makes the definition static again after a non-static declaration.
#
# Each case compiles and links real objects with warnings as errors, in accurate and fallback
# preprocessing alike, since both reconcile with the full expansion.

require 'spec_helper'
require 'spec_integration_helper'
require 'partials_generation_integration_helper'

describe 'Partial functions and variables whose decorators a macro supplies' do

  include_context 'requires gcc'

  after(:each) { cleanup_dir( @dir ) }

  ENGINE_HEADER = <<~C
    #ifndef ENGINE_H
    #define ENGINE_H
    #define PRIVATE static
    #define STATICINLINE static inline
    #define EXTERN extern
    #define LEN 2
    int engine_get(void);
    #endif
  C

  def engine(source, mode:, header: ENGINE_HEADER, **options)
    result = generate_partial(
      module_name: 'engine', header: header, source: source, source_includes: ['engine.h'], mode: mode, **options
    )
    @dir = result.dir
    return result
  end

  def link_cleanly(result, references:)
    link = link_partial( result, references: references, flags: '-Wall -Werror' )
    expect( link.ok ).to be( true ), "expected a clean link, got: #{link.first_diagnostic}"
  end

  [:accurate, :fallback].each do |mode|
    context "with #{mode} preprocessing" do
      before { skip 'directives-only preprocessing is unavailable' if mode == :accurate and !directives_only_supported? }

      it 'links a selected function a macro makes static' do
        result = engine( "#include \"engine.h\"\nPRIVATE int helper(void) { return 41; }\nint engine_get(void) { return helper() + 1; }\n", mode: mode )

        expect( result.impl_c ).to include( 'int helper(void) { return 41; }' )
        expect( result.impl_c ).not_to include( 'PRIVATE int helper' )
        link_cleanly( result, references: ['helper', 'engine_get'] )
      end

      # Fallback keeps comments in the text it extracts, where a ';' or a split name could mislead
      it 'links a selected function whose head holds comments' do
        source = "#include \"engine.h\"\nPRIVATE int helper /* c */ (int a) /* adds; */ { return a ? helper( a - 1 ) : 41; }\n" \
                 "int engine_get(void) { return helper( 2 ) + 1; }\n"
        result = engine( source, mode: mode )

        expect( result.impl_c ).not_to include( 'PRIVATE int helper' )
        link_cleanly( result, references: ['helper', 'engine_get'] )
      end

      # Each body line keeps its own line, so coverage and diagnostics still point at the module
      it 'keeps the function name and every body line at their own lines' do
        source = "#include \"engine.h\"\nPRIVATE int\nhelper(int a,\n       int b)\n{\n  return a + b;\n}\nint engine_get(void) { return helper( 20, 22 ); }\n"
        result = engine( source, mode: mode )

        expect( result.impl_c ).to match( /^#line 3 "[^"]*engine\.c"\nint helper\(int a, int b\)\n\n\{\n  return a \+ b;\n\}/ )
        link_cleanly( result, references: ['helper'] )
      end

      it 'links a selected function a macro makes static and inline' do
        result = engine( "#include \"engine.h\"\nSTATICINLINE int twice(int v) { return v * 2; }\nint engine_get(void) { return twice( 21 ); }\n", mode: mode )

        expect( result.impl_c ).to include( 'int twice(int v) { return v * 2; }' )
        link_cleanly( result, references: ['twice', 'engine_get'] )
      end
    end
  end

  # A variable's storage class can come from a macro too. Its extern and its definition then
  # take the expanded declaration, less `static`, so the two agree and the name links.
  [:accurate, :fallback].each do |mode|
    context "a file-scope variable, with #{mode} preprocessing" do
      before { skip 'directives-only preprocessing is unavailable' if mode == :accurate and !directives_only_supported? }

      it 'links a variable a macro makes static' do
        result = engine( "#include \"engine.h\"\nPRIVATE int counter;\nint engine_get(void) { return counter; }\n", mode: mode )

        expect( result.impl_h ).to include( 'extern int counter;' )
        expect( result.impl_h ).not_to include( 'extern PRIVATE' )
        link_cleanly( result, references: ['counter', 'engine_get'] )
      end

      it 'links a qualified array a macro makes static, with its initializer' do
        result = engine( "#include \"engine.h\"\nPRIVATE const unsigned char table[LEN] = { 1, 2 };\nint engine_get(void) { return table[1]; }\n", mode: mode )

        expect( result.impl_h ).to include( 'extern const unsigned char table[2];' )
        expect( result.impl_c ).to include( 'const unsigned char table[2] = { 1, 2 };' )
        link_cleanly( result, references: ['table', 'engine_get'] )
      end

      # A variable only declared extern gets a weak definition, however `extern` is spelled
      it 'gives a variable a macro declares extern its weak definition' do
        result = engine( "#include \"engine.h\"\nEXTERN int shared;\nint engine_get(void) { return shared; }\n", mode: mode )

        expect( result.impl_h ).to include( 'extern int shared;' )
        expect( result.impl_h ).not_to include( 'extern EXTERN' )
        expect( result.impl_c ).to include( '__attribute__((weak)) int shared;' )
        link_cleanly( result, references: ['shared', 'engine_get'] )
      end

      # A variable the module defines needs no weak definition, whatever its declaration says
      it 'gives no weak definition to a variable a macro declares extern and the module defines' do
        result = engine( "#include \"engine.h\"\nEXTERN int shared;\nint shared = 1;\nint engine_get(void) { return shared; }\n", mode: mode )

        expect( result.impl_c ).not_to include( '__attribute__((weak))' )
        link_cleanly( result, references: ['shared', 'engine_get'] )
      end

      it 'links each variable of a compound declaration a macro makes static' do
        result = engine( "#include \"engine.h\"\nPRIVATE int low = 1, *high;\nint engine_get(void) { return low + (high != 0); }\n", mode: mode )

        expect( result.impl_h ).to include( 'extern int low;' )
        link_cleanly( result, references: ['low', 'high', 'engine_get'] )
      end

      # The type a macro hid ahead of it is named once and declared once
      it 'links a variable a macro makes static that defines its own type' do
        result = engine( "#include \"engine.h\"\nPRIVATE struct { int a; } state;\nint engine_get(void) { return state.a; }\n", mode: mode )

        expect( result.types_h.scan( 'ceedling_partial_engine_state_t;' ).size ).to eq( 1 )
        expect( result.impl_h ).to include( 'extern ceedling_partial_engine_state_t state;' )
        link_cleanly( result, references: ['state', 'engine_get'] )
      end

      it 'links a variable a macro makes static that defines a tagged type' do
        result = engine( "#include \"engine.h\"\nPRIVATE struct pair { int a; } first;\nint engine_get(void) { return first.a; }\n", mode: mode )

        link_cleanly( result, references: ['first', 'engine_get'] )
      end
    end
  end

  # A macro after a type's closing brace, as `struct pk { … } PACKED;`, reads as a variable in
  # the written text. The expansion shows the macro belongs to the type, so the type keeps it.
  [:accurate, :fallback].each do |mode|
    context "a type a macro ends, with #{mode} preprocessing" do
      before { skip 'directives-only preprocessing is unavailable' if mode == :accurate and !directives_only_supported? }

      def ended_types(declarations, mode:, extra: {}, includes: [])
        header = "#ifndef ENGINE_H\n#define ENGINE_H\n#{includes.map { |name| "#include \"#{name}\"\n" }.join}" \
                 "#define PACKED __attribute__((packed))\n#define ALIGNED(n) __attribute__((aligned(n)))\n" \
                 "#{declarations}int engine_get(void);\n#endif\n"
        engine( "#include \"engine.h\"\nint engine_get(void) { return 0; }\n", mode: mode, header: header, extra: extra, header_includes: includes )
      end

      # The link's test translation unit asserts the layout through the generated headers
      def link_holding(result, assertion)
        link = link_partial( result, references: ['engine_get'], stubs: "_Static_assert( #{assertion}, \"layout kept\" );\n", flags: '-Wall -Werror' )
        expect( link.ok ).to be( true ), "expected a clean link, got: #{link.first_diagnostic}"
      end

      it 'keeps the macro with its type, so the type keeps its layout' do
        result = ended_types( "struct pk { char c; int i; } PACKED;\n", mode: mode )

        expect( result.types_h ).to include( 'struct pk { char c; int i; } PACKED;' )
        expect( result.impl_h ).not_to match( /\bPACKED;/ )
        link_holding( result, 'sizeof( struct pk ) == 5' )
      end

      # Variables after the macro read it as the start of their type, and the type keeps it too
      {
        'one variable'                   => ["struct pk { char c; int i; } PACKED inst;\n", 'inst', 'sizeof( inst ) == 5'],
        'a static variable'              => ["static struct pk { char c; int i; } PACKED inst;\n", 'inst', 'sizeof( inst ) == 5'],
        'two variables'                  => ["struct pk { char c; int i; } PACKED i1, i2;\n", 'i1', 'sizeof( i1 ) == 5 && sizeof( i2 ) == 5'],
        'an initialized const variable'  => ["const struct pk { char c; int i; } PACKED inst = { 1, 2 };\n", 'inst', 'sizeof( inst ) == 5'],
        'a pointer'                      => ["struct pk { char c; int i; } PACKED *gp;\n", 'gp', 'sizeof( *gp ) == 5']
      }.each do |shape, (declaration, variable, assertion)|
        it "keeps the macro with its type ahead of #{shape}" do
          result = engine( "#include \"engine.h\"\n#{declaration}int engine_get(void) { return sizeof( #{variable} ); }\n",
                           mode: mode, header: "#ifndef ENGINE_H\n#define ENGINE_H\n#define PACKED __attribute__((packed))\nint engine_get(void);\n#endif\n" )

          expect( result.impl_h ).not_to match( /PACKED \*?#{variable}/ )
          link = link_partial( result, references: [variable, 'engine_get'], stubs: "_Static_assert( #{assertion}, \"layout kept\" );\n", flags: '-Wall -Werror' )
          expect( link.ok ).to be( true ), "expected a clean link, got: #{link.first_diagnostic}"
        end
      end

      # A macro for a storage class or a qualifier after the brace belongs to the variable
      it 'keeps a storage class and a qualifier a macro writes after the brace with the variable' do
        header = "#ifndef ENGINE_H\n#define ENGINE_H\n#define PRIVATE static\n#define CONST const\nint engine_get(void);\n#endif\n"
        source = "#include \"engine.h\"\nstruct pk { char c; int i; } PRIVATE inst;\nstruct pc { char c; } CONST ro = { 1 };\n" \
                 "int engine_get(void) { return inst.i + ro.c; }\n"
        result = engine( source, mode: mode, header: header )

        expect( result.types_h ).not_to match( /\}\s*(?:PRIVATE|CONST|static|const)\b/ )
        link = link_partial( result, references: ['inst', 'ro', 'engine_get'], flags: '-Wall -Werror' )
        expect( link.ok ).to be( true ), "expected a clean link, got: #{link.first_diagnostic}"
      end

      it 'keeps a function-like macro with its type' do
        result = ended_types( "struct al { char c; } ALIGNED(8);\n", mode: mode )

        expect( result.types_h ).to include( 'struct al { char c; } ALIGNED(8);' )
        link_holding( result, '_Alignof( struct al ) == 8' )
      end

      it 'keeps the macro with a type a storage class declares alone' do
        link_holding( ended_types( "static struct pk { char c; int i; } PACKED;\n", mode: mode ), 'sizeof( struct pk ) == 5' )
      end

      # The types header reaches the macro through the module header's own includes
      it 'keeps a macro another header defines with its type' do
        toolchain = "#ifndef TOOLCHAIN_H\n#define TOOLCHAIN_H\n#define TIGHT __attribute__((packed))\n#endif\n"
        result    = ended_types( "struct pk { char c; int i; } TIGHT;\n", mode: mode, extra: { 'toolchain.h' => toolchain }, includes: ['toolchain.h'] )

        link_holding( result, 'sizeof( struct pk ) == 5' )
      end

      # A macro that names a real variable leaves a variable behind in the expansion too, and a
      # forward declaration of its tag defines nothing that says otherwise
      it 'keeps a variable a macro names after a type it defines' do
        header = "#ifndef ENGINE_H\n#define ENGINE_H\n#define MY_VAR g_var\nint engine_get(void);\n#endif\n"
        result = engine( "#include \"engine.h\"\nstruct pt;\nstruct pt { int a; } MY_VAR;\nint engine_get(void) { return MY_VAR.a; }\n", mode: mode, header: header )

        expect( result.types_h ).not_to include( '} MY_VAR;' )
        link = link_partial( result, references: ['MY_VAR', 'engine_get'], flags: '-Wall -Werror -fno-common' )
        expect( link.ok ).to be( true ), "expected a clean link, got: #{link.first_diagnostic}"
      end
    end
  end

  context 'with accurate preprocessing' do
    before { skip 'directives-only preprocessing is unavailable' unless directives_only_supported? }

    it 'links a selected function from a source with CRLF line endings' do
      source = "#include \"engine.h\"\r\nPRIVATE int helper(void)\r\n{\r\n  return 41;\r\n}\r\nint engine_get(void) { return helper() + 1; }\r\n"
      link_cleanly( engine( source, mode: :accurate ), references: ['helper', 'engine_get'] )
    end

    # The mock takes the private function's place, and the tested public one calls it
    it 'compiles a public function under test that calls its private neighbor through the mock' do
      result = engine(
        "#include \"engine.h\"\nPRIVATE int helper(void) { return 41; }\nint engine_get(void) { return helper() + 1; }\n",
        mode: :accurate, tests_expose: PartializerConfig::PUBLIC, mocks_expose: PartializerConfig::PRIVATE
      )

      expect( result.interface_h ).to include( 'int helper(void);' )
      compile = compile_objects( result, flags: '-Wall -Werror' )
      expect( compile.ok ).to be( true ), "expected a clean compile, got: #{compile.first_diagnostic}"
    end
  end
end
