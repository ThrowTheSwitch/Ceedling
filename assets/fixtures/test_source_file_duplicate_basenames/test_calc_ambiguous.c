#include "unity.h"

// calc.c has no corresponding header; deliberately bare (no disambiguating
// path) with two same-named calc.c files present in the project.
TEST_SOURCE_FILE("calc.c")

extern int calc_value(void);

void setUp(void) {}
void tearDown(void) {}

void test_calc_value(void)
{
  TEST_ASSERT_EQUAL(111, calc_value());
}
