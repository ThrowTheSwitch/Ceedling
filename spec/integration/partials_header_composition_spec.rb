# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# How a Partial's generated headers compose, and whether a compiler accepts them.
#
# Every example here states the behavior Ceedling should have. Several fail against the
# current implementation, which is the point: issue #1319 reports that the generated types
# header is not self-contained, and issue #1293 reports that it must nonetheless appear
# early. The two requirements conflict, and the failures below mark exactly where.
#
# Generation runs through the helpers in
# spec/support/integration/partials_generation_integration_helper.rb rather than a
# `ceedling test:` build. See that file for why, and for what is real versus doubled.
#
# A case states its own include lists because includes reach the partializer from the
# preprocessor stage rather than from the extractor. Varying that order is how the
# ordering question becomes testable.
#
# Every case's C is preprocessed before extraction, the way the real pipeline does it. That
# rules whole classes of suspicion out: conditional compilation is already resolved by real
# GCC, comments are gone, and a module's file holds only its own lines. What remains is what
# survives that treatment -- which is the only thing worth asserting about.

require 'spec_helper'
require 'spec_integration_helper'
require 'partials_generation_integration_helper'

describe 'Partial header composition' do

  # Compiling is the whole point, so a missing compiler must not read as a pass. These cases
  # also assume accurate preprocessing: fallback resolves strictly less, and what it cannot
  # resolve is the fallback spec's subject rather than a failure here.
  include_context 'requires gcc'
  before { skip 'directives-only preprocessing is unavailable' unless directives_only_supported? }

  after(:each) { cleanup_partial( @result ) }

  # A header declaring a type Ceedling knows nothing about. Standing in for the
  # reporters' common.h and Types.h.
  FOUNDATION_H = <<~C
    #ifndef FOUNDATION_H
    #define FOUNDATION_H
    typedef signed short S16;
    typedef unsigned char U8;
    typedef struct { int id; } Event_t;
    #endif
  C

  # ---------------------------------------------------------------------------
  context 'a types header that references types from elsewhere' do
  # ---------------------------------------------------------------------------

    # Issue #1319, first reporter. Types live in the module header and reference types
    # from a header the source includes after the module's own header.
    it 'compiles when the module header is included before its dependency' do
      @result = generate_partial(
        module_name: 'lm75b',
        header: <<~C,
          #ifndef LM75B_H
          #define LM75B_H
          typedef struct {
              S16 os_over_temperature_deci_c;
              U8  pin_state;
          } lm75b_config_t;
          void lm75b_init(void);
          #endif
        C
        source: "#include <string.h>\n#include \"lm75b.h\"\n#include \"foundation.h\"\n",
        source_includes: ['<string.h>', 'lm75b.h', 'foundation.h'],
        extra: { 'foundation.h' => FOUNDATION_H }
      )

      compile = compile_partial( @result )
      expect( compile.ok ).to be(true), "expected a clean compile, got: #{compile.first_error}"
    end

    # Issue #1319, second reporter. The type lives in the source file instead, and
    # references a type from a header that source includes.
    it 'compiles when the type is declared in the source file' do
      @result = generate_partial(
        module_name: 'eventqueue',
        header: "#ifndef EVENTQUEUE_H\n#define EVENTQUEUE_H\nvoid eventqueue_push(void);\n#endif\n",
        source: <<~C,
          #include "eventqueue.h"
          #include "foundation.h"
          typedef struct {
              Event_t test_event;
          } MyStruct_t;
        C
        source_includes: ['eventqueue.h', 'foundation.h'],
        extra: { 'foundation.h' => FOUNDATION_H }
      )

      compile = compile_partial( @result )
      expect( compile.ok ).to be(true), "expected a clean compile, got: #{compile.first_error}"
    end

    # The order that happens to work today, kept so a fix is not mistaken for having
    # changed this case.
    it 'compiles when the dependency is included before the module header' do
      @result = generate_partial(
        module_name: 'lm75b',
        header: "#ifndef LM75B_H\n#define LM75B_H\ntypedef struct { S16 temp; } lm75b_t;\n#endif\n",
        source: "#include \"foundation.h\"\n#include \"lm75b.h\"\n",
        source_includes: ['foundation.h', 'lm75b.h'],
        extra: { 'foundation.h' => FOUNDATION_H }
      )

      compile = compile_partial( @result )
      expect( compile.ok ).to be(true), "expected a clean compile, got: #{compile.first_error}"
    end

    # The property underneath both reports. A header that cannot be compiled on its own
    # is a liability wherever it is placed.
    it 'is self-contained, compiling with nothing included before it' do
      @result = generate_partial(
        module_name: 'lm75b',
        header: "#ifndef LM75B_H\n#define LM75B_H\ntypedef struct { S16 temp; } lm75b_t;\n#endif\n",
        source: "#include \"foundation.h\"\n#include \"lm75b.h\"\n",
        source_includes: ['foundation.h', 'lm75b.h'],
        extra: { 'foundation.h' => FOUNDATION_H }
      )

      compile = compile_types_header_alone( @result )
      expect( compile.ok ).to be(true), "expected the types header to stand alone, got: #{compile.first_error}"
    end

    it 'carries the includes its own types depend on' do
      @result = generate_partial(
        module_name: 'lm75b',
        header: "#ifndef LM75B_H\n#define LM75B_H\ntypedef struct { S16 temp; } lm75b_t;\n#endif\n",
        source: "#include \"foundation.h\"\n#include \"lm75b.h\"\n",
        source_includes: ['foundation.h', 'lm75b.h'],
        extra: { 'foundation.h' => FOUNDATION_H }
      )

      expect( @result.types_h_includes.join( "\n" ) ).to include('foundation.h')
    end
  end

  # ---------------------------------------------------------------------------
  context 'a types header alongside transitive re-inclusion' do
  # ---------------------------------------------------------------------------

    # Issue #1293. A later header reaches the real module header, which would declare the
    # same type a second time. The generated header's guard-spoofing #define has to land
    # first for that to be suppressed.
    it 'compiles when a later header transitively re-includes the real module header' do
      @result = generate_partial(
        module_name: 'alertmanager',
        header: <<~C,
          #ifndef ALERTMANAGER_H
          #define ALERTMANAGER_H
          typedef struct { int severity; } AlertEntry_t;
          #endif
        C
        source: "#include \"alertmanager.h\"\n#include \"facade.h\"\n",
        source_includes: ['alertmanager.h', 'facade.h'],
        extra: {
          'facade.h' => "#ifndef FACADE_H\n#define FACADE_H\n#include \"alertmanager.h\"\n#endif\n"
        }
      )

      compile = compile_partial( @result )
      expect( compile.ok ).to be(true), "expected a clean compile, got: #{compile.first_error}"
    end

    it 'emits the guard-spoofing define before anything it must suppress' do
      @result = generate_partial(
        module_name: 'alertmanager',
        header: "#ifndef ALERTMANAGER_H\n#define ALERTMANAGER_H\ntypedef struct { int severity; } AlertEntry_t;\n#endif\n",
        source: "#include \"alertmanager.h\"\n#include \"facade.h\"\n",
        source_includes: ['alertmanager.h', 'facade.h'],
        extra: { 'facade.h' => "#ifndef FACADE_H\n#define FACADE_H\n#include \"alertmanager.h\"\n#endif\n" }
      )

      body = @result.types_h.to_s
      spoof = body.index( '#define ALERTMANAGER_H' )
      first_include = body.index( '#include' )

      expect( spoof ).not_to be_nil, 'no guard-spoofing define was emitted at all'
      expect( spoof ).to be < (first_include || body.length)
    end

    # Both requirements at once, which is the case neither issue covers alone. The
    # module's types need a foreign header, and a later header re-includes the real
    # module header.
    it 'compiles when it must be both self-contained and early' do
      @result = generate_partial(
        module_name: 'alertmanager',
        header: <<~C,
          #ifndef ALERTMANAGER_H
          #define ALERTMANAGER_H
          typedef struct { S16 level; } AlertEntry_t;
          #endif
        C
        source: "#include \"alertmanager.h\"\n#include \"facade.h\"\n#include \"foundation.h\"\n",
        source_includes: ['alertmanager.h', 'facade.h', 'foundation.h'],
        extra: {
          'foundation.h' => FOUNDATION_H,
          'facade.h' => "#ifndef FACADE_H\n#define FACADE_H\n#include \"alertmanager.h\"\n#endif\n"
        }
      )

      compile = compile_partial( @result )
      expect( compile.ok ).to be(true), "expected a clean compile, got: #{compile.first_error}"
    end
  end

  # ---------------------------------------------------------------------------
  context 'macros the types depend on' do
  # ---------------------------------------------------------------------------

    it 'resolves an array size macro defined in the module header' do
      @result = generate_partial(
        module_name: 'queue',
        header: <<~C,
          #ifndef QUEUE_H
          #define QUEUE_H
          #define QUEUE_CAPACITY (16u)
          typedef struct { int slots[QUEUE_CAPACITY]; } queue_t;
          #endif
        C
        source: "#include \"queue.h\"\n",
        source_includes: ['queue.h']
      )

      compile = compile_partial( @result )
      expect( compile.ok ).to be(true), "expected a clean compile, got: #{compile.first_error}"
    end

    # Preprocessing preserves macro directives rather than expanding invocations, and keeps
    # only the lines belonging to the module. A macro defined in another header therefore
    # survives as an unexpanded name with its #define left behind, which is the same shape
    # as #1319 with a macro in the place of a type.
    it 'resolves an array size macro defined in another header' do
      @result = generate_partial(
        module_name: 'ring',
        header: <<~C,
          #ifndef RING_H
          #define RING_H
          #include "limits_cfg.h"
          typedef struct { int slot[RING_DEPTH]; } ring_t;
          #endif
        C
        source: "#include \"ring.h\"\n",
        header_includes: ['limits_cfg.h'],
        source_includes: ['ring.h'],
        extra: { 'limits_cfg.h' => "#ifndef LIMITS_CFG_H\n#define LIMITS_CFG_H\n#define RING_DEPTH 8\n#endif\n" }
      )

      compile = compile_partial( @result )
      expect( compile.ok ).to be(true), "expected a clean compile, got: #{compile.first_error}"
    end

    # The same gap reached through the module's own header rather than the source, which is
    # where a self-contained module header puts its dependency.
    it 'resolves a type named by a header the module header includes' do
      @result = generate_partial(
        module_name: 'stage',
        header: <<~C,
          #ifndef STAGE_H
          #define STAGE_H
          #include "modes.h"
          typedef struct { stage_mode_t mode; } stage_t;
          #endif
        C
        source: "#include \"stage.h\"\n",
        header_includes: ['modes.h'],
        source_includes: ['stage.h'],
        extra: { 'modes.h' => "#ifndef MODES_H\n#define MODES_H\ntypedef enum { IDLE, RUN } stage_mode_t;\n#endif\n" }
      )

      compile = compile_partial( @result )
      expect( compile.ok ).to be(true), "expected a clean compile, got: #{compile.first_error}"
    end
  end

  # ---------------------------------------------------------------------------
  context 'shapes that already work' do
  # ---------------------------------------------------------------------------

    it 'writes no types header for a module defining no types' do
      @result = generate_partial(
        module_name: 'plain',
        header: "#ifndef PLAIN_H\n#define PLAIN_H\nvoid plain_go(void);\n#endif\n",
        source: "#include \"plain.h\"\nstatic int helper(void) { return 1; }\n",
        source_includes: ['plain.h']
      )

      expect( @result.types_h ).to be_nil
    end

    it 'compiles a type that depends on nothing outside the module' do
      @result = generate_partial(
        module_name: 'standalone',
        header: "#ifndef STANDALONE_H\n#define STANDALONE_H\ntypedef struct { int a; } standalone_t;\n#endif\n",
        source: "#include \"standalone.h\"\n",
        source_includes: ['standalone.h']
      )

      compile = compile_partial( @result )
      expect( compile.ok ).to be(true), "expected a clean compile, got: #{compile.first_error}"
    end

    it 'compiles a non-typedef aggregate definition' do
      @result = generate_partial(
        module_name: 'tagged',
        header: "#ifndef TAGGED_H\n#define TAGGED_H\nstruct tagged { int a; };\n#endif\n",
        source: "#include \"tagged.h\"\n",
        source_includes: ['tagged.h']
      )

      compile = compile_partial( @result )
      expect( compile.ok ).to be(true), "expected a clean compile, got: #{compile.first_error}"
    end

    it 'replaces the module header rather than leaving both' do
      @result = generate_partial(
        module_name: 'widget',
        header: "#ifndef WIDGET_H\n#define WIDGET_H\ntypedef struct { int a; } widget_t;\n#endif\n",
        source: "#include \"base.h\"\n#include \"widget.h\"\n",
        source_includes: ['base.h', 'widget.h'],
        extra: { 'base.h' => "#ifndef BASE_H\n#define BASE_H\n#endif\n" }
      )

      expect( @result.impl_h_includes.join( "\n" ) ).not_to include('"widget.h"')
      expect( @result.impl_h_index( 'ceedling_partial_widget_types.h' ) ).not_to be_nil
    end

    # Preprocessing settles a conditional before extraction sees anything, so only the
    # selected arm reaches the types header. Kept so that stays true.
    it 'carries only the selected arm of a conditionally defined type' do
      @result = generate_partial(
        module_name: 'cond',
        header: "#ifndef COND_H\n#define COND_H\n#if USE_WIDE\ntypedef unsigned long counter_t;\n#else\ntypedef unsigned char counter_t;\n#endif\n#endif\n",
        source: "#include \"cond.h\"\nstatic counter_t count;\n",
        source_includes: ['cond.h']
      )

      expect( @result.types_h.to_s ).to include('typedef unsigned char counter_t;')
      expect( @result.types_h.to_s ).not_to include('unsigned long')
    end
  end

  # ---------------------------------------------------------------------------
  context 'the mockable interface header' do
  # ---------------------------------------------------------------------------

    # CMock mocks the generated interface header in place of the real module header, so that
    # file carries the same extracted types the implementation header does. A module tested
    # and mocked in one test file puts both in a single translation unit, which is the whole
    # reason the types live in a third file.

    it 'carries the types header at the module header-s own list position' do
      @result = generate_partial(
        module_name: 'valve',
        header: "#ifndef VALVE_H\n#define VALVE_H\ntypedef struct { int port; } valve_t;\n#endif\n",
        source: "#include \"base.h\"\n#include \"valve.h\"\n#include \"trailer.h\"\n",
        source_includes: ['base.h', 'valve.h', 'trailer.h'],
        extra: {
          'base.h' => "#ifndef BASE_H\n#define BASE_H\n#endif\n",
          'trailer.h' => "#ifndef TRAILER_H\n#define TRAILER_H\n#endif\n"
        }
      )

      expect( @result.interface_h_index( 'base.h' ) ).to eq(0)
      expect( @result.interface_h_index( 'ceedling_partial_valve_types.h' ) ).to eq(1)
      expect( @result.interface_h_index( 'trailer.h' ) ).to eq(2)
    end

    it 'omits the module-s own header' do
      @result = generate_partial(
        module_name: 'valve',
        header: "#ifndef VALVE_H\n#define VALVE_H\ntypedef struct { int port; } valve_t;\n#endif\n",
        source: "#include \"valve.h\"\n",
        source_includes: ['valve.h']
      )

      expect( @result.interface_h_includes.join( "\n" ) ).not_to include('"valve.h"')
    end

    # The interface header declares; it must not define. A type definition reaching it would
    # be the second copy in the translation unit the implementation header already serves.
    it 'declares functions without restating the extracted types' do
      @result = generate_partial(
        module_name: 'valve',
        header: <<~C,
          #ifndef VALVE_H
          #define VALVE_H
          typedef struct { int port; } valve_t;
          void valve_open(valve_t* v);
          #endif
        C
        source: "#include \"valve.h\"\nvoid valve_open(valve_t* v) { (void)v; }\n",
        source_includes: ['valve.h']
      )

      expect( @result.interface_h ).to include('void valve_open(valve_t* v);')
      expect( @result.type_names( :interface_h ) ).not_to include('valve_t')
      expect( @result.type_names( :types_h ) ).to include('valve_t')
    end

    it 'defines each extracted type once across both generated headers' do
      @result = generate_partial(
        module_name: 'valve',
        header: <<~C,
          #ifndef VALVE_H
          #define VALVE_H
          typedef struct { int port; } valve_t;
          void valve_open(valve_t* v);
          #endif
        C
        source: "#include \"valve.h\"\nvoid valve_open(valve_t* v) { (void)v; }\n",
        source_includes: ['valve.h']
      )

      compile = compile_both_headers( @result )
      expect( compile.ok ).to be(true), "expected a clean compile, got: #{compile.first_error}"
    end
  end

  # ---------------------------------------------------------------------------
  context 'names that resemble other names' do
  # ---------------------------------------------------------------------------

    # Matching a module to an include, or a guard to a macro, means comparing names. GH #1266
    # was exactly this going wrong: a macro whose name merely contained the include guard as a
    # substring was wrongly rejected. These cases hold the line on each comparison that
    # Partial generation performs.

    it 'replaces only the module-s own header, not a header whose name extends it' do
      @result = generate_partial(
        module_name: 'foo',
        header: "#ifndef FOO_H\n#define FOO_H\ntypedef int foo_t;\n#endif\n",
        source: "#include \"foobar.h\"\n#include \"foo.h\"\n#include \"myfoo.h\"\n",
        source_includes: ['foobar.h', 'foo.h', 'myfoo.h'],
        extra: {
          'foobar.h' => "#ifndef FOOBAR_H\n#define FOOBAR_H\n#endif\n",
          'myfoo.h' => "#ifndef MYFOO_H\n#define MYFOO_H\n#endif\n"
        }
      )

      includes = @result.impl_h_includes.join( "\n" )
      expect( includes ).to include('"foobar.h"')
      expect( includes ).to include('"myfoo.h"')
      expect( includes ).not_to include('"foo.h"')
      expect( @result.impl_h_index( 'ceedling_partial_foo_types.h' ) ).to eq(1)
    end

    it 'drops another partialized module without touching a near-named header' do
      @result = generate_partial(
        module_name: 'foo',
        header: "#ifndef FOO_H\n#define FOO_H\ntypedef int foo_t;\n#endif\n",
        source: "#include \"foo.h\"\n#include \"bar.h\"\n#include \"barn.h\"\n",
        source_includes: ['foo.h', 'bar.h', 'barn.h'],
        partials: other_partial( 'bar' ),
        extra: {
          'bar.h' => "#ifndef BAR_H\n#define BAR_H\n#endif\n",
          'barn.h' => "#ifndef BARN_H\n#define BARN_H\n#endif\n"
        }
      )

      includes = @result.impl_h_includes.join( "\n" )
      expect( includes ).not_to include('"bar.h"')
      expect( includes ).to include('"barn.h"')
    end

    it 'carries a macro whose name extends the include guard' do
      @result = generate_partial(
        module_name: 'gated',
        header: <<~C,
          #ifndef GATED_H
          #define GATED_H
          #define GATED_H_LIMIT 8
          typedef struct { int slots[GATED_H_LIMIT]; } gated_t;
          #endif
        C
        source: "#include \"gated.h\"\n",
        source_includes: ['gated.h']
      )

      expect( @result.defines( :types_h ) ).to include('GATED_H_LIMIT')

      compile = compile_partial( @result )
      expect( compile.ok ).to be(true), "expected a clean compile, got: #{compile.first_error}"
    end

    it 'keeps two types whose names share a prefix' do
      @result = generate_partial(
        module_name: 'kin',
        header: <<~C,
          #ifndef KIN_H
          #define KIN_H
          typedef int kin_t;
          typedef struct { kin_t id; } kin_type_t;
          typedef struct { kin_type_t inner; } kin_type_wrapper_t;
          #endif
        C
        source: "#include \"kin.h\"\n",
        source_includes: ['kin.h']
      )

      expect( @result.type_names( :types_h ) ).to include('kin_t', 'kin_type_t', 'kin_type_wrapper_t')

      compile = compile_partial( @result )
      expect( compile.ok ).to be(true), "expected a clean compile, got: #{compile.first_error}"
    end
  end

  # ---------------------------------------------------------------------------
  context 'a system header among the includes' do
  # ---------------------------------------------------------------------------

    # The first reporter's list opens with <string.h>, and the types header landed
    # immediately after it. Kept as its own case because a system header is the one
    # include that can never supply a project type.
    it 'compiles with a system header ahead of the module header' do
      @result = generate_partial(
        module_name: 'lm75b',
        header: "#ifndef LM75B_H\n#define LM75B_H\ntypedef struct { U8 pin; } lm75b_t;\n#endif\n",
        source: "#include <string.h>\n#include \"lm75b.h\"\n#include \"foundation.h\"\n",
        source_includes: ['<string.h>', 'lm75b.h', 'foundation.h'],
        extra: { 'foundation.h' => FOUNDATION_H }
      )

      compile = compile_partial( @result )
      expect( compile.ok ).to be(true), "expected a clean compile, got: #{compile.first_error}"
    end
  end

  # ---------------------------------------------------------------------------
  context 'C shapes the extraction model does not yet carry' do
  # ---------------------------------------------------------------------------

    # Neither reported issue covers these, and none involves include ordering. Each survives
    # preprocessing, so each is extraction's own to answer. They share an origin with #1319
    # all the same: content is moved out of a module into generated files, and what travels
    # with it is decided by category rather than by what the relocated code actually needs.
    #
    # Each is marked pending against its own follow-on work. RSpec fails an example that
    # passes while pending, so every one of these is a live tripwire: the day extraction
    # learns the shape, the suite says so rather than staying quiet.

    # Preprocessing for Partials preserves macro directives rather than expanding them, so an
    # invocation reaches extraction intact. A bare invocation is then routed to the generated
    # source alone, since it may expand to a function definition that must exist in exactly
    # one object. A macro that expands to a typedef needs the opposite treatment, and the
    # container-generating macros in sys/queue.h and in hand-rolled X-macro tables are
    # exactly that shape.
    it 'declares a type created by a macro invocation' do
      pending 'a macro expanding to a typedef needs expansion to recognize -- follow-on work'

      @result = generate_partial(
        module_name: 'roster',
        header: "#ifndef ROSTER_H\n#define ROSTER_H\n#define DECLARE_LIST(T) typedef struct { T* head; } T##_list_t;\nDECLARE_LIST(int)\n#endif\n",
        source: "#include \"roster.h\"\nstatic int_list_t active;\n",
        source_includes: ['roster.h']
      )

      compile = compile_partial( @result )
      expect( compile.ok ).to be(true), "expected a clean compile, got: #{compile.first_error}"
    end

    # An aggregate carrying a declarator is not a standalone type definition, so it reaches
    # the variable extractor whole. Re-emitting it as both an extern and a definition states
    # an anonymous struct twice, and C treats two anonymous structs as unrelated types.
    it 'keeps one type for an aggregate defined inline on a variable' do
      pending 'an aggregate carrying a declarator is classified as a variable -- follow-on work'

      @result = generate_partial(
        module_name: 'slotted',
        header: "#ifndef SLOTTED_H\n#define SLOTTED_H\n#endif\n",
        source: "#include \"slotted.h\"\nstatic struct { int depth; } slot;\n",
        source_includes: ['slotted.h']
      )

      compile = compile_partial( @result, prelude: "#include \"ceedling_partial_slotted_impl.c\"\n" )
      expect( compile.ok ).to be(true), "expected a clean compile, got: #{compile.first_error}"
    end

    # A tag-only forward declaration has no declarator, and reaching the variable extractor
    # turns it into `extern struct node;`. That is an empty declaration with a storage class,
    # which is a diagnostic in its own right and an error under -Werror.
    it 'preserves a forward declaration as a forward declaration' do
      pending 'a tag-only forward declaration is classified as a variable -- follow-on work'

      @result = generate_partial(
        module_name: 'fwd',
        header: "#ifndef FWD_H\n#define FWD_H\nstruct node;\ntypedef struct node* node_ref_t;\n#endif\n",
        source: "#include \"fwd.h\"\nstruct node { int value; };\nstatic node_ref_t head;\n",
        source_includes: ['fwd.h']
      )

      expect( @result.impl_h.to_s ).not_to include('extern struct node;')
    end

    # Directives-only preprocessing passes both #define and #undef through, and extraction
    # keeps only #define. A macro the module deliberately scoped to a few lines therefore
    # becomes visible everywhere the generated headers reach, the test file included.
    it 'does not leak a macro the module undefines' do
      pending 'extraction keeps #define and discards #undef -- follow-on work'

      @result = generate_partial(
        module_name: 'scoped',
        header: "#ifndef SCOPED_H\n#define SCOPED_H\n#define DEPTH 4\ntypedef int window_t[DEPTH];\n#undef DEPTH\n#endif\n",
        source: "#include \"scoped.h\"\nstatic window_t recent;\n",
        source_includes: ['scoped.h']
      )

      expect( @result.types_h.to_s ).not_to include('#define DEPTH')
      expect( @result.impl_h.to_s ).not_to include('#define DEPTH')
    end

    # The guard-spoof is the real header's own #define, which survives preprocessing and is
    # carried only because it precedes the first type definition. A header guarded by
    # #pragma once contributes no #define at all -- the pragma does not survive reconstitution
    # either -- so the only macro available to carry is the synthetic guard on the
    # reconstituted file, which suppresses nothing real. #1293's duplicates return.
    it 'suppresses a real header guarded by #pragma once' do
      pending '#pragma once offers no macro to spoof -- its own follow-on PR'

      @result = generate_partial(
        module_name: 'onced',
        header: "#pragma once\ntypedef struct { int x; } onced_t;\n",
        source: "#include \"onced.h\"\nstatic onced_t state;\n",
        source_includes: ['onced.h']
      )

      compile = compile_partial( @result, prelude: "#include \"onced.h\"\n" )
      expect( compile.ok ).to be(true), "expected a clean compile, got: #{compile.first_error}"
    end
  end

end
