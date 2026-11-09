# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

##
## Function Pointers in Partials Through Real Builds
## =================================================
##
## A module may take, return and hold function pointers without a typedef for their type.
## A Partial of such a module has to read each declaration whole and declare each function
## pointer with its whole type. A mocked Partial hands such a prototype to CMock.
##

PARTIALS_FP_PREAMBLE = "#include \"unity.h\"\n#include \"ceedling.h\"\n"

PARTIALS_FP_HEADER = <<~C
  #ifndef TICKER_H
  #define TICKER_H
  void ticker_register(int (*cb)(int));
  int ticker_count(void);
  int ticker_fire(int n);
  #endif
C

PARTIALS_FP_SOURCE = <<~C
  #include "ticker.h"

  static int calls;
  static int (*s_hook)(int);

  void ticker_register(int (*cb)(int))
  {
      s_hook = cb;
      calls = cb(calls);
  }

  int ticker_count(void)
  {
      return calls;
  }

  int ticker_fire(int n)
  {
      return s_hook ? s_hook(n) : -1;
  }
C

PARTIALS_FP_TEST = PARTIALS_FP_PREAMBLE + <<~C
  #include TEST_PARTIAL_PUBLIC_MODULE(ticker)
  static int bump(int n) { return n + 1; }
  void setUp(void) {}
  void tearDown(void) {}
  void test_register_calls_back(void) { ticker_register(bump); TEST_ASSERT_EQUAL_INT(1, ticker_count()); }
  void test_fire_uses_the_hook(void) { ticker_register(bump); TEST_ASSERT_EQUAL_INT(3, ticker_fire(2)); }
  void test_hook_is_visible(void) { s_hook = bump; TEST_ASSERT_EQUAL_INT(5, ticker_fire(4)); }
C

PARTIALS_FP_MOCK_TEST = PARTIALS_FP_PREAMBLE + <<~C
  #include MOCK_PARTIAL_PUBLIC_MODULE(ticker)
  static int bump(int n) { return n + 1; }
  void setUp(void) {}
  void tearDown(void) {}
  void test_register_is_expected(void) { ticker_register_Expect(bump); ticker_register(bump); }
C

ceedling_system_tests do
  include_context "a fresh ceedling gem project", "partials_function_pointers"

  before do
    in_project do
      File.write( 'src/ticker.h', PARTIALS_FP_HEADER )
      File.write( 'src/ticker.c', PARTIALS_FP_SOURCE )

      @c.merge_project_yml_for_test( { :project => { :use_partials => true } } )
    end
  end

  def build_passing(tests)
    output = @c.ceedling_build_exec( "test:all" )
    expect(@c.last_exit_status).to eq(0), output
    expect(output).to match(/PASSED:\s+#{tests}/)

    return output
  end

  it "tests a module whose function takes a function pointer and that holds one" do
    in_project do
      File.write( 'test/test_ticker.c', PARTIALS_FP_TEST )

      build_passing( 3 )
    end
  end

  it "mocks a module whose function takes a function pointer" do
    in_project do
      File.write( 'test/test_ticker.c', PARTIALS_FP_MOCK_TEST )

      build_passing( 1 )
    end
  end
end
