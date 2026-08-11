#include "unity.h"
#include "totally/bogus/dir/bar.h"

void setUp(void) {}
void tearDown(void) {}

void test_bar_value(void)
{
  TEST_ASSERT_EQUAL(7, BAR_VALUE);
}
