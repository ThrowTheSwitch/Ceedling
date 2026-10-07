# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Partial generation when no C preprocessor resolved the module first.
#
# Ceedling falls back to a text scan whenever the accurate `-fdirectives-only` pass is
# unavailable -- Apple Clang ignores the flag, and any single invocation can fail. Fallback is
# therefore a real production path, not a degraded mode reserved for broken toolchains, and it
# resolves strictly less: `CPreprocessorConditionals` evaluates a few directive shapes against
# a defines list and treats anything it cannot evaluate as active.
#
# Every case here forces `mode: :fallback` by parameter rather than waiting for a toolchain
# that cannot do better, so this coverage runs on every platform. That matters because the
# shapes fallback mishandles are invisible on a machine where the accurate pass always wins.
#
# What fallback resolves correctly is the subject below. What it cannot resolve is the subject
# of the insufficiency cases, which Ceedling must refuse rather than guess at.

require 'spec_helper'
require 'spec_integration_helper'
require 'partials_generation_integration_helper'

describe 'Partial fallback preprocessing' do

  include_context 'requires gcc'

  after(:each) { cleanup_partial( @result ) }

  # ---------------------------------------------------------------------------
  context 'content the text scan carries' do
  # ---------------------------------------------------------------------------

    # Fallback strips every directive line out of the content it collects, so a macro a type
    # depends on would vanish. A second pass recovers macros and pragmas and reinserts them,
    # which is what keeps an array bound visible when no compiler ran.
    it 'carries a macro the extracted type depends on' do
      @result = generate_partial(
        mode: :fallback,
        module_name: 'window',
        header: <<~C,
          #ifndef WINDOW_H
          #define WINDOW_H
          #define DEPTH 4
          typedef struct { int samples[DEPTH]; } window_t;
          #endif
        C
        source: "#include \"window.h\"\n",
        source_includes: ['window.h']
      )

      expect( @result.defines( :types_h ) ).to include('DEPTH')
      expect( @result.type_names( :types_h ) ).to include('window_t')
      expect( @result.define_index( :types_h, 'DEPTH' ) ).to be < @result.line_index( :types_h, /typedef/ )

      compile = compile_partial( @result )
      expect( compile.ok ).to be(true), "expected a clean compile, got: #{compile.first_error}"
    end

    it 'extracts types from the source file as well as the header' do
      @result = generate_partial(
        mode: :fallback,
        module_name: 'split',
        header: "#ifndef SPLIT_H\n#define SPLIT_H\ntypedef int split_id_t;\n#endif\n",
        source: "#include \"split.h\"\ntypedef struct { split_id_t id; } split_rec_t;\n",
        source_includes: ['split.h']
      )

      expect( @result.type_names( :types_h ) ).to include('split_id_t', 'split_rec_t')
    end

    it 'exposes functions and file-scope data the same way the accurate path does' do
      @result = generate_partial(
        mode: :fallback,
        module_name: 'pump',
        header: "#ifndef PUMP_H\n#define PUMP_H\n#endif\n",
        source: "#include \"pump.h\"\nstatic int pump_rate;\nstatic int pump_step(void) { return pump_rate; }\n",
        source_includes: ['pump.h']
      )

      expect( @result.impl_h ).to include('extern int pump_rate;')
      expect( @result.impl_h ).to include('int pump_step(void);')

      link = link_partial( @result, references: ['pump_rate', 'pump_step'] )
      expect( link.ok ).to be(true), "expected a clean link, got: #{link.first_diagnostic}"
    end
  end

  # ---------------------------------------------------------------------------
  context 'conditionals the text scan evaluates' do
  # ---------------------------------------------------------------------------

    # These are the shapes CPreprocessorConditionals genuinely decides, and it reaches the
    # same answer a real preprocessor would. Each case pins one of them.
    it 'selects the else arm when an #ifdef macro is not defined' do
      @result = generate_partial( mode: :fallback, **conditional_module )

      expect( @result.type_names( :types_h ) ).to eq(['feat_t'])
      expect( @result.types_h ).to include('typedef char feat_t;')
      expect( @result.types_h ).not_to include('long')
    end

    it 'selects the if arm when the macro is defined' do
      @result = generate_partial( mode: :fallback, defines: ['USE_WIDE'], **conditional_module )

      expect( @result.types_h ).to include('typedef long feat_t;')
      expect( @result.types_h ).not_to include('char')
    end

    it 'drops a block behind #if 0' do
      @result = generate_partial(
        mode: :fallback,
        module_name: 'disabled',
        header: <<~C,
          #ifndef DISABLED_H
          #define DISABLED_H
          #if 0
          typedef long dead_t;
          #endif
          typedef char live_t;
          #endif
        C
        source: "#include \"disabled.h\"\n",
        source_includes: ['disabled.h']
      )

      expect( @result.type_names( :types_h ) ).to eq(['live_t'])
    end

    it 'resolves a single defined() test' do
      @result = generate_partial(
        mode: :fallback,
        module_name: 'probed',
        defines: ['HAVE_WIDE'],
        header: <<~C,
          #ifndef PROBED_H
          #define PROBED_H
          #if defined(HAVE_WIDE)
          typedef long probed_t;
          #else
          typedef char probed_t;
          #endif
          #endif
        C
        source: "#include \"probed.h\"\n",
        source_includes: ['probed.h']
      )

      expect( @result.types_h ).to include('typedef long probed_t;')
    end

    # Only one arm ever reaches the types header. A tracker that let both through would
    # produce two definitions of one type, which is a compile error rather than a wrong
    # answer, so this is worth stating separately from the arm-selection cases above.
    it 'never carries both arms of one conditional' do
      @result = generate_partial( mode: :fallback, **conditional_module )

      expect( @result.type_names( :types_h ).length ).to eq(1)

      compile = compile_partial( @result )
      expect( compile.ok ).to be(true), "expected a clean compile, got: #{compile.first_error}"
    end
  end

  # ---------------------------------------------------------------------------
  context 'limits the text scan cannot overcome' do
  # ---------------------------------------------------------------------------

    # Two shapes are knowably beyond fallback, and generating from a guess leaves a compiler or
    # a linker to report something arcane several stages later. Ceedling refuses instead, naming
    # the module and the directive, and refuses before writing anything.

    # Resolving an #include whose target is a macro needs a real preprocessor to expand it.
    # Fallback has no expansion at all, so the include is simply lost and whatever it declared
    # is missing from the carried dependency list.
    it 'refuses a module whose header computes an include' do
      expect {
        @result = generate_partial( mode: :fallback, **computed_include_module )
      }.to raise_error( CeedlingException, /computes an #include target/ )
    end

    it 'refuses before writing any generated file' do
      dir = shared_partials_dir

      expect {
        generate_partial( mode: :fallback, dir: dir, **computed_include_module )
      }.to raise_error( CeedlingException )

      expect( Dir[File.join( dir, 'ceedling_partial_*' )] ).to be_empty

      cleanup_dir( dir )
    end

    # A compound condition is beyond the tracker, which keeps the block rather than dropping it.
    # That is the safe default for an unrelated block and the wrong answer for one that decides
    # which type exists: the types header would carry a type the build should not have.
    it 'refuses a module whose type sits behind a condition it cannot evaluate' do
      expect {
        @result = generate_partial( mode: :fallback, **unevaluable_type_module )
      }.to raise_error( CeedlingException, /fallback preprocessing cannot evaluate/ )
    end

    # The accurate path resolves both shapes, so neither is an error there. A check that fired
    # regardless would turn a working project into a broken one.
    it 'accepts a computed include under accurate preprocessing' do
      @result = generate_partial( **computed_include_module )

      expect( @result.types_h ).to include('typedef')
    end

    it 'accepts an unevaluable condition under accurate preprocessing' do
      @result = generate_partial( **unevaluable_type_module )

      expect( @result.type_names( :types_h ) ).to eq(['narrow_t'])
    end

    # A compound condition that decides nothing the Partial relocates is not a reason to refuse.
    # Scoping the check to conditionals actually enclosing a type or an include is what keeps it
    # from firing on ordinary code.
    it 'accepts an unevaluable condition that encloses nothing it relocates' do
      @result = generate_partial(
        mode: :fallback,
        module_name: 'benign',
        header: "#ifndef BENIGN_H\n#define BENIGN_H\ntypedef int benign_t;\n#endif\n",
        source: <<~C,
          #include "benign.h"
          int benign_run(void) {
          #if defined(A) && defined(B)
            return 1;
          #else
            return 0;
          #endif
          }
        C
        source_includes: ['benign.h']
      )

      expect( @result.type_names( :types_h ) ).to eq(['benign_t'])
    end
  end

  # A module header reaching for a header named by a macro rather than spelled out.
  def computed_include_module
    {
      module_name: 'computed',
      header: <<~C,
        #ifndef COMPUTED_H
        #define COMPUTED_H
        #define DEVICE_HEADER "device_cfg.h"
        #include DEVICE_HEADER
        typedef struct { int slot; } computed_t;
        #endif
      C
      source: "#include \"computed.h\"\n",
      header_includes: ['device_cfg.h'],
      source_includes: ['computed.h'],
      extra: { 'device_cfg.h' => "#ifndef DEVICE_CFG_H\n#define DEVICE_CFG_H\n#endif\n" }
    }
  end

  # A type chosen by a compound condition the tracker treats as active without evaluating it.
  def unevaluable_type_module
    {
      module_name: 'narrow',
      header: <<~C,
        #ifndef NARROW_H
        #define NARROW_H
        #if defined(USE_A) && defined(USE_B)
        typedef long narrow_t;
        #else
        typedef char narrow_t;
        #endif
        #endif
      C
      source: "#include \"narrow.h\"\n",
      source_includes: ['narrow.h']
    }
  end

  # A type behind a plain #ifdef, the shape both arm-selection cases vary by defines alone.
  def conditional_module
    {
      module_name: 'feat',
      header: <<~C,
        #ifndef FEAT_H
        #define FEAT_H
        #ifdef USE_WIDE
        typedef long feat_t;
        #else
        typedef char feat_t;
        #endif
        #endif
      C
      source: "#include \"feat.h\"\n",
      source_includes: ['feat.h']
    }
  end

end
