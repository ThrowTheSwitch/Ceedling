#include "unity.h"
#include "ceedling.h"
#include TEST_PARTIAL_ALL_MODULE(counter)
#include "counter.h"

void test_helloCounter(void) {
  TEST_ASSERT_EQUAL(1, helloCounter());
  TEST_ASSERT_EQUAL(2, helloCounter());
}
