# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

##
## Macro-Supplied Decorators in Partials Through Real Builds
## =========================================================
##
## A module may spell `static`, `static inline` or a type attribute through macros of its own.
## A Partial tests and mocks each function a macro makes static, and exposes each such variable.
## A type keeps an attribute a macro writes after its closing brace. Forced fallback
## preprocessing builds the same tests.
##

PARTIALS_MACROS_CONFIG_HEADER = <<~C
  #ifndef CONFIG_H
  #define CONFIG_H
  #define PRIVATE static
  #define STATICINLINE static inline
  #define PACKED __attribute__((packed))
  #endif
C

PARTIALS_MACROS_WIDGET_HEADER = <<~C
  #ifndef WIDGET_H
  #define WIDGET_H
  #include "config.h"
  struct pk { char c; int i; } PACKED;
  int widget_get(void);
  #endif
C

PARTIALS_MACROS_WIDGET_SOURCE = <<~C
  #include "widget.h"

  PRIVATE int counter;

  // The name on its own line moves the rewritten head's line marker
  PRIVATE int
  helper(void)
  {
      return 20;
  }

  STATICINLINE int twice(int v)
  {
      return v * 2;
  }

  int widget_get(void)
  {
      counter++;
      return twice( helper() ) + 2;
  }
C

PARTIALS_MACROS_PREAMBLE = "#include \"unity.h\"\n#include \"ceedling.h\"\n"

# Every function and variable a macro made static, and the type a macro packed
PARTIALS_MACROS_ALL_TEST = PARTIALS_MACROS_PREAMBLE + <<~C
  #include TEST_PARTIAL_ALL_MODULE(widget)
  void setUp(void) { counter = 0; }
  void tearDown(void) {}
  void test_helper(void) { TEST_ASSERT_EQUAL_INT(20, helper()); }
  void test_twice(void) { TEST_ASSERT_EQUAL_INT(42, twice(21)); }
  void test_get_counts(void) { TEST_ASSERT_EQUAL_INT(42, widget_get()); TEST_ASSERT_EQUAL_INT(1, counter); }
  void test_packed(void) { TEST_ASSERT_EQUAL_size_t(sizeof(char) + sizeof(int), sizeof(struct pk)); }
C

# The public function under test calls its private neighbors through their mocks
PARTIALS_MACROS_MOCKED_TEST = PARTIALS_MACROS_PREAMBLE + <<~C
  #include TEST_PARTIAL_PUBLIC_MODULE(widget)
  #include MOCK_PARTIAL_PRIVATE_MODULE(widget)
  void setUp(void) {}
  void tearDown(void) {}
  void test_get_through_mocks(void)
  {
      helper_ExpectAndReturn(5);
      twice_ExpectAndReturn(5, 7);
      TEST_ASSERT_EQUAL_INT(9, widget_get());
  }
C

ceedling_system_tests do
  include_context "a fresh ceedling gem project", "partials_macro_decorators"

  before do
    in_project do
      File.write( 'src/config.h', PARTIALS_MACROS_CONFIG_HEADER )
      File.write( 'src/widget.h', PARTIALS_MACROS_WIDGET_HEADER )
      File.write( 'src/widget.c', PARTIALS_MACROS_WIDGET_SOURCE )
      File.write( 'test/test_widget_all.c', PARTIALS_MACROS_ALL_TEST )
      File.write( 'test/test_widget_mocked.c', PARTIALS_MACROS_MOCKED_TEST )

      @c.merge_project_yml_for_test( { :project => { :use_partials => true } } )
    end
  end

  def build_passing(tests)
    output = @c.ceedling_build_exec( "test:all" )
    expect(@c.last_exit_status).to eq(0), output
    expect(output).to match(/PASSED:\s+#{tests}/)

    return output
  end

  it "tests and mocks the functions macros make static, and exposes the variable" do
    in_project do
      build_passing( 5 )
    end
  end

  it "tests and mocks the functions macros make static with forced fallback preprocessing" do
    in_project do
      @c.merge_project_yml_for_test( { :test_build => { :preprocess_force_fallback => true } } )

      expect(build_passing( 5 )).to match(/Forcing best-effort fallback preprocessing/)
    end
  end
end
