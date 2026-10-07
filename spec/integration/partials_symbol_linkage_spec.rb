# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Whether a Partial's mutated symbols survive to the link, and with the linkage intended.
#
# Partials exists to reach inside a module, and it does that by removing the very thing that
# kept a name private. A file-scope `static` loses its storage class; a function-scoped
# `static` is renamed and promoted to module scope; a `static` function has `static` stripped
# from its signature. Every one of those changes what the linker sees, and none of it is
# observable from a syntax-only compile -- a declaration that compiles is not proof a
# definition survived relocation.
#
# So these cases compile real object files and link them against a stand-in translation unit
# that takes the address of each symbol, forcing the linker to resolve it. `undefined
# reference to` and `multiple definition of` are the two diagnostics this file exists to
# provoke or to rule out.
#
# Accurate preprocessing is assumed throughout; what fallback cannot resolve belongs to
# partials_fallback_preprocessing_spec.rb.

require 'spec_helper'
require 'spec_integration_helper'
require 'partials_generation_integration_helper'

describe 'Partial symbol linkage' do

  include_context 'requires gcc'
  before { skip 'directives-only preprocessing is unavailable' unless directives_only_supported? }

  after(:each) { cleanup_dir( @dir ) }

  # ---------------------------------------------------------------------------
  context 'a function the Partial exposes' do
  # ---------------------------------------------------------------------------

    it 'links a static function whose storage class was stripped' do
      result = generate_partial(
        module_name: 'engine',
        header: "#ifndef ENGINE_H\n#define ENGINE_H\n#endif\n",
        source: "#include \"engine.h\"\nstatic int engine_step(int v) { return v + 1; }\n",
        source_includes: ['engine.h']
      )
      @dir = result.dir

      expect( result.impl_h ).to include('int engine_step(int v);')
      expect( result.impl_h ).not_to include('static int engine_step')

      link = link_partial( result, references: ['engine_step'] )
      expect( link.ok ).to be(true), "expected a clean link, got: #{link.first_diagnostic}"
    end

    # An inline function carries no external definition of its own in C99, so exposing one
    # has to produce a definition the linker can find rather than only a declaration.
    it 'links an inline function the Partial exposes' do
      result = generate_partial(
        module_name: 'scaler',
        header: "#ifndef SCALER_H\n#define SCALER_H\n#endif\n",
        source: "#include \"scaler.h\"\nstatic inline int scaler_twice(int v) { return v * 2; }\n",
        source_includes: ['scaler.h']
      )
      @dir = result.dir

      link = link_partial( result, references: ['scaler_twice'] )
      expect( link.ok ).to be(true), "expected a clean link, got: #{link.first_diagnostic}"
    end
  end

  # ---------------------------------------------------------------------------
  context 'a file-scope variable the Partial exposes' do
  # ---------------------------------------------------------------------------

    it 'links a stripped static from a separate object' do
      result = generate_partial(
        module_name: 'ticker',
        header: "#ifndef TICKER_H\n#define TICKER_H\n#endif\n",
        source: "#include \"ticker.h\"\nstatic int tick_count;\n",
        source_includes: ['ticker.h']
      )
      @dir = result.dir

      expect( result.impl_h ).to include('extern int tick_count;')
      expect( result.impl_c ).to include('int tick_count;')
      expect( result.impl_c ).not_to include('static int tick_count;')

      expect( compile_objects( result ).ok ).to be(true)

      link = link_partial( result, references: ['tick_count'] )
      expect( link.ok ).to be(true), "expected a clean link, got: #{link.first_diagnostic}"
    end

    # The extern and the definition must agree on the whole type, qualifiers included. A
    # disagreement is a compile error in the one translation unit holding both, which is
    # exactly the unit the generated source becomes.
    it 'keeps qualifiers on both the extern and the definition' do
      result = generate_partial(
        module_name: 'regs',
        header: "#ifndef REGS_H\n#define REGS_H\n#endif\n",
        source: "#include \"regs.h\"\nstatic volatile int regs_flag;\nstatic const int regs_limit = 7;\n",
        source_includes: ['regs.h']
      )
      @dir = result.dir

      expect( result.impl_h ).to include('extern volatile int regs_flag;')
      expect( result.impl_h ).to include('extern const int regs_limit;')

      link = link_partial( result, references: ['regs_flag', 'regs_limit'] )
      expect( link.ok ).to be(true), "expected a clean link, got: #{link.first_diagnostic}"
    end

    it 'links an exposed array with its dimension intact' do
      result = generate_partial(
        module_name: 'window',
        header: "#ifndef WINDOW_H\n#define WINDOW_H\n#define DEPTH 4\n#endif\n",
        source: "#include \"window.h\"\nstatic int window_samples[DEPTH];\n",
        source_includes: ['window.h']
      )
      @dir = result.dir

      expect( result.impl_h ).to include('extern int window_samples[DEPTH];')

      link = link_partial( result, references: ['window_samples'] )
      expect( link.ok ).to be(true), "expected a clean link, got: #{link.first_diagnostic}"
    end
  end

  # ---------------------------------------------------------------------------
  context 'a function-scoped static the Partial promotes' do
  # ---------------------------------------------------------------------------

    it 'links the promoted variable under its generated name' do
      result = generate_partial(
        module_name: 'counter',
        header: "#ifndef COUNTER_H\n#define COUNTER_H\n#endif\n",
        source: "#include \"counter.h\"\nint counter_next(void) { static int calls; calls++; return calls; }\n",
        source_includes: ['counter.h']
      )
      @dir = result.dir

      expect( result.impl_h ).to include('extern int partial_counter_next_calls;')
      expect( result.impl_c ).to include('int partial_counter_next_calls;')

      link = link_partial( result, references: ['counter_next', 'partial_counter_next_calls'] )
      expect( link.ok ).to be(true), "expected a clean link, got: #{link.first_diagnostic}"
    end

    # The generated name is qualified by the function it came from, so two functions in one
    # module may each keep a static of the same spelling without colliding.
    it 'keeps two same-named statics distinct across two functions' do
      result = generate_partial(
        module_name: 'dual',
        header: "#ifndef DUAL_H\n#define DUAL_H\n#endif\n",
        source: <<~C,
          #include "dual.h"
          int dual_first(void) { static int calls; calls++; return calls; }
          int dual_second(void) { static int calls; calls++; return calls; }
        C
        source_includes: ['dual.h']
      )
      @dir = result.dir

      link = link_partial(
        result,
        references: ['partial_dual_first_calls', 'partial_dual_second_calls']
      )
      expect( link.ok ).to be(true), "expected a clean link, got: #{link.first_diagnostic}"
    end
  end

  # ---------------------------------------------------------------------------
  context 'a module both tested and mocked in one test file' do
  # ---------------------------------------------------------------------------

    # The implementation header arrives directly and the interface header arrives the way
    # CMock's generated mock brings it, so both land in one translation unit. Defining each
    # type once is a compile claim; exposing each symbol once is a link claim.
    it 'compiles and links with one definition of each exposed symbol' do
      result = generate_partial(
        module_name: 'relay',
        header: <<~C,
          #ifndef RELAY_H
          #define RELAY_H
          typedef struct { int pin; } relay_cfg_t;
          void relay_open(void);
          #endif
        C
        source: "#include \"relay.h\"\nvoid relay_open(void) {}\nstatic int relay_state;\n",
        source_includes: ['relay.h']
      )
      @dir = result.dir

      compile = compile_both_headers( result )
      expect( compile.ok ).to be(true), "expected a clean compile, got: #{compile.first_error}"

      expect( result.type_names( :types_h ) ).to include('relay_cfg_t')
      expect( result.type_names( :impl_h ) ).not_to include('relay_cfg_t')
      expect( result.type_names( :interface_h ) ).not_to include('relay_cfg_t')

      link = link_partial( result, references: ['relay_open', 'relay_state'] )
      expect( link.ok ).to be(true), "expected a clean link, got: #{link.first_diagnostic}"
    end
  end

  # ---------------------------------------------------------------------------
  context 'a module tested at one visibility and mocked at another' do
  # ---------------------------------------------------------------------------

    # The common real-world pairing: TEST_PARTIAL_PUBLIC_MODULE beside
    # MOCK_PARTIAL_PRIVATE_MODULE, which tests a module's public surface while mocking the
    # private helpers that surface calls. It splits one module's own content across two
    # generated files, and that split is the shape a single-visibility case cannot reach.
    #
    # wondrous_forest's ForestMonitor is exactly this, and a refactor that dropped the module's
    # own interface header from its generated source left a private function undeclared at
    # compile time with nothing below the system tier to catch it.

    # A module's own config is part of the partials hash the remaps receive, which is what tells
    # the source remap to carry this module's interface header alongside its implementation.
    it 'carries its own interface header in its generated source' do
      @result = generate_partial( **split_visibility_module )
      @dir = @result.dir

      expect( @result.source_include_list.join( "\n" ) )
        .to include('ceedling_partial_gauge_impl.h')
      expect( @result.source_include_list.join( "\n" ) )
        .to include('ceedling_partial_gauge_interface.h')
    end

    # The interface header includes the types header, so carrying the interface back into the
    # types header would fold its declarations into that file instead.
    it 'never carries its own interface header into the types header' do
      @result = generate_partial( **split_visibility_module )
      @dir = @result.dir

      expect( @result.types_h_includes.join( "\n" ) )
        .not_to include('ceedling_partial_gauge_interface.h')
    end

    it 'declares the public functions in the implementation header and the private ones in the interface' do
      @result = generate_partial( **split_visibility_module )
      @dir = @result.dir

      expect( @result.impl_h ).to include('int gauge_read(void);')
      expect( @result.impl_h ).not_to include('gauge_scale')

      expect( @result.interface_h ).to include('int gauge_scale(int raw);')
      expect( @result.interface_h ).not_to include('gauge_read')
    end

    # The failure mode the regression produced: a public body calls a private helper declared
    # only in the interface header, so the generated source compiles only if it reaches both.
    it 'compiles a public body that calls a private helper' do
      @result = generate_partial( **split_visibility_module )
      @dir = @result.dir

      compile = compile_objects( @result )
      expect( compile.ok ).to be(true), "expected a clean compile, got: #{compile.first_error}"
      expect( compile.stderr ).not_to match(/implicit declaration/)
    end

    it 'links the public surface, with the private helper left for a mock to satisfy' do
      @result = generate_partial( **split_visibility_module )
      @dir = @result.dir

      # gauge_scale is deliberately absent: a mocked private function is satisfied by CMock's
      # generated definition in a real build, so the Partial must not also define it.
      expect( @result.impl_c ).not_to include('int gauge_scale(int raw)')

      link = link_partials( [@result], references: ['gauge_read'] )
      expect( link.ok ).to be(false)
      # Linkers disagree on the wording -- GNU ld reports an undefined reference, Apple's
      # reports undefined symbols for an architecture -- but both name the symbol.
      expect( link.stderr ).to include('gauge_scale')
    end

    # The whole chain at once: split visibility, a carried type dependency, and exposed
    # file-scope data.
    it 'resolves a carried type dependency across the split' do
      @result = generate_partial(
        tests_expose: Partials::PUBLIC,
        mocks_expose: Partials::PRIVATE,
        module_name: 'gauge',
        header: <<~C,
          #ifndef GAUGE_H
          #define GAUGE_H
          #include "units.h"
          typedef struct { Celsius limit; } gauge_cfg_t;
          int gauge_read(void);
          #endif
        C
        source: <<~C,
          #include "gauge.h"
          static gauge_cfg_t config = { 0 };
          static int gauge_scale(int raw) { return raw; }
          int gauge_read(void) { return gauge_scale(config.limit); }
        C
        header_includes: ['units.h'],
        source_includes: ['gauge.h'],
        extra: { 'units.h' => "#ifndef UNITS_H\n#define UNITS_H\ntypedef signed short Celsius;\n#endif\n" }
      )
      @dir = @result.dir

      expect( @result.type_names( :types_h ) ).to include('gauge_cfg_t')
      expect( @result.types_h_includes.join( "\n" ) ).to include('units.h')
      expect( @result.impl_h ).to include('extern gauge_cfg_t config;')

      standalone = compile_types_header_alone( @result )
      expect( standalone.ok ).to be(true), "expected the types header to stand alone, got: #{standalone.first_error}"

      compile = compile_objects( @result )
      expect( compile.ok ).to be(true), "expected a clean compile, got: #{compile.first_error}"
    end
  end

  # A module whose public function calls a private helper, tested publicly and mocked privately.
  def split_visibility_module
    {
      tests_expose: Partials::PUBLIC,
      mocks_expose: Partials::PRIVATE,
      module_name: 'gauge',
      header: "#ifndef GAUGE_H\n#define GAUGE_H\nint gauge_read(void);\n#endif\n",
      source: <<~C,
        #include "gauge.h"
        static int reading = 7;
        static int gauge_scale(int raw) { return raw * 2; }
        int gauge_read(void) { return gauge_scale(reading); }
      C
      source_includes: ['gauge.h']
    }
  end

  # ---------------------------------------------------------------------------
  context 'two partialized modules sharing a file-scope name' do
  # ---------------------------------------------------------------------------

    # Characterization, not a requirement. Exposing file-scope data is the point of Partials,
    # and the consequence is that a name chosen to be module-private now participates in
    # link-time resolution. Two modules that each keep a `shared_count` therefore collide once
    # both are partialized. This case pins that behavior so a future change to it is deliberate
    # rather than silent.
    #
    # Both definitions are initialized on purpose. An uninitialized file-scope variable is a
    # tentative definition, which some toolchains still merge as a common symbol rather than
    # rejecting -- the collision would then appear on one platform and not another. An
    # initialized definition is a strong symbol everywhere, so the collision is the fixture's
    # property rather than the linker's.
    it 'collides at link time, which is the behavior today' do
      @dir = shared_partials_dir

      alpha = generate_partial(
        module_name: 'alpha', dir: @dir,
        header: "#ifndef ALPHA_H\n#define ALPHA_H\n#endif\n",
        source: "#include \"alpha.h\"\nstatic int shared_count = 1;\n",
        source_includes: ['alpha.h']
      )
      beta = generate_partial(
        module_name: 'beta', dir: @dir,
        header: "#ifndef BETA_H\n#define BETA_H\n#endif\n",
        source: "#include \"beta.h\"\nstatic int shared_count = 2;\n",
        source_includes: ['beta.h']
      )

      link = link_partials( [alpha, beta], references: ['shared_count'] )

      expect( link.ok ).to be(false)
      # GNU ld reports a multiple definition, Apple's a duplicate symbol. Both name it.
      expect( link.stderr ).to include('shared_count')
    end
  end

end
