#include "unity.h"
#include "dup.h"

// A bare #include "dup.h" would, on its own, implicitly resolve to the first
// candidate by search-path order (alpha/dup.c, returning 111). This
// TEST_SOURCE_FILE() entry names beta/dup.c specifically -- the same basename,
// stem-matched against the header's own implied source -- so it should
// override that implicit resolution rather than merely adding a second,
// separately-compiled dup.c alongside it (which would fail to link: both
// alpha/dup.c and beta/dup.c define dup_value()).
TEST_SOURCE_FILE("beta/dup.c")

void setUp(void) {}
void tearDown(void) {}

void test_dup_value_overridden_by_test_source_file(void)
{
  TEST_ASSERT_EQUAL(222, dup_value());
}
