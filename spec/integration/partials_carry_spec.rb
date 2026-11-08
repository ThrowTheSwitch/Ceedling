# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# What a Partial carries beyond the functions a test selected, proven with a real compiler.
#
# A module's code relies on more than its own selected functions. It declares functions
# defined elsewhere, and its header defines small static or inline helpers. A Partial
# carries the prototypes and the referenced helpers into its implementation source, after
# every include, so that code compiles and links. Each case below is a shape that failed to
# compile or link before carrying, or a shape carrying must leave alone.
#
# Generation runs through spec/support/integration/partials_generation_integration_helper.rb,
# which plans carrying the way PartialsManager does.

require 'spec_helper'
require 'spec_integration_helper'
require 'partials_generation_integration_helper'

describe 'What a Partial carries' do

  include_context 'requires gcc'
  before { skip 'directives-only preprocessing is unavailable' unless directives_only_supported? }

  after(:each) { cleanup_partial( @result ) }

  # The harness mocks every function unless told otherwise. A mocked function is never carried,
  # so cases about carrying turn mocking off and a case about mocking says how it mocks.

  ENGINE_API_H = <<~C
    #ifndef ENGINE_API_H
    #define ENGINE_API_H
    inline int engine_get_twice(void) { return 42; }
    #endif
  C

  # ---------------------------------------------------------------------------
  context 'prototypes of functions the module declares but never defines' do
  # ---------------------------------------------------------------------------

    # The C99 inline idiom: a header holds the inline body, and one source file declares the
    # function `extern inline` so its object holds the external definition. Nothing calls the
    # prototype. Its whole job is that definition, which an unoptimized call links against.
    it 'links a call to an inline function whose external definition the module provides' do
      @result = generate_partial(
        module_name: 'engine',
        header: "#ifndef ENGINE_H\n#define ENGINE_H\nint engine_get(void);\n#endif\n",
        source: "#include \"engine.h\"\n#include \"engine_api.h\"\nextern inline int engine_get_twice(void);\nint engine_get(void) { return 1; }\n",
        source_includes: ['engine.h', 'engine_api.h'],
        extra: { 'engine_api.h' => ENGINE_API_H },
        tests_expose: PartializerConfig::PUBLIC, mocks_expose: nil
      )

      expect( @result.impl_c ).to include( 'extern inline int engine_get_twice(void);' )

      link = link_partial( @result, references: ['engine_get_twice'], flags: '-O0' )
      expect( link.ok ).to be(true), "expected a clean link, got: #{link.first_error}"
    end

    it 'compiles a call to a function the source declares extern' do
      @result = generate_partial(
        module_name: 'ticker',
        header: "#ifndef TICKER_H\n#define TICKER_H\nint ticker_get(void);\n#endif\n",
        source: "#include \"ticker.h\"\nextern int board_tick(void);\nint ticker_get(void) { return board_tick() + 1; }\n",
        source_includes: ['ticker.h'], mocks_expose: nil
      )

      compile = compile_objects( @result )
      expect( compile.ok ).to be(true), "expected a clean compile, got: #{compile.first_error}"
    end

    it 'compiles a call to a function the header declares and another module defines' do
      @result = generate_partial(
        module_name: 'counter',
        header: "#ifndef COUNTER_H\n#define COUNTER_H\nint counter_get(void);\nint board_tick(void);\n#endif\n",
        source: "#include \"counter.h\"\nint counter_get(void) { return board_tick() + 1; }\n",
        source_includes: ['counter.h'], mocks_expose: nil
      )

      compile = compile_objects( @result )
      expect( compile.ok ).to be(true), "expected a clean compile, got: #{compile.first_error}"
    end
  end

  # ---------------------------------------------------------------------------
  context 'prototypes a later macro renames' do
  # ---------------------------------------------------------------------------

    # A header included after the prototype turns calls into calls of another function. Nothing
    # kept calls the original name, so its prototype stays behind where the macro can't mangle it.
    it 'compiles when a function-like macro defined later shares a prototype\'s name' do
      @result = generate_partial(
        module_name: 'pooled',
        header: "#ifndef POOLED_H\n#define POOLED_H\nvoid *pool_alloc(unsigned n);\nvoid *pooled_buf(void);\n#endif\n",
        source: "#include \"pooled.h\"\n#include \"pool_dbg.h\"\nvoid *pooled_buf(void) { return pool_alloc(4); }\n",
        source_includes: ['pooled.h', 'pool_dbg.h'],
        extra: { 'pool_dbg.h' => "#ifndef POOL_DBG_H\n#define POOL_DBG_H\nvoid *pool_alloc_dbg(unsigned n, int line);\n#define pool_alloc(n) pool_alloc_dbg((n), __LINE__)\n#endif\n" },
        tests_expose: PartializerConfig::PUBLIC, mocks_expose: nil
      )

      compile = compile_objects( @result )
      expect( compile.ok ).to be(true), "expected a clean compile, got: #{compile.first_error}"
    end
  end

  # ---------------------------------------------------------------------------
  context 'functions the test left out' do
  # ---------------------------------------------------------------------------

    # A test subtracts a function to stub it. The selected function calling it links to the stub.
    it 'links a selected call to a subtracted function against the test stub' do
      @result = generate_partial(
        module_name: 'reporter',
        header: "#ifndef REPORTER_H\n#define REPORTER_H\nint reporter_poll(void);\nint reporter_report(void);\n#endif\n",
        source: "#include \"reporter.h\"\nint reporter_poll(void) { return 1; }\nint reporter_report(void) { return reporter_poll() + 1; }\n",
        source_includes: ['reporter.h'],
        tests_expose: PartializerConfig::PUBLIC, tests_subtract: ['reporter_poll'], mocks_expose: nil
      )

      expect( @result.impl_c ).not_to include( 'return 1; }' )

      link = link_partial( @result, references: ['reporter_report'], stubs: 'int reporter_poll(void) { return 7; }' )
      expect( link.ok ).to be(true), "expected a clean link, got: #{link.first_error}"
    end
  end

  # ---------------------------------------------------------------------------
  context 'helpers the module header defines' do
  # ---------------------------------------------------------------------------

    it 'compiles a selected call to a static inline helper, anchored to the header' do
      @result = generate_partial(
        module_name: 'clamped',
        header: "#ifndef CLAMPED_H\n#define CLAMPED_H\nstatic inline int clamp(int v) { return v > 9 ? 9 : v; }\nint clamped_get(int v);\n#endif\n",
        source: "#include \"clamped.h\"\nint clamped_get(int v) { return clamp(v); }\n",
        source_includes: ['clamped.h'],
        tests_expose: PartializerConfig::PUBLIC, mocks_expose: nil
      )

      expect( @result.impl_c ).to include( 'static inline int clamp(int v)' )

      compile = compile_objects( @result )
      expect( compile.ok ).to be(true), "expected a clean compile, got: #{compile.first_error}"
    end

    it 'leaves out a helper nothing kept calls, so its own calls never have to compile' do
      @result = generate_partial(
        module_name: 'quiet',
        header: "#ifndef QUIET_H\n#define QUIET_H\nstatic void raw_write(void);\nstatic inline void log_raw(void) { raw_write(); }\nint quiet_get(void);\n#endif\n",
        source: "#include \"quiet.h\"\nstatic void raw_write(void) { }\nint quiet_get(void) { return 1; }\n",
        source_includes: ['quiet.h'],
        tests_expose: PartializerConfig::PUBLIC, mocks_expose: nil
      )

      expect( @result.impl_c ).not_to include( 'log_raw' )

      compile = compile_objects( @result, flags: '-Wall -Werror' )
      expect( compile.ok ).to be(true), "expected a clean compile, got: #{compile.first_error}"
    end

    # The expanded copy shows the call the macro hides
    it 'carries a helper that a macro calls' do
      @result = generate_partial(
        module_name: 'macroed',
        header: "#ifndef MACROED_H\n#define MACROED_H\n#define CLAMP(x) clamp(x)\nstatic inline int clamp(int v) { return v > 9 ? 9 : v; }\nint macroed_get(int v);\n#endif\n",
        source: "#include \"macroed.h\"\nint macroed_get(int v) { return CLAMP(v); }\n",
        source_includes: ['macroed.h'],
        tests_expose: PartializerConfig::PUBLIC, mocks_expose: nil
      )

      compile = compile_objects( @result )
      expect( compile.ok ).to be(true), "expected a clean compile, got: #{compile.first_error}"
    end

    # Promotion renames a helper's function-scope static and defines it once in the same file
    it 'links a helper whose function-scope static was promoted' do
      @result = generate_partial(
        module_name: 'ticks',
        header: "#ifndef TICKS_H\n#define TICKS_H\nstatic inline int counter(void) { static int n = 0; return ++n; }\nint ticks_next(void);\n#endif\n",
        source: "#include \"ticks.h\"\nint ticks_next(void) { return counter(); }\n",
        source_includes: ['ticks.h'],
        tests_expose: PartializerConfig::PUBLIC, mocks_expose: nil
      )

      link = link_partial( @result, references: ['ticks_next'] )
      expect( link.ok ).to be(true), "expected a clean link, got: #{link.first_error}"
    end

    # The helper sits after the module's own interface include, where the mocked function is declared
    it 'compiles a helper that calls a function the test mocks' do
      @result = generate_partial(
        module_name: 'noted',
        header: "#ifndef NOTED_H\n#define NOTED_H\nvoid noted_log(int code);\nstatic inline void note(int code) { noted_log(code); }\nint noted_get(int v);\n#endif\n",
        source: "#include \"noted.h\"\nvoid noted_log(int code) { (void)code; }\nint noted_get(int v) { note(v); return v + 1; }\n",
        source_includes: ['noted.h'],
        tests_expose: PartializerConfig::PUBLIC,
        mocks_expose: PartializerConfig::ACCUMULATE, mocks_add: ['noted_log']
      )

      expect( @result.impl_c.index( 'static inline void note' ) ).to be > @result.impl_c.index( 'ceedling_partial_noted_interface.h' )

      compile = compile_objects( @result )
      expect( compile.ok ).to be(true), "expected a clean compile, got: #{compile.first_error}"
    end

    # A member that shares a helper's name is not a call. Carrying the helper anyway leaves an
    # unused static function, which -Wall -Werror rejects.
    it 'carries no helper that only a member access names' do
      @result = generate_partial(
        module_name: 'buffers',
        header: "#ifndef BUFFERS_H\n#define BUFFERS_H\ntypedef struct { int len; int size; } buf_t;\nstatic inline int size(const buf_t *b) { return b->len; }\nint buffers_get(const buf_t *b);\n#endif\n",
        source: "#include \"buffers.h\"\nint buffers_get(const buf_t *b) { return b->size; }\n",
        source_includes: ['buffers.h'],
        tests_expose: PartializerConfig::PUBLIC, mocks_expose: nil
      )

      expect( @result.impl_c ).not_to include( 'static inline int size' )

      compile = compile_objects( @result, flags: '-Wall -Werror' )
      expect( compile.ok ).to be(true), "expected a clean compile, got: #{compile.first_error}"
    end

    # A plain inline helper gets its external definition from the source's extern inline prototype
    it 'links a plain inline helper through its extern inline prototype' do
      @result = generate_partial(
        module_name: 'twicer',
        header: "#ifndef TWICER_H\n#define TWICER_H\nint twicer_base(void);\ninline int twicer_twice(void) { return 2 * twicer_base(); }\nint twicer_get(void);\n#endif\n",
        source: "#include \"twicer.h\"\nextern inline int twicer_twice(void);\nint twicer_base(void) { return 21; }\nint twicer_get(void) { return twicer_twice(); }\n",
        source_includes: ['twicer.h'],
        tests_expose: PartializerConfig::PUBLIC, mocks_expose: nil
      )

      link = link_partial( @result, references: ['twicer_get'], flags: '-O0' )
      expect( link.ok ).to be(true), "expected a clean link, got: #{link.first_error}"
    end
  end

  # ---------------------------------------------------------------------------
  context 'a module header without an include guard' do
  # ---------------------------------------------------------------------------

    # Another header pulls the real module header in, helpers and all. A carried copy would collide.
    it 'carries no helper, so the real header\'s copy compiles alone' do
      @result = generate_partial(
        module_name: 'onceful',
        header: "#pragma once\nstatic inline int clamp(int v) { return v > 9 ? 9 : v; }\nint onceful_get(int v);\n",
        source: "#include \"onceful.h\"\n#include \"onceful_cfg.h\"\nint onceful_get(int v) { return clamp(v) + ONCEFUL_BIAS; }\n",
        source_includes: ['onceful.h', 'onceful_cfg.h'],
        extra: { 'onceful_cfg.h' => "#ifndef ONCEFUL_CFG_H\n#define ONCEFUL_CFG_H\n#include \"onceful.h\"\n#define ONCEFUL_BIAS 0\n#endif\n" },
        tests_expose: PartializerConfig::PUBLIC, mocks_expose: nil
      )

      expect( @result.impl_c ).not_to include( 'static inline int clamp' )
      expect( @result.carry.skipped.map( &:item ) ).to eq( ['clamp'] )

      compile = compile_objects( @result )
      expect( compile.ok ).to be(true), "expected a clean compile, got: #{compile.first_error}"
    end
  end

  # ---------------------------------------------------------------------------
  context 'prototypes a header already declared' do
  # ---------------------------------------------------------------------------

    REDUNDANT_SOURCE = "#include \"repeats.h\"\n#include \"repeats_board.h\"\nextern int board_tick(void);\nint repeats_get(void) { return board_tick(); }\n"

    def generate_repeats(suppress:)
      generate_partial(
        module_name: 'repeats',
        header: "#ifndef REPEATS_H\n#define REPEATS_H\nint board_tick(void);\nint repeats_get(void);\n#endif\n",
        source: REDUNDANT_SOURCE,
        source_includes: ['repeats.h', 'repeats_board.h'],
        extra: { 'repeats_board.h' => "#ifndef REPEATS_BOARD_H\n#define REPEATS_BOARD_H\nint board_tick(void);\n#endif\n" },
        suppress_redundant_decls: suppress, mocks_expose: nil
      )
    end

    it 'compiles under -Wredundant-decls -Werror with the redundant declarations suppressed' do
      @result = generate_repeats( suppress: true )

      compile = compile_objects( @result, flags: '-Wredundant-decls -Werror' )
      expect( compile.ok ).to be(true), "expected a clean compile, got: #{compile.first_error}"
    end

    it 'writes the prototypes bare when suppression is off' do
      @result = generate_repeats( suppress: false )

      expect( @result.impl_c ).to include( 'extern int board_tick(void);' )
      expect( @result.impl_c ).not_to include( '#pragma' )
    end
  end

  # ---------------------------------------------------------------------------
  context 'a selected function that never returns' do
  # ---------------------------------------------------------------------------

    # A caller ending in a call to it needs to know it never returns, or -Wreturn-type objects
    it 'keeps _Noreturn, so its callers compile under -Wall -Werror' do
      @result = generate_partial(
        module_name: 'parser',
        header: "#ifndef PARSER_H\n#define PARSER_H\nint parser_parse(int x);\n#endif\n",
        source: "#include \"parser.h\"\nstatic _Noreturn void fatal(void) { for (;;) {} }\nint parser_parse(int x) { if (x >= 0) return x; fatal(); }\n",
        source_includes: ['parser.h'], mocks_expose: nil
      )

      expect( @result.impl_c ).to include( '_Noreturn void fatal(void)' )

      compile = compile_objects( @result, flags: '-Wall -Werror' )
      expect( compile.ok ).to be(true), "expected a clean compile, got: #{compile.first_error}"
    end
  end

  # ---------------------------------------------------------------------------
  context 'variables' do
  # ---------------------------------------------------------------------------

    # Two definitions of one variable are a link error wherever common symbols are off
    it 'links an extern variable defined elsewhere without defining it again' do
      @result = generate_partial(
        module_name: 'tally',
        header: "#ifndef TALLY_H\n#define TALLY_H\nextern int board_count;\nint tally_get(void);\n#endif\n",
        source: "#include \"tally.h\"\nint tally_get(void) { return board_count + 1; }\n",
        source_includes: ['tally.h'], mocks_expose: nil
      )

      link = link_partial( @result, references: ['tally_get'], stubs: 'int board_count = 41;', flags: '-fno-common' )
      expect( link.ok ).to be(true), "expected a clean link, got: #{link.first_error}"
    end

    TALLY_H = "#ifndef TALLY_H\n#define TALLY_H\nextern int board_count;\nint tally_get(void);\n#endif\n"
    TALLY_C = "#include \"tally.h\"\nint tally_get(void) { return board_count + 1; }\n"

    # The weak definition stands in when the defining module isn't part of the test
    it 'links an extern variable nothing else defines' do
      @result = generate_partial(
        module_name: 'tally', header: TALLY_H, source: TALLY_C, source_includes: ['tally.h'], mocks_expose: nil
      )

      link = link_partial( @result, references: ['tally_get'], flags: '-fno-common' )
      expect( link.ok ).to be(true), "expected a clean link, got: #{link.first_error}"
    end

    it 'leaves the definition to the test when told to' do
      @result = generate_partial(
        module_name: 'tally', header: TALLY_H, source: TALLY_C, source_includes: ['tally.h'],
        mocks_expose: nil, extern_variables: :test
      )

      expect( @result.impl_c ).not_to include( 'int board_count' )

      link = link_partial( @result, references: ['tally_get'], stubs: 'int board_count = 41;', flags: '-fno-common' )
      expect( link.ok ).to be(true), "expected a clean link, got: #{link.first_error}"
    end

    # The implementation header declares the variable from its definition, size included
    it 'keeps an array\'s size for a test\'s sizeof' do
      @result = generate_partial(
        module_name: 'table',
        header: "#ifndef TABLE_H\n#define TABLE_H\nextern const int lut[];\nint table_get(int i);\n#endif\n",
        source: "#include \"table.h\"\nconst int lut[4] = { 1, 2, 3, 4 };\nint table_get(int i) { return lut[i]; }\n",
        source_includes: ['table.h'], mocks_expose: nil
      )

      link = link_partial( @result, references: ['table_get'], stubs: 'unsigned lut_size(void) { return sizeof(lut); }' )
      expect( link.ok ).to be(true), "expected a clean link, got: #{link.first_error}"
    end

    # No definition of a type the module never completes can compile, so the defining module supplies it
    it 'writes no definition of an extern variable of an opaque struct' do
      @result = generate_partial(
        module_name: 'handle',
        header: "#ifndef HANDLE_H\n#define HANDLE_H\nstruct handle_s;\nextern struct handle_s the_handle;\nstruct handle_s *handle_get(void);\n#endif\n",
        source: "#include \"handle.h\"\nstruct handle_s *handle_get(void) { return &the_handle; }\n",
        source_includes: ['handle.h'], mocks_expose: nil
      )

      expect( @result.impl_c ).not_to include( 'struct handle_s the_handle;' )

      link = link_partial( @result, references: ['handle_get'], stubs: 'struct handle_s { int id; }; struct handle_s the_handle;' )
      expect( link.ok ).to be(true), "expected a clean link, got: #{link.first_error}"
    end
  end

  # ---------------------------------------------------------------------------
  context 'under fallback preprocessing' do
  # ---------------------------------------------------------------------------

    # Fallback keeps one branch of a conditional it can't evaluate, so a prototype arrives once
    it 'carries a prototype from a conditional header' do
      @result = generate_partial(
        module_name: 'branchy',
        header: "#ifndef BRANCHY_H\n#define BRANCHY_H\n#if BOARD_REV > 2\nint board_tick(int);\n#else\nlong board_tick(int);\n#endif\nint branchy_get(void);\n#endif\n",
        source: "#include \"branchy.h\"\nint branchy_get(void) { return (int)board_tick(1); }\n",
        source_includes: ['branchy.h'], mode: :fallback, mocks_expose: nil
      )

      expect( @result.carry.prototypes.size ).to eq( 1 )

      compile = compile_objects( @result )
      expect( compile.ok ).to be(true), "expected a clean compile, got: #{compile.first_error}"
    end
  end

  # ---------------------------------------------------------------------------
  context 'an inline function the module only declares, under a private mock' do
  # ---------------------------------------------------------------------------

    # Its body lives in a header the module includes, so a mock could never replace it
    it 'keeps it out of the mock and carries its prototype instead' do
      @result = generate_partial(
        module_name: 'mocked',
        header: "#ifndef MOCKED_H\n#define MOCKED_H\nint mocked_get(void);\n#endif\n",
        source: "#include \"mocked.h\"\n#include \"engine_api.h\"\nextern inline int engine_get_twice(void);\nstatic int mocked_base(void) { return 41; }\nint mocked_get(void) { return mocked_base() + 1; }\n",
        source_includes: ['mocked.h', 'engine_api.h'],
        extra: { 'engine_api.h' => ENGINE_API_H },
        tests_expose: PartializerConfig::PUBLIC, mocks_expose: PartializerConfig::PRIVATE
      )

      expect( @result.interface_h ).not_to include( 'engine_get_twice' )
      expect( @result.interface_h ).to include( 'int mocked_base(void);' )
      expect( @result.impl_c ).to include( 'extern inline int engine_get_twice(void);' )
    end
  end
end
