#include "unity.h"
#include "drivers/Mockfoo.h"

void setUp(void) {}
void tearDown(void) {}

void test_foo_value_pathed_include(void)
{
  foo_value_ExpectAndReturn(222);
  TEST_ASSERT_EQUAL(222, foo_value());
}
