#include "unity.h"
#include "reader.h"

// A macro names the mock, so only the preprocessor sees this #include
#define WIDGET_MOCK "mock_widget.h"
#include WIDGET_MOCK

void test_reader_returns_the_widget_reading(void)
{
  widget_read_ExpectAndReturn( 7 );

  TEST_ASSERT_EQUAL( 7, reader() );
}
