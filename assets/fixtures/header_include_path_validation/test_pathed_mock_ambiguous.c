#include "unity.h"
#include "drivers/mock_foo.h"

// Disambiguates by path what test_ambiguous_mock.c leaves bare -- selects
// src/drivers/foo.h specifically, not src/alt_drivers/foo.h (the bare default).

void setUp(void) {}
void tearDown(void) {}

void test_foo_value_pathed_mock_ambiguous(void)
{
  foo_value_ExpectAndReturn(111);
  TEST_ASSERT_EQUAL(111, foo_value());
}
