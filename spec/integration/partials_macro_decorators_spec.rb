# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# A selected function whose storage class or inline specifier a macro supplies.
#
# A project can hide `static` behind a macro of its own, such as `#define PRIVATE static`. A
# Partial strips `static` from every function it selects, so the function links from the test.
# The implementation header declares the expanded, stripped signature. The implementation
# source must define the same signature, or the macro, carried in with the module's header,
# makes the definition static again after a non-static declaration.
#
# Each case compiles and links real objects with warnings as errors, in accurate and fallback
# preprocessing alike, since both reconcile with the full expansion.

require 'spec_helper'
require 'spec_integration_helper'
require 'partials_generation_integration_helper'

describe 'Partial functions whose decorators a macro supplies' do

  include_context 'requires gcc'

  after(:each) { cleanup_dir( @dir ) }

  ENGINE_HEADER = <<~C
    #ifndef ENGINE_H
    #define ENGINE_H
    #define PRIVATE static
    #define STATICINLINE static inline
    int engine_get(void);
    #endif
  C

  def engine(source, mode:, **options)
    result = generate_partial(
      module_name: 'engine', header: ENGINE_HEADER, source: source, source_includes: ['engine.h'], mode: mode, **options
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
