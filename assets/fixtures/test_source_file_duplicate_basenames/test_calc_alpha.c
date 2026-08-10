#include "unity.h"

// calc.c has no corresponding header; enough path is given here to identify
// alpha/calc.c specifically, distinct from beta/calc.c elsewhere in the project.
TEST_SOURCE_FILE("alpha/calc.c")

extern int calc_value(void);

void setUp(void) {}
void tearDown(void) {}

void test_calc_value_from_alpha(void)
{
  TEST_ASSERT_EQUAL(111, calc_value());
}
