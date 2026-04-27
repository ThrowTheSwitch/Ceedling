# How Does a Test Case Even Work?

## Behold assertions

In its simplest form, a test case is just a C function with no 
parameters and no return value that packages up logical assertions. 
If no assertions fail, the test case passes. Technically, an empty
test case function is a passing test since there can be no failing
assertions.

Ceedling relies on the [Unity] project for its unit test framework
(i.e. the thing that provides assertions and counts up passing
and failing tests).

An assertion is simply a logical comparison of expected and actual
values. Unity provides a wide variety of different assertions to 
cover just about any scenario you might encounter. Getting 
assertions right is actually a bit tricky. Unity does all that 
hard work for you and has been thoroughly tested itself and battle
hardened through use by many, many developers.

## Super simple passing test case

```c
#include "unity.h"

void test_case(void) {
   TEST_ASSERT_TRUE( (1 == 1) );
}
```

## Super simple failing test case

```c
#include "unity.h"

void test_a_different_case(void) {
   TEST_ASSERT_TRUE( (1 == 2) );
}
```

## Realistic simple test case

In reality, we're probably not testing the static value of an integer 
against itself. Instead, we're calling functions in our source code
and making assertions against return values.

```c
#include "unity.h"
#include "my_math.h"

void test_some_sums(void) {
   TEST_ASSERT_EQUALS(   5, mySum(  2,   3) );
   TEST_ASSERT_EQUALS(   6, mySum(  0,   6) );
   TEST_ASSERT_EQUALS( -12, mySum( 20, -32) );
}
```

If an assertion fails, the test case fails. As soon as an assertion
fails, execution within that test case stops.

Multiple test cases can live in the same test file. When all the
test cases are run, their results are tallied into simple pass
and fail metrics with a bit of metadata for failing test cases such 
as line numbers and names of test cases.

Ceedling and Unity work together to both automatically run your test
cases and tally up all the results.

## Sample test case output

Successful test suite run:

```
--------------------
OVERALL TEST SUMMARY
--------------------
TESTED:  49
PASSED:  49
FAILED:   0
IGNORED:  0
```

A test suite with a failing test:

```
-------------------
FAILED TEST SUMMARY
-------------------
[test/TestModel.c]
  Test: testInitShouldCallSchedulerAndTemperatureFilterInit
  At line (21): "Function TaskScheduler_Init() called more times than expected."

--------------------
OVERALL TEST SUMMARY
--------------------
TESTED:  49
PASSED:  48
FAILED:   1
IGNORED:  0
```

## Advanced test cases with mocks

Often you want to test not just what a function returns but how
it interacts with other functions.

The simple test cases above work well at the "edges" of a 
codebase (libraries, state management, some kinds of I/O, etc.). 
But, in the messy middle of your code, code calls other code. 
One way to handle testing this is with [mock functions][mocks] and
[interaction-based testing][interaction-based-tests].

Mock functions are functions with the same interface as the real 
code the mocks replace. A mocked function allows you to control 
how it behaves and wrap up assertions within a higher level idea 
of expectations.

What is meant by an expectation? Well… We _expect_ a certain 
function is called with certain arguments and that it will return
certain values. With the appropriate code inside a mocked function 
all of this can be managed and checked.

You can write your own mocks, of course. But, it's generally better 
to rely on something else to do it for you. Ceedling uses the [CMock] 
framework to perform mocking for you.

Here's some sample code you might want to test:

```c
#include "other_code.h"

void doTheThingYo(mode_t input) {
   mode_t result = processMode(input);
   if (result == MODE_3) {
      setOutput(OUTPUT_F);
   }
   else {
      setOutput(OUTPUT_D);
   } 
}
```

And, here's what test cases using mocks for that code could look 
like:

```c
#include "mock_other_code.h"

void test_doTheThingYo_should_enableOutputF(void) {
   // Mocks
   processMode_ExpectAndReturn(MODE_1, MODE_3);
   setOutput_Expect(OUTPUT_F);

   // Function under test
   doTheThingYo(MODE_1);
}

void test_doTheThingYo_should_enableOutputD(void) {
   // Mocks
   processMode_ExpectAndReturn(MODE_2, MODE_4);
   setOutput_Expect(OUTPUT_D);

   // Function under test
   doTheThingYo(MODE_2);
}
```

Remember, the generated mock code you can't see here has a whole bunch 
of smarts and Unity assertions inside it. CMock scans header files and
then generates mocks (C code) from the function signatures it finds in
those header files. It's kinda magical.

## That was the basics, but you'll need more

For more on the assertions and mocking shown above, consult the 
documentation for [Unity] and [CMock] or the resources in
Ceedling's [README](https://github.com/ThrowTheSwitch/Ceedling/blob/master/README.md).

Ceedling, Unity, and CMock rely on a variety of
[conventions to make your life easier][conventions-and-behaviors].
Read up on these to understand how to build up test cases
and test suites.

Also take a look at the very next sections for more examples
and details on how everything fits together.

[Unity]: http://github.com/ThrowTheSwitch/Unity
[CMock]: http://github.com/ThrowTheSwitch/CMock
[mocks]: https://blog.pragmatists.com/test-doubles-fakes-mocks-and-stubs-1a7491dfa3da
[interaction-based-tests]: http://martinfowler.com/articles/mocksArentStubs.html
[conventions-and-behaviors]: conventions.md
