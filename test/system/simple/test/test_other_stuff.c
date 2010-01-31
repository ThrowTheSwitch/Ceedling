#include "unity.h"
#include "other_stuff.h"


void setUp(void) {}
void tearDown(void) {}

// test successes

void test_add_should_succeed_1(void)
{
	TEST_ASSERT_EQUAL(100, add(30, 70));
}

void test_add_should_succeed_2(void)
{
	TEST_ASSERT_EQUAL(0, add(-5, 5));
}

// test failures

void test_fail()
{
  TEST_FAIL("Boom.");
}

void test_add_should_fail(void)
{
	TEST_ASSERT_EQUAL(0, add(2, 2));
}
