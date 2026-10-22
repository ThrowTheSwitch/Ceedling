#include "unity.h"
#include "foo/bar.h"
#include "baz/bar.h"

void setUp(void) {}
void tearDown(void) {}

void test_foo_bar_and_baz_bar_values_are_both_correct(void)
{
  TEST_ASSERT_EQUAL(111, foo_bar_value());
  TEST_ASSERT_EQUAL(222, baz_bar_value());
}
