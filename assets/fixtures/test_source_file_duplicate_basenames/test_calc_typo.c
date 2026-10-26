#include "unity.h"

// Misspells alpha/calc.c on purpose, so no source file matches this entry.
TEST_SOURCE_FILE("alpha/clac.c")

extern int calc_value(void);

void setUp(void) {}
void tearDown(void) {}

void test_calc_value_from_a_misspelled_source(void)
{
  TEST_ASSERT_EQUAL(111, calc_value());
}
