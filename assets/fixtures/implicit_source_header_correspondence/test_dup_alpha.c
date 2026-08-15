#include "unity.h"
#include "alpha/dup.h"

void setUp(void) {}
void tearDown(void) {}

void test_dup_value_alpha(void)
{
  TEST_ASSERT_EQUAL(111, dup_value());
}
