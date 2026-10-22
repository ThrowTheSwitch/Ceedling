#include "unity.h"
#include "foo/bar.h"

void setUp(void) {}
void tearDown(void) {}

void test_foo_bar_value_should_be_111(void)
{
  TEST_ASSERT_EQUAL(111, foo_bar_value());
}
