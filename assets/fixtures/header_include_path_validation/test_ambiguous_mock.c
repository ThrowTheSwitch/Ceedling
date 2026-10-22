#include "unity.h"
#include "mock_foo.h"

// foo.h exists identically in two configured :include directories
// (src/alt_drivers/foo.h and src/drivers/foo.h). This bare #include must
// resolve to exactly one of them, by search-path order, rather than erroring.

void setUp(void) {}
void tearDown(void) {}

void test_foo_value_ambiguous_mock(void)
{
  foo_value_ExpectAndReturn(111);
  TEST_ASSERT_EQUAL(111, foo_value());
}
