#include "unity.h"
#include "mock_foo.h"

void setUp(void) {}
void tearDown(void) {}

void test_foo_value_bare_include(void)
{
  foo_value_ExpectAndReturn(111);
  TEST_ASSERT_EQUAL(111, foo_value());
}
