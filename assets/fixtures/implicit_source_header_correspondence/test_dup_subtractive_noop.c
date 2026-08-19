#include "unity.h"
#include "alpha/dup.h"

// beta/dup.c is a real file in this project's source collection, but this
// test's own #include never causes it to be part of the compile/link list in
// the first place -- alpha/dup.h unambiguously resolves alpha/dup.c on its
// own. Removing a file that was never present changes nothing.
TEST_SOURCE_FILE("-:beta/dup.c")

void setUp(void) {}
void tearDown(void) {}

void test_dup_value_subtractive_noop(void)
{
  TEST_ASSERT_EQUAL(111, dup_value());
}
