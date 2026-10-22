#include "unity.h"

// calc.c has no corresponding header; enough path is given here to identify
// beta/calc.c specifically, distinct from alpha/calc.c elsewhere in the project.
TEST_SOURCE_FILE("beta/calc.c")

extern int calc_value(void);

void setUp(void) {}
void tearDown(void) {}

void test_calc_value_from_beta(void)
{
  TEST_ASSERT_EQUAL(222, calc_value());
}
