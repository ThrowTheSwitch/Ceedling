#include "unity.h"
#include "FeatureConfig.h"

void test_always_runs(void)
{
  TEST_PASS();
}

// The header alone decides whether this test case exists
#ifdef FEATURE_X
void test_feature_x_runs_when_enabled(void)
{
  TEST_PASS();
}
#endif
