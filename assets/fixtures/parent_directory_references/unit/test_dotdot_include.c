#include "unity.h"
#include "../common/helper.h"

void setUp(void) {}
void tearDown(void) {}

void test_helper_value_via_parent_directory_include(void)
{
  TEST_ASSERT_EQUAL(111, helper_value());
}
