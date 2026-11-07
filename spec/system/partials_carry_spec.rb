# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

##
## What a Partial Carries Through Real Builds
## ==========================================
##
## A Partial's implementation source carries what the module's code relied on beyond the
## selected functions: prototypes of functions defined elsewhere, prototypes of functions the
## test left out, and the header helpers kept code calls. These builds run unoptimized, where
## an inline function's call needs a real external definition to link against.
##

PARTIALS_CARRY_PREAMBLE = "#include \"unity.h\"\n#include \"ceedling.h\"\n"

# An inline function lives in a header that isn't the module's. The module's source declares it
# `extern inline`, which makes that source's object hold the external definition.
PARTIALS_CARRY_API_HEADER = <<~C
  #ifndef ENGINE_API_H
  #define ENGINE_API_H
  int engine_get(void);
  inline int engine_get_twice(void)
  {
      return 2 * engine_get();
  }
  #endif
C

PARTIALS_CARRY_PORT_HEADER = <<~C
  #ifndef PORT_H
  #define PORT_H
  static int port_read(void);
  #endif
C

PARTIALS_CARRY_INLINE_SOURCE = <<~C
  #include "engine_api.h"
  #include "port.h"

  extern inline int engine_get_twice(void);

  int engine_get(void)
  {
      return port_read() + 1;
  }
C

PARTIALS_CARRY_INLINE_TEST = PARTIALS_CARRY_PREAMBLE + <<~C
  #include TEST_PARTIAL_PUBLIC_MODULE(engine)
  #include MOCK_PARTIAL_PRIVATE_MODULE(port)
  #include "engine_api.h"

  void setUp(void) {}
  void tearDown(void) {}

  void test_engine_get_adds_one(void)
  {
      port_read_ExpectAndReturn(41);
      TEST_ASSERT_EQUAL_INT(42, engine_get());
  }

  void test_engine_get_twice_doubles(void)
  {
      port_read_ExpectAndReturn(20);
      TEST_ASSERT_EQUAL_INT(42, engine_get_twice());
  }
C

# A header helper, a prototype defined elsewhere, a subtracted function the test stubs, and an
# extern variable the test defines
PARTIALS_CARRY_HELPER_HEADER = <<~C
  #ifndef BOARD_ENGINE_H
  #define BOARD_ENGINE_H
  extern int board_count;
  int board_tick(void);
  static inline int clamp(int v) { return v > 9 ? 9 : v; }
  int board_engine_get(void);
  int board_engine_poll(void);
  int board_engine_report(void);
  int board_engine_count(void);
  #endif
C

PARTIALS_CARRY_HELPER_SOURCE = <<~C
  #include "board_engine.h"
  int board_engine_get(void) { return clamp(board_tick()); }
  int board_engine_poll(void) { return board_engine_get(); }
  int board_engine_report(void) { return board_engine_poll() + 1; }
  int board_engine_count(void) { return board_count + 1; }
C

PARTIALS_CARRY_HELPER_TEST = PARTIALS_CARRY_PREAMBLE + <<~C
  #include TEST_PARTIAL_PUBLIC_MODULE(board_engine)
  TEST_PARTIAL_CONFIG(board_engine, -board_engine_poll)

  int board_count = 41;
  int board_tick(void) { return 12; }
  int board_engine_poll(void) { return 7; }

  void setUp(void) {}
  void tearDown(void) {}

  void test_get_clamps_the_tick(void) { TEST_ASSERT_EQUAL_INT(9, board_engine_get()); }
  void test_report_uses_the_stubbed_poll(void) { TEST_ASSERT_EQUAL_INT(8, board_engine_report()); }
  void test_count_reads_the_extern_variable(void) { TEST_ASSERT_EQUAL_INT(42, board_engine_count()); }
C

# A guardless module header that another header pulls in again, helpers and all
PARTIALS_CARRY_ONCE_HEADER = <<~C
  #pragma once
  static inline int clamp(int v) { return v > 9 ? 9 : v; }
  int once_get(int v);
C

PARTIALS_CARRY_ONCE_CONFIG = <<~C
  #ifndef ONCE_CFG_H
  #define ONCE_CFG_H
  #include "once.h"
  #define ONCE_BIAS 0
  #endif
C

PARTIALS_CARRY_ONCE_SOURCE = <<~C
  #include "once.h"
  #include "once_cfg.h"
  int once_get(int v) { return clamp(v) + ONCE_BIAS; }
C

PARTIALS_CARRY_ONCE_TEST = PARTIALS_CARRY_PREAMBLE + <<~C
  #include TEST_PARTIAL_PUBLIC_MODULE(once)
  void setUp(void) {}
  void tearDown(void) {}
  void test_get(void) { TEST_ASSERT_EQUAL_INT(9, once_get(42)); }
C

ceedling_system_tests do
  include_context "a fresh ceedling gem project", "partials_carry"

  before do
    in_project do
      @c.merge_project_yml_for_test( { :project => { :use_partials => true } } )
    end
  end

  def build_passing(tests)
    output = @c.ceedling_build_exec( "test:all" )
    expect(@c.last_exit_status).to eq(0), output
    expect(output).to match(/PASSED:\s+#{tests}/)

    return output
  end

  it "links a test calling an inline function the module defines externally" do
    in_project do
      File.write( 'src/engine_api.h', PARTIALS_CARRY_API_HEADER )
      File.write( 'src/port.h', PARTIALS_CARRY_PORT_HEADER )
      File.write( 'src/engine.c', PARTIALS_CARRY_INLINE_SOURCE )
      File.write( 'test/test_engine.c', PARTIALS_CARRY_INLINE_TEST )

      build_passing( 2 )
    end
  end

  it "builds a module whose code relies on a helper, external prototypes and a test stub" do
    in_project do
      File.write( 'src/board_engine.h', PARTIALS_CARRY_HELPER_HEADER )
      File.write( 'src/board_engine.c', PARTIALS_CARRY_HELPER_SOURCE )
      File.write( 'test/test_board_engine.c', PARTIALS_CARRY_HELPER_TEST )

      build_passing( 3 )
    end
  end

  it "leaves an unguarded header's helpers behind with a notice, and still builds" do
    in_project do
      File.write( 'src/once.h', PARTIALS_CARRY_ONCE_HEADER )
      File.write( 'src/once_cfg.h', PARTIALS_CARRY_ONCE_CONFIG )
      File.write( 'src/once.c', PARTIALS_CARRY_ONCE_SOURCE )
      File.write( 'test/test_once.c', PARTIALS_CARRY_ONCE_TEST )

      output = build_passing( 1 )
      expect(output).to include( 'Not carrying helper `clamp()` from src/once.h.' )
    end
  end
end
