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
  context 'two partialized modules sharing a file-scope name' do
  # ---------------------------------------------------------------------------

    # Characterization, not a requirement. Exposing file-scope data is the point of Partials,
    # and the consequence is that a name chosen to be module-private now participates in
    # link-time resolution. Two modules that each keep a `static int shared_count` therefore
    # collide once both are partialized. This case pins that behavior so a future change to
    # it is deliberate rather than silent.
    it 'collides at link time, which is the behavior today' do
      @dir = shared_partials_dir

      alpha = generate_partial(
        module_name: 'alpha', dir: @dir,
        header: "#ifndef ALPHA_H\n#define ALPHA_H\n#endif\n",
        source: "#include \"alpha.h\"\nstatic int shared_count;\n",
        source_includes: ['alpha.h']
      )
      beta = generate_partial(
        module_name: 'beta', dir: @dir,
        header: "#ifndef BETA_H\n#define BETA_H\n#endif\n",
        source: "#include \"beta.h\"\nstatic int shared_count;\n",
        source_includes: ['beta.h']
      )

      link = link_partials( [alpha, beta], references: ['shared_count'] )

      expect( link.ok ).to be(false)
      expect( link.stderr ).to match(/multiple definition/)
    end
  end

end
