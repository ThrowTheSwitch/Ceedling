# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

##
## Partial Regeneration Through Real Builds
## ========================================
##
## A Partial is regenerated when anything its generation reads changes: the test's selection
## of functions, or the preprocessed copies of the module, which forced fallback preprocessing
## rewrites without touching the originals. Nothing is regenerated when nothing changed.
##

PARTIALS_DELTA_ENGINE_HEADER = <<~C
  #ifndef ENGINE_H
  #define ENGINE_H
  int engine_get(void);
  #endif
C

PARTIALS_DELTA_ENGINE_SOURCE = <<~C
  #include "engine.h"

  static int helper(void)
  {
      return 41;
  }

  int engine_get(void)
  {
      return 42;
  }
C

PARTIALS_DELTA_PREAMBLE = "#include \"unity.h\"\n#include \"ceedling.h\"\n"

# Only engine_get(), which the public selection holds
PARTIALS_DELTA_PUBLIC_TEST = PARTIALS_DELTA_PREAMBLE + <<~C
  #include TEST_PARTIAL_PUBLIC_MODULE(engine)
  void setUp(void) {}
  void tearDown(void) {}
  void test_get(void) { TEST_ASSERT_EQUAL_INT(42, engine_get()); }
C

# helper() too, which only the whole module's selection holds
PARTIALS_DELTA_ALL_TEST = PARTIALS_DELTA_PREAMBLE + <<~C
  #include TEST_PARTIAL_ALL_MODULE(engine)
  void setUp(void) {}
  void tearDown(void) {}
  void test_get(void) { TEST_ASSERT_EQUAL_INT(42, engine_get()); }
  void test_helper(void) { TEST_ASSERT_EQUAL_INT(41, helper()); }
C

ceedling_system_tests do
  include_context "a fresh ceedling gem project", "partials_delta"

  before do
    in_project do
      File.write( 'src/engine.h', PARTIALS_DELTA_ENGINE_HEADER )
      File.write( 'src/engine.c', PARTIALS_DELTA_ENGINE_SOURCE )
      File.write( 'test/test_engine.c', PARTIALS_DELTA_PUBLIC_TEST )

      @c.merge_project_yml_for_test( { :project => { :use_partials => true } } )
    end
  end

  def build_passing(tests)
    output = @c.ceedling_build_exec( "test:all" )
    expect(@c.last_exit_status).to eq(0), output
    expect(output).to match(/PASSED:\s+#{tests}/)

    return output
  end

  it "regenerates a Partial when the test's selection changes, without a clobber" do
    in_project do
      build_passing( 1 )

      File.write( 'test/test_engine.c', PARTIALS_DELTA_ALL_TEST )
      output = build_passing( 2 )
      expect(output).to match(/Generating Partial implementation for .*engine/)

      File.write( 'test/test_engine.c', PARTIALS_DELTA_PUBLIC_TEST )
      output = build_passing( 1 )
      expect(output).to match(/Generating Partial implementation for .*engine/)
    end
  end

  it "skips generating a Partial when nothing changed" do
    in_project do
      build_passing( 1 )

      output = build_passing( 1 )
      expect(output).to_not match(/Generating Partial implementation for/)
      expect(output).to match(/Skipping Partial implementation generation/)
    end
  end

  it "regenerates a Partial when forced fallback preprocessing rewrites its preprocessed copies" do
    in_project do
      build_passing( 1 )

      @c.merge_project_yml_for_test( { :test_build => { :preprocess_force_fallback => true } } )
      output = build_passing( 1 )
      expect(output).to match(/Generating Partial implementation for .*engine/)
    end
  end
end
