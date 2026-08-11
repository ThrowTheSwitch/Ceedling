#include "unity.h"
#include "baz/bar.h"

void setUp(void) {}
void tearDown(void) {}

void test_baz_bar_value_should_be_222(void)
{
  TEST_ASSERT_EQUAL(222, baz_bar_value());
}
