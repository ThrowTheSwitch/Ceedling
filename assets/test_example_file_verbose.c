#include "unity.h"
#include "example_file.h"
#include <stdio.h>

void setUp(void) {}
void tearDown(void) {}

void test_add_numbers_adds_numbers(void) {
  printf("1 + 1 = 2\n");
  TEST_ASSERT_EQUAL(2, add_numbers(1,1));
}

