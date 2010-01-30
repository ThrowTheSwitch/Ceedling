#include "unity.h"
#include "other_stuff.h"
#include "mock_a_file.h"
#include "another_file.h"


void setUp(void) {}
void tearDown(void) {}


/*
void test_some_stuff(void)
{
  TEST_IGNORE_MESSAGE("pay no attention to the test behind the curtain");
}

void test_some_more_stuff ( void )
{
  TEST_IGNORE_MESSAGE("pay no attention to the test behind the curtain");
}
*/

void test()
{
  TEST_IGNORE_MESSAGE("pay no attention to the test behind the curtain");
}

void test_fail()
{
  TEST_FAIL("Boom.");
}
