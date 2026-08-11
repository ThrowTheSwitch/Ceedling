#include "unity.h"
#include "totally/bogus/dir/Mockfoo.h"

void setUp(void) {}
void tearDown(void) {}

void test_foo_value_bogus_include(void)
{
  foo_value_ExpectAndReturn(333);
  TEST_ASSERT_EQUAL(333, foo_value());
}
