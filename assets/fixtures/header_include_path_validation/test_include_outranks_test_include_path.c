#include "unity.h"

// dup.h exists both via TEST_INCLUDE_PATH("other_inc") and via :paths -> :include
// (src/inc_dup/dup.h). TEST_INCLUDE_PATH() ranks ahead of :include by default, but
// naming enough trailing path here selects the :include copy specifically.
TEST_INCLUDE_PATH("other_inc")

#include "inc_dup/dup.h"

void setUp(void) {}
void tearDown(void) {}

void test_dup_value_resolves_via_include_path(void)
{
  TEST_ASSERT_EQUAL(222, DUP_VALUE);
}
