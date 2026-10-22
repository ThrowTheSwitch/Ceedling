#include "unity.h"

// extra.c has no corresponding header; this test file lives one directory
// away from it, so resolving this directive exercises TEST_SOURCE_FILE()'s
// own anchor-relative .. resolution rather than the #include machinery.
TEST_SOURCE_FILE("../alpha/extra.c")

extern int extra_value(void);

void setUp(void) {}
void tearDown(void) {}

void test_extra_value_via_parent_directory_test_source_file(void)
{
  TEST_ASSERT_EQUAL(222, extra_value());
}
