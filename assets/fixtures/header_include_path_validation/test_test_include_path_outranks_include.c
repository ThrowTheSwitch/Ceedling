#include "unity.h"

// dup.h exists both via TEST_INCLUDE_PATH("other_inc") and via :paths -> :include
// (src/dup.h, reached through src/**). TEST_INCLUDE_PATH() ranks ahead of :include
// in this test's own search paths, so the bare #include below must resolve to
// other_inc/dup.h, matching the real compiler's own -I order.
TEST_INCLUDE_PATH("other_inc")

#include "dup.h"

void setUp(void) {}
void tearDown(void) {}

void test_dup_value_resolves_via_test_include_path(void)
{
  TEST_ASSERT_EQUAL(111, DUP_VALUE);
}
