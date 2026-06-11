/* =========================================================================
 * Test — © 2024 Ünïcödé Corp.
 * Tests unicoder module using a mock. The mock is generated from unicoder.h
 * which contains non-ASCII UTF-8 characters in comments.
 * ========================================================================= */

#include "unity.h"
#include "mock_unicoder.h"

/* Verify that the mocked unicoder_greet() returns the expected value. */
void test_unicoder_greet_returns_expected_length(void)
{
    unicoder_greet_ExpectAndReturn(5);
    TEST_ASSERT_EQUAL(5, unicoder_greet());
}
