#include "unity.h"
#include "a_file.h"
#include "mock_stuff.h"
#include "mock_other_stuff.h"


void setUp(void) {}
void tearDown(void) {}


void test_a_function_should_pass_with_values_that_make_sense(void)
{
	add_ExpectAndReturn(3, 5, 8);
	subtract_ExpectAndReturn(8, 2, 6);
	
  TEST_ASSERT_EQUAL(6, a_function(3, 5, 2));
}

void test_a_function_should_pass_because_we_lied_with_our_mocks(void)
{
	add_ExpectAndReturn(0, 0, 0);
	subtract_ExpectAndReturn(0, 0, 100);
	
  TEST_ASSERT_EQUAL(100, a_function(0, 0, 0));
}

void test_a_function_should_fail_because_missing_expectation(void)
{
	subtract_ExpectAndReturn(0, 0, 100);
	
  TEST_ASSERT_EQUAL(100, a_function(0, 0, 0));
}

void test_a_function_should_fail_because_wrong_return_value(void)
{
	add_ExpectAndReturn(3, 5, 8);
	subtract_ExpectAndReturn(8, 2, 0);
	
  TEST_ASSERT_EQUAL(6, a_function(3, 5, 2));
}

