#include "unity.h"
#include "alpha/dup.h"

// alpha/dup.h unambiguously resolves alpha/dup.c via the implicit
// header/source convention on its own -- no ambiguity, and no other
// TEST_SOURCE_FILE() entry here shares its "dup" basename, so the separate
// basename-stem override mechanism never enters into this at all. This entry
// removes that implicit match outright, and a second, differently-named
// entry supplies a replacement implementation instead.
TEST_SOURCE_FILE("-:alpha/dup.c")
TEST_SOURCE_FILE("gamma/dup_gamma.c")

void setUp(void) {}
void tearDown(void) {}

void test_dup_value_subtracted_in_favor_of_gamma(void)
{
  TEST_ASSERT_EQUAL(333, dup_value());
}
