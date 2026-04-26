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

### Super simple passing test case

```c
#include "unity.h"

void test_case(void) {
   TEST_ASSERT_TRUE( (1 == 1) );
}
```

### Super simple failing test case

```c
#include "unity.h"

void test_a_different_case(void) {
   TEST_ASSERT_TRUE( (1 == 2) );
}
```

### Realistic simple test case

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

### Sample test case output

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

### Advanced test cases with mocks

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

### That was the basics, but you'll need more

For more on the assertions and mocking shown above, consult the 
documentation for [Unity] and [CMock] or the resources in
Ceedling's [README](/README.md).

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

<br/>

# Commented Sample Test File

**Here is a beautiful test file to help get you started…**

## Core concepts in code

After absorbing this sample code, you'll have context for much
of the documentation that follows.

The sample test file below demonstrates the following:

1. Making use of the Unity & CMock test frameworks.
1. Adding the source under test (`foo.c`) to the final test 
   executable by convention (`#include "foo.h"`).
1. Adding two mocks to the final test executable by convention
   (`#include "mock_bar.h` and `#include "mock_baz.h`).
1. Adding a source file with no matching header file to the test 
   executable with a test build directive macro 
   `TEST_SOURCE_FILE("more.c")`.
1. Creating two test cases with mock expectations and Unity
   assertions.

All other conventions and features are documented in the sections
that follow.

```c
// test_foo.c -----------------------------------------------
#include "unity.h"     // Compile/link in Unity test framework
#include "types.h"     // Header file with no *.c file -- no compilation/linking
#include "foo.h"       // Corresponding source file, foo.c, under test will be compiled and linked
#include "mock_bar.h"  // bar.h will be found and mocked as mock_bar.c + compiled/linked in;
#include "mock_baz.h"  // baz.h will be found and mocked as mock_baz.c + compiled/linked in

TEST_SOURCE_FILE("more.c") // foo.c depends on symbols from more.c, but more.c has no matching more.h

void setUp(void) {}    // Every test file requires this function;
                       // setUp() is called by the generated runner before each test case function

void tearDown(void) {} // Every test file requires this function;
                       // tearDown() is called by the generated runner after each test case function

// A test case function
void test_Foo_Function1_should_Call_Bar_AndGrill(void)
{
    Bar_AndGrill_Expect();                    // Function from mock_bar.c that instructs our mocking 
                                              // framework to expect Bar_AndGrill() to be called once
    TEST_ASSERT_EQUAL(0xFF, Foo_Function1()); // Foo_Function1() is under test (Unity assertion):
                                              //  (a) Calls Bar_AndGrill() from bar.h
                                              //  (b) Returns a byte compared to 0xFF
}

// Another test case function
void test_Foo_Function2_should_Call_Baz_Tec(void)
{
    Baz_Tec_ExpectAnd_Return(1);       // Function from mock_baz.c that instructs our mocking
                                       // framework to expect Baz_Tec() to be called once and return 1
    TEST_ASSERT_TRUE(Foo_Function2()); // Foo_Function2() is under test (Unity assertion)
                                       //  (a) Calls Baz_Tec() in baz.h
                                       //  (b) Returns a value that can be compared to boolean true
}

// end of test_foo.c ----------------------------------------
```

## Ceedling actions from the sample test code

From the test file specified above Ceedling will generate 
`test_foo_runner.c`. This runner file will contain `main()` and will call 
both of the example test case functions.

The final test executable will be `test_foo.exe` (Windows) or `test_foo.out` 
for Unix-based systems (extensions are configurable. Based on the `#include` 
list and test directive macro above, the test executable will be the output 
of the linker having processed `unity.o`, `foo.o`, `mock_bar.o`, `mock_baz.o`, 
`more.o`, `test_foo.o`, and `test_foo_runner.o`. 

Ceedling finds the needed code files, generates mocks, generates a runner, 
compiles all the code files, and links everything into the test executable. 
Ceedling will then run the test executable and collect test results from it 
to be reported to the developer at the command line.

## Incidentally, Ceedling comes with example projects

Ceedling comes with entire example projects you can extract.

1. Execute `ceedling examples` in your terminal to list available example 
   projects.
1. Execute `ceedling example <project> [destination]` to extract the 
   named example project.

You can inspect the _project.yml_ file and source & test code. Run 
`ceedling help` from the root of the example projects to see what you can
do, or just go nuts with `ceedling test:all`.

<br/>

# Anatomy of a Test Suite

A Ceedling test suite is composed of one or more individual test executables.

The [Unity] project provides the actual framework for test case assertions 
and unit test sucess/failure accounting. If mocks are enabled, [CMock] builds 
on Unity to generate mock functions from source header files with expectation
test accounting. Ceedling is the glue that combines these frameworks, your
project's toolchain, and your source code into a collection of test 
executables you can run as a singular suite.

## What is a test executable?

Put simply, in a Ceedling test suite, each test file becomes a test executable.
Your test code file becomes a single test executable.

`test_foo.c` ➡️ `test_foo.out` (or `test_foo.exe` on Windows)

A single test executable generally comprises the following. Each item in this
list is a C file compiled into an object file. The entire list is linked into
a final test executable.

* One or more release C code files under test (`foo.c`)
* `unity.c`.
* A test C code file (`test_foo.c`).
* A generated test runner C code file (`test_foo_runner.c`). `main()` is located
  in the runner.
* If using mocks:
   * `cmock.c`
   * One more mock C code files generated from source header files (`mock_bar.c`)

## Why multiple individual test executables in a suite?

For several reasons:

* This greatly simplifies the building of your tests.
* C lacks any concept of namespaces or reflection abilities able to segment and 
  distinguish test cases.
* This allows the same release code to be built differently under different
  testing scenarios. Think of how different `#define`s, compiler flags, and
  linked libraries might come in handy for different tests of the same 
  release C code. One source file can be built and tested in different ways
  with multiple test files.

## Ceedling's role in your test suite

A test executable is not all that hard to create by hand, but it can be tedious,
repetitive, and error-prone.

What Ceedling provides is an ability to perform the process repeatedly and simply 
at the push of a button, alleviating the tedium and any forgetfulness. Just as 
importantly, Ceedling also does all the work of running each of those test 
executables and tallying all the test results.

<br/>
