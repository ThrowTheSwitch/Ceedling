#include "unity.h"
#include "stuff.h"
#include "mock_another_file.h"
#include "a_file.h"


void setUp(void) {}
void tearDown(void) {}


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

void test_success(void)
{
	TEST_ASSERT(1);
}
