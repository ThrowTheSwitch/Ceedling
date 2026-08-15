#include "unity.h"
#include "dup.h"

void setUp(void) {}
void tearDown(void) {}

void test_dup_value_bare(void)
{
  TEST_ASSERT_EQUAL(111, dup_value());
}
