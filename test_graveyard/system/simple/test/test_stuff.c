#include "unity.h"
#include "stuff.h"


void setUp(void) {}
void tearDown(void) {}


// test ignores & variations on test declarations

void test_a_single_thing(void)
{
  TEST_IGNORE_MESSAGE("pay no attention to the test behind the curtain");
}

 void  test_another_thing ( void )
{
  TEST_IGNORE_MESSAGE("pay no attention to the test behind the curtain");
}

void test_some_non_void_param_stuff()
{
  TEST_IGNORE_MESSAGE("pay no attention to the test behind the curtain");
}

void
test_some_multiline_test_case_action
(void)
{
  TEST_IGNORE_MESSAGE("pay no attention to the test behind the curtain");
}

// test successes

void test_subtract_should_succeed_1(void)
{
	TEST_ASSERT_EQUAL(10, subtract(31, 21));
}

void test_subtract_should_succeed_2(void)
{
	TEST_ASSERT_EQUAL(0, subtract(12, 12));
}

// test failures

void test_subtract_should_fail(void)
{
	TEST_ASSERT_EQUAL(100, subtract(210, 109));
}

