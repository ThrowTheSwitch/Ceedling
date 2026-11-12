#include "unity.h"
#include "ceedling.h"
#include TEST_PARTIAL_ALL_MODULE(tally)
#include "tally.h"

void test_tally(void) {
  TEST_ASSERT_EQUAL(1, tally());
  TEST_ASSERT_EQUAL(1, PARTIAL_LOCAL_VAR(tally, state).count);
}
