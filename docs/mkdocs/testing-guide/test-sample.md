# Commented Sample Test File

**Here is a beautiful test file to help get you started…**

!!! note "This sample test only illustrates basic assertions and mocks"
    Dealing with complex and legacy code may require the use of
    [Partials](partials/index.md) for accessing `static` / `inline` 
    functions and `static` variables. Partials allow you to test these 
    C elements without rewriting your source code.

## Core concepts in code

After absorbing this sample code, you'll have context for much
of the rest of the documentation.

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

!!! tip "Example projects"
    Ceedling’s built-in [example projects](../getting-started/example-projects/index.md)
    provide fully working code for your reference and learning. The examples span 
    test assertions, mocks, partials, release builds, and system & embedded 
    programming.

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

## Ceedling actions

From the test file specified above Ceedling will generate 
`test_foo_runner.c`. This runner file will contain `main()` and will call 
both of the example test case functions.

The final test executable will be `test_foo.exe` (Windows) or `test_foo.out` 
for Unix-based systems (extensions are configurable). Based on the `#include` 
list and test directive macro above, the test executable will be the output 
of the linker having processed `unity.o`, `foo.o`, `mock_bar.o`, `mock_baz.o`, 
`more.o`, `test_foo.o`, and `test_foo_runner.o`. 

Ceedling finds the needed code files, generates mocks, generates a runner, 
compiles all the code files, and links everything into the test executable. 
Ceedling will then run the test executable and collect test results from it 
to be reported to the developer at the command line.

<br/><br/>
