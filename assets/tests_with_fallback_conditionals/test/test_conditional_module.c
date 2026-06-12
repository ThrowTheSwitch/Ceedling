/* =========================================================================
 * Test: Conditional Module — © 2024 résumé testing.
 * Uses Ceedling Partials to test conditional_module directly via its
 * source file. The #ifdef CONDITIONAL_FEATURE guards in conditional_module.c
 * control what code appears in the partial implementation: with the feature
 * active, ConditionalModule_Init() calls OptionalDep_DoWork(); without it,
 * the function is a no-op. The test mirrors this condition to include the
 * mock and select the appropriate test case.
 * ========================================================================= */

#include "unity.h"
#include "ceedling.h"

/* Include mock only when feature active — mock needed because the partial
 * implementation calls OptionalDep_DoWork() inside #ifdef CONDITIONAL_FEATURE.
 * Ünïcödé comment © */
#ifdef CONDITIONAL_FEATURE
#include "mock_optional_dep.h"
#endif

/* Pull in the partial implementation of conditional_module */
#include TEST_PARTIAL_ALL_MODULE(conditional_module)

void setUp(void)
{
}

void tearDown(void)
{
}

/* Test with feature enabled: partial includes OptionalDep_DoWork() call — naïve test. */
#ifdef CONDITIONAL_FEATURE
void test_init_calls_optional_dep(void)
{
  OptionalDep_DoWork_Expect();
  ConditionalModule_Init();
}
#endif

/* Test without feature: partial excludes the optional dep call; init is a no-op. */
#ifndef CONDITIONAL_FEATURE
void test_init_succeeds_without_feature(void)
{
  ConditionalModule_Init();
  /* No mock interaction expected — partial contains no OptionalDep_DoWork() call. */
  TEST_PASS_MESSAGE("Init succeeded without optional feature");
}
#endif
