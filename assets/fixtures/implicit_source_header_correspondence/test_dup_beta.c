#include "unity.h"
#include "beta/dup.h"

void setUp(void) {}
void tearDown(void) {}

void test_dup_value_beta(void)
{
  TEST_ASSERT_EQUAL(222, dup_value());
}
