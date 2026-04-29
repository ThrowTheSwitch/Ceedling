# Partials

A _Partial_ is your C code sliced and diced to expose functional elements 
for testing that you could not otherwise access without rewriting your 
source code. Think of Partials as a scalpel for testing your code.

Partials are useful when a module under test contains:

* **`static` or `inline` functions** — With Partials these become easily 
  accessible within your test code.
* **File-scoped `static` variables** — With Partials the `static` keyword 
  is stripped and the variable is automatically made `extern` so it can 
  be easily accessed within your test code.
* **Function-scoped `static` variables** — Partials promotes these from
  within function scope to module scope so they can be accessed in your
  test code. Apart from a necessary renaming, these work identically to
  file-scoped `static` variables.

## What Is a Partial?

Ceedling reads your real source and header files, extracts their C contents,
and generates new C files that comprise a Partial:

When creating a Partial, Ceedling:

1. Extracts your source code under test into a set of new C files in a special
   build directory.
1. Reorganizes and slightly alters your code so it can be accessed by your test.
   Functions are stripped of `static` and `inline`. Variables are stripped of
   `static`.
1. Structures the test build to omit the original source file from the 
   resulting test executable. Generated Partials are self-sufficient stand-ins 
   for the original C code from which the Partials are derived.
1. Maps the reorganized functions in generated Partials back to the 
   original source module’s filepath and line numbers (using GCC’s `#line` 
   directive) for correct test coverage reporting.

| Generated file | Role | Default filename pattern |
|---|---|---|
| **Partial implementation** header | Declares testable functions and `extern`s file-scope variables | `ceedling_partial_<module>_impl.h` |
| **Partial implementation** source | Defines testable functions and `static`-less variables | `ceedling_partial_<module>_impl.c` |
| **Partial interface** header | Declares mockable function signatures | `ceedling_partial_<module>_interface.h` |

These generated Partials files `#include` the same header files as the 
original files from which they are generated. They also contain all macros,
`typedef`s, user-defined types, etc. discovered in the original C code.

Ceedling uses CMock to generate mocks from Partials interface header files
just as it does for any other mockable header files.

When a test file references a Partial, Ceedling excludes the original source
file from that test executable‘s build. Only the generated Partial 
source is compiled and linked in its place.

## Simple Partials Example

Imagine a temperature sensor module.

```c
// sensor.h -----------------------------------------------
void Sensor_Init(void);
int  Sensor_ReadCelsius(void);
```

```c
// sensor.c -----------------------------------------------
#include "sensor.h"
#include "hal.h" // Hardware Abstraction Layer (to be mocked)

// Private helper -- static, not visible outside this translation unit
static int _ConvertRawToMilliCelsius(uint16_t raw)
{
    return (int)raw * 10 - 40000;
}

void Sensor_Init(void)
{
    HAL_SensorEnable();
}

int Sensor_ReadCelsius(void)
{
    uint16_t raw = HAL_SensorRead();
    return _ConvertRawToMilliCelsius(raw) / 1000;
}
```

### Testing & mocking `static` helper

You as a test author want to test and mock the `static` helper `_ConvertRawToMilliCelsius()`.

1. **Test** `_ConvertRawToMilliCelsius()` directly
2. **Mock** `_ConvertRawToMilliCelsius()` while testing `Sensor_ReadCelsius()`

Partials allows you to accomplish both of these goals with no changes to
_sensor.c_ even though `_ConvertRawToMilliCelsius()` is static.

!!! warning "A Function Cannot Be Both Tested and Mocked"
    A core restriction of the C language remains here! `_ConvertRawToMilliCelsius()`
    cannot be both tested and mocked in the same test. Attempting to do so would
    duplicate the function and cause a doubly-defined symbol failure during linking.
    We solve this by simply creating two peer test files for the different Partials
    usage scenarios.

### Example Testable Partial

```c
// test_sensor_partials_test.c -----------------------------------
#include "unity.h"
#include "ceedling.h" // Required -- defines Partial directive macros
#include "mock_hal.h" // Traditional mocking still available

// Make all functions in the sensor module available for direct testing
#include TEST_PARTIAL_ALL_MODULE(sensor)

// Test the `static` conversion helper internal to source module under test
void test_ConvertRawToMilliCelsius(void)
{
    // _ConvertRawToMilliCelsius is accessible in the Partial linked in this test executable build
    TEST_ASSERT_EQUAL_INT(-40000, _ConvertRawToMilliCelsius(0));
}
```
#### Partials processing step-by-step

1. Reads `sensor.c` and `sensor.h` and extracts all function definitions.
1. `TEST_PARTIAL_ALL_MODULE()` instructs Partial generation to gather and 
   expose all functions from the `sensor` module to be made testable.
1. Generates `ceedling_partial_sensor_impl.c` containing all source functions
   including `_ConvertRawToMilliCelsius()` (stripped of `static` decorator).
1. Compiles and links the Partial implementation source (in place of the original 
   `sensor` source module) and the test file into the test executable. The 
   symbols and includes of `sensor.h` and `sensor.c` are duplicated in the 
   Partials while the original `sensor.c` is omitted from the build.

### Example Mockable Partial

```c
// test_sensor_partials_mocks.c -----------------------------------
#include "unity.h"
#include "ceedling.h" // Required -- defines Partial directive macros
#include "mock_hal.h" // Traditional mocking still available

// Create two complementary Partials:
//  1. All the non-static functions for testing
//  2. Mocked static functions to be used in test cases
//
// We need both Partials with non-overlapping lists of functions in
// order to separate the testable functions from the mocked functions
// extracted from the same source module.

// Make all the non-static functions available for testing
#include TEST_PARTIAL_PUBLIC_MODULE(sensor)

// Make the static helper function available as a mock
#include MOCK_PARTIAL_PRIVATE_MODULE(sensor)

// Test Sensor_ReadCelsius() using a mock of the helper function
void test_Sensor_ReadCelsius(void)
{
    // Traditional mock of external HAL interface
    HAL_SensorRead_ExpectAndReturn(1234);

    // Partial mock of `static` function internal to source module under test
    _ConvertRawToMilliCelsius_ExpectAndReturn(1234, 1000);

    TEST_ASSERT_EQUAL_INT(1, Sensor_ReadCelsius());
}
```

#### Partials processing step-by-step

1. Reads `sensor.c` and `sensor.h`, extracts all function definitions.
1. Classifies `_ConvertRawToMilliCelsius` as **private** (from the `static`
   decorator).
1. Generates `ceedling_partial_sensor_interface.h` containing only
   `_ConvertRawToMilliCelsius()`.
1. Collects all non-static functions in the `sensor` module and
   generates `ceedling_partial_sensor_impl.h` and 
   `ceedling_partial_sensor_impl.c` containing those functions segragated
   from the mockable function signature organized in (3).
1. Runs CMock on the Partial interface header to produce mock source.
1. Compiles and links the mocked Partial interface source from (3), the 
   Partial implementation source from (4) in place of the original `sensor` 
   source module, and the test file into the test executable. The 
   symbols and includes of `sensor.h` and `sensor.c` are duplicated in the 
   Partials while the original `sensor.c` is omitted from the build.

## Conventions and Terminology

### Modules

In Ceedling Partials, a _module_ is a C source file, a C header file, or a matched
source + header pair sharing the same base filename. The base filename —
without its extension — is the _module name_.

| Files present | Module name |
|---|---|
| `sensor.c` and `sensor.h` | `sensor` |
| `sensor.h` only | `sensor` |
| `sensor.c` only | `sensor` |

When both a source file and a header file share a name, Ceedling treats them
as a single unit. Both files are read when generating a Partial. When only 
one file is present, only that file is read.

All Partial directive macros take a module name — a bare filename stem with
no extension and no path:

```c
// Module name: 'sensor'
// Not "sensor.c" or "path/to/sensor"
#include TEST_PARTIAL_PRIVATE_MODULE(sensor)
```

### Public and Private Functions

C has no access modifiers. Every function with external linkage is — from the
language‘s perspective — equally visible at link time. In the context of
Partials, Ceedling uses the more modern terms _public_ and _private_ to 
describe a practical distinction based on function decorators:

**Private functions** carry one or more of the following keywords anywhere in
their declaration or definition:

* `static`
* `inline`
* `__inline`
* `__inline__`

A `static` function has internal linkage. It is invisible to the linker
outside its containing translation unit, and therefore cannot be called or 
mocked from a test build without special handling. Inline functions may be 
folded away by the compiler entirely. Partials use decorators to organize
lists of functions for testing and mocking, but the decorators are stripped
in the resulting generated code.

**Public functions** are everything else — functions with no visibility-
restricting decorator and ordinary external linkage.

This public/private distinction is one set of filters for assembling a list
of functions each `_MODULE` macro selects. The filtering and collection is 
documented in detail in the 
[Partials function-selection by macro](#partials-function-selection-by-macro) section below.

## Partial Directive Macros

All Partial configuration is expressed through C macros placed
in your test file. No separate configuration file is required. The macros
require `#include "ceedling.h"` in the test file.

The Partial `_MODULE` macros accomplish the following:

1. Expand to a filename for the preceding `#include` directive.
1. Provide a module name for Ceedling to process for the resulting Partial.
1. Assemble a gross, base set of functions to test or mock.

The optional Partial `_CONFIG` macros modify the base set of functions 
from (3).

Example:

```c
#include "ceedling.h"

// Mock all `static` and/or `inline` functions of "mymodule" except `InternalHelper()`
#include MOCK_PARTIAL_PRIVATE_MODULE(mymodule)
MOCK_PARTIAL_CONFIG(mymodule, -_InternalHelper)
```

### `#include` conventions

The `_MODULE` macros each expand to a **string literal** that names a
generated header file. This means you use them as the argument to `#include`:

```c
// Must come first -- defines all Partial macros
#include "ceedling.h"

#include TEST_PARTIAL_*_MODULE(sensor)
//  ↑ expands to: #include "ceedling_partial_sensor_impl.h"
```

A `TEST_PARTIAL_*_MODULE` macro always names an implementation header.

```c
#include "ceedling.h"

#include MOCK_PARTIAL_*_MODULE(sensor)
//  ↑ expands to: #include "mock_ceedling_partial_sensor_interface.h"
```

A `MOCK_PARTIAL_*_MODULE` macro always names a mockable interface header.

!!! warning "Do Not Touch Generated Partials Files"
    In practice, you as the test author will never directly interact with the
    generated Partials C files. Do not reference them or modify them. These
    examples and explanation are solely for education and awareness.

The filters in place of `*` in the macro names — `PUBLIC`, `PRIVATE`, `ALL`, 
and none — tell Ceedling how to initialize internal function lists (that 
can be optionally modified) towards injecting the collected functions into 
each Partial. 

### Partials function-selection by macro

Each test or mock Partial is independently configured by exactly
one `_MODULE` macro call. The macro determines the _base set_ of
functions that Ceedling collects towards generating a Partial. Once
the base set of functions is determined, explicit additions or 
subtractions can be applied with `_CONFIG` macros.

This scheme gives you the, test author, full control of which functions
are injected into which type of Partial while avoiding laboriously
listing each function individually.

#### Partials base function filters

| Macro | Base set of functions | Additions | Subtractions |
|---|---|---|---|
| `[TEST/MOCK]_PARTIAL_PUBLIC_MODULE(mod)` | All public functions | Add private | Remove public |
| `[TEST/MOCK]_PARTIAL_PRIVATE_MODULE(mod)` | All private functions | Add public | Remove private |
| `[TEST/MOCK]_PARTIAL_MODULE(mod)` | Empty | Any function (at least one) | Forbidden |
| `[TEST/MOCK]_PARTIAL_ALL_MODULE(mod)` | All functions | Forbidden | Any function |

**Notes:**
* `*_PARTIAL_MODULE` requires at least one addition via `*_PARTIAL_CONFIG` 
  (see next section).
* `*_PARTIAL_ALL_MODULE` with no subtractions adds every module function to
  base set of functions.
* Each module can appear in **at most one** `TEST_PARTIAL_*_MODULE` and 
  `MOCK_PARTIAL_*_MODULE` macro within a given test file.

#### Partials function list configuration macros

`TEST_PARTIAL_CONFIG` and `MOCK_PARTIAL_CONFIG` refine the base set of functions
filtered by the corresponding `_MODULE` macro. Both `_CONFIG` macros require at 
least one function name argument beyond the module name.

Note that no quotation marks are needed.

```c
TEST_PARTIAL_CONFIG(module, func1, func2, ...)
MOCK_PARTIAL_CONFIG(module, func1, func2, ...)
```

Similar to the convenion in Ceedling’s `paths:` and `files:` YAML configuration 
sections, each function name argument is treated as an **addition** or a 
**subtraction** depending on an optional prefix character:

| Prefix | Meaning |
|---|---|
| _(none)_ or `+` | Add this function to the Partial (`+<function>`) |
| `-` | Exclude this function from the Partial (`-<function>`) |

**Addition & subtraction rules by mode:**

| Macro | Filter | Subtraction target | Addition target |
|---|---|---|---|
| `[TEST/MOCK]_PARTIAL_PUBLIC_MODULE` | Public | Public functions only | Private functions |
| `[TEST/MOCK]_PARTIAL_PRIVATE_MODULE` | Private | Private functions only | Public functions |
| `[TEST/MOCK]_PARTIAL_MODULE` | Accumulate | Forbidden | Any function (one required) |
| `[TEST/MOCK]_PARTIAL_ALL_MODULE` | Deduct | Any function | Forbidden |

### `TEST_` / `MOCK_` Partials exclusion

Any function explicitly added on one side via a Partial `_CONFIG` macro is 
**automatically removed** from the complementary function list (if it exists).
This prevents the same function from accidentally appearing both in a Partial 
implementation and Partial mock, which would produce a duplicate symbol linker 
error.

```c
// _InternalHelper added to the test side while automatically removed from the mock side.
#include TEST_PARTIAL_PRIVATE_MODULE(mymodule)
TEST_PARTIAL_CONFIG(mymodule, _InternalHelper)

// _InternalHelper will NOT appear in the mock
#include MOCK_PARTIAL_PUBLIC_MODULE(mymodule)
```

### Partials configuration examples

#### Test a specific private function; Mock everything else

```c
#include "ceedling.h"

#include TEST_PARTIAL_MODULE(sensor)     // Starts empty
TEST_PARTIAL_CONFIG(sensor, _ConvertRaw) // Add exactly this one function

#include MOCK_PARTIAL_ALL_MODULE(sensor) // Starts with all functions
// _ConvertRaw is automatically excluded from the Partial mock
```

#### Test all functions except one; Mock nothing

```c
#include "ceedling.h"

#include TEST_PARTIAL_ALL_MODULE(sensor)  // All functions
TEST_PARTIAL_CONFIG(sensor, -Sensor_Init) // Subtract one
```

#### Test public functions plus one private helper; Mock selected private functions

```c
#include "ceedling.h"

// Test: start with all public functions, add one private function
#include TEST_PARTIAL_PUBLIC_MODULE(sensor)
TEST_PARTIAL_CONFIG(sensor, _ConvertRaw)

// Mock: Start with no functions, add a private function
#include MOCK_PARTIAL_MODULE(sensor)
MOCK_PARTIAL_CONFIG(sensor, _ReadIOValue)
```

## Accessing Static Variables with Partials

### File-Scoped Static Variables

A file-scoped `static` variable is declared at the top level of a `.c` file
with the `static` keyword. Like a `static` function, it has _internal linkage_ 
-- the linker cannot see it outside the translation unit in which it is defined.
This means test code in a separate translation unit cannot read or write it,
making it impossible to inspect state or reset it between test cases without
modifying the production source.

When Ceedling generates a Partial it automatically copies every file-scoped 
`static` variable found in the source module into the Partial and strips the 
`static` keyword. The resulting definition in the generated `_impl.c` file 
has external linkage. A matching `extern` declaration is emitted in the 
generated `_impl.h` header. Including any `TEST_PARTIAL_*_MODULE` macro brings 
that `extern` declaration into scope, causing the variable to accessible in 
test code directly by its **original name** — no renaming or helper macro is 
required.

#### Partial file-scoped static variable example

Extending the sensor module with a file-scoped error counter:

```c
// sensor.c -----------------------------------------------
static uint32_t g_error_count = 0; // File-scoped; invisible outside sensor.c

int Sensor_ReadCelsius(void)
{
    uint16_t raw = HAL_SensorRead();
    if (raw == 0xFFFF) { // sentinel value signals hardware error
        g_error_count++;
        return -1;
    }
    return _ConvertRawToMilliCelsius(raw) / 1000;
}
```

Ceedling strips `static` when generating the test Partial:

```c
// ceedling_partial_sensor_impl.c (generated) ---------------
uint32_t g_error_count = 0; // `static` stripped -- now has external linkage
// ...
int Sensor_ReadCelsius(void)
{
    uint16_t raw = HAL_SensorRead();
    if (raw == 0xFFFF) {
        g_error_count++;
        return -1;
    }
    return _ConvertRawToMilliCelsius(raw) / 1000;
}
```

```c
// ceedling_partial_sensor_impl.h (generated) ---------------
extern uint32_t g_error_count; // `extern` declaration -- immediately available in test code
// ...
```

Because `#include TEST_PARIAL_*_MODULE()` automatically causes the generated
Partial header file to be included in your test, the `extern`ed variable is
immediately available to you in your test.

In the test file, the variable is accessed directly by its original name:

```c
// test_sensor_partial.c -----------------------------------
#include "unity.h"
#include "ceedling.h"
#include "mock_hal.h"

// Brings `extern g_error_count` into scope
#include TEST_PARTIAL_ALL_MODULE(sensor)

void setUp(void) {
    g_error_count = 0; // Reset to known state before each test
}

void test_ReadCelsius_counts_hardware_errors(void)
{
    HAL_SensorRead_ExpectAndReturn(0xFFFF); // Simulate hardware error
    TEST_ASSERT_EQUAL_INT(-1, Sensor_ReadCelsius());
    // Access the previously inaccessible `g_error_count`
    TEST_ASSERT_EQUAL_UINT32(1, g_error_count);
}
```

### Function-scoped static variables

C allows variables to be declared `static` inside a function body. Unlike a
local variable, a function-scoped `static` variable persists across calls —
its storage is allocated once and retains its value for the lifetime of the
program. This persistence makes these variables useful for call counters, 
cached state, accumulated error totals, etc.

In ordinary C, a function-scoped `static` variable is completely inaccessible
outside its containing function; the C standard does not provide any way to
take its address or read its value from another translation unit. This makes
it impossible to inspect or reset it from a test.

When Ceedling generates a Partial, it automatically promotes all function-scoped
`static` variables to module scope in the generated implementation files.
The original declaration inside the function body is replaced with a no-op
statement so that source line mappings for coverage reporting remain accurate.

#### Renaming to prevent collisions

Multiple functions in the same module may each contain a function-scoped
`static` variable with the same name — for example, both `Foo_Init()` and
`Foo_Reset()` might each have `static uint32_t call_count = 0;`. Promoting
both to module scope without renaming would produce a duplicate symbol error
at compilation.

Ceedling resolves this by prepending a prefix of `partial_` and the containing
function’s name to each promoted variable’s name:

```
partial_<function_name>_<variable_name>
```

Example renaming:

| Original declaration (inside function) | Containing function | Promoted name |
|---|---|---|
| `static uint32_t call_count = 0;` | `Sensor_ReadCelsius` | `partial_Sensor_ReadCelsius_call_count` |
| `static bool initialized = false;` | `Sensor_Init` | `partial_Sensor_Init_initialized` |
| `static int error_count;` | `Sensor_Init` | `partial_Sensor_Init_error_count` |

The promoted variable is defined in the generated implementation source
(`ceedling_partial_<module>_impl.c`) and declared `extern` in the generated
implementation header (`ceedling_partial_<module>_impl.h`). Including the
implementation header via a `TEST_PARTIAL_*_MODULE` macro therefore makes all
promoted variables available to your test code.

#### `PARTIAL_LOCAL_VAR()` macro to access promoted function-scoped static variables

Typing `partial_Sensor_ReadCelsius_call_count` throughout a test file is
error-prone. The `PARTIAL_LOCAL_VAR` macro, defined in `ceedling.h`, assembles
the promoted name from its two components:

```c
PARTIAL_LOCAL_VAR(function_name, variable_name)
// expands to: partial_<function_name>_<variable_name>
```

`PARTIAL_LOCAL_VAR()` is not a function call. The macro expands to a simple 
C identifier. It can appear anywhere a variable name is legal — in expressions, 
assertions, and assignments.

#### Example use of `PARTIAL_LOCAL_VAR()`

Extending the sensor module from earlier examples:

```c
// sensor.c -----------------------------------------------
int Sensor_ReadCelsius(void)
{
    // Function-scoped static variable that tracks total calls
    static uint32_t sample_count = 0;
    sample_count++;

    uint16_t raw = HAL_SensorRead();
    return _ConvertRawToMilliCelsius(raw) / 1000;
}
```

Ceedling promotes `sample_count` to `partial_Sensor_ReadCelsius_sample_count`.

In the copy of `Sensor_ReadCelsius()` organized in a generated Partial, 
Ceedling replaces the variable declaration inside the function with a no-op
to preserve code coverage line tracking.

```c
// ceedling_partial_sensor_impl.c (generated) ---------------
// ...
int Sensor_ReadCelsius(void)
{
    (void)0; /* static uint32_t sample_count = 0 */
    partial_Sensor_ReadCelsius_sample_count++;

    uint16_t raw = HAL_SensorRead();
    return _ConvertRawToMilliCelsius(raw) / 1000;
}
```
Ceedling simultaneously organizes an `extern` statement in the generated 
Partial header file.

```c
// ceedling_partial_sensor_impl.h (generated) ---------------
// ...
extern uint32_t partial_Sensor_ReadCelsius_sample_count;
// ...
```

Because `#include TEST_PARIAL_*_MODULE()` automatically causes the generated
Partial header file to be included in your test, the promoted, renamed, and
`extern`ed variable is immediately available to you in your test.

In your test file, `PARTIAL_LOCAL_VAR()` makes the variable accessible for both
reset and assertion:

```c
// test_sensor_partial.c -----------------------------------
#include "unity.h"
#include "ceedling.h"
#include TEST_PARTIAL_PRIVATE_MODULE(sensor)

void setUp(void)
{
    // Reset promoted static back to its initial value before each test
    PARTIAL_LOCAL_VAR(Sensor_ReadCelsius, sample_count) = 0;
}

void test_ReadCelsius_increments_sample_count_on_each_call(void)
{
    HAL_SensorRead_ExpectAndReturn(1000);
    Sensor_ReadCelsius();
    TEST_ASSERT_EQUAL_UINT32(1, PARTIAL_LOCAL_VAR(Sensor_ReadCelsius, sample_count));

    HAL_SensorRead_ExpectAndReturn(2000);
    Sensor_ReadCelsius();
    TEST_ASSERT_EQUAL_UINT32(2, PARTIAL_LOCAL_VAR(Sensor_ReadCelsius, sample_count));
}
```

#### What `PARTIAL_LOCAL_VAR()` cannot do

`PARTIAL_LOCAL_VAR` is a token-pasting macro — it constructs a C identifier at
compile time. It cannot be used with a runtime string or a variable holding a
function name. Both arguments must be literal tokens that match the original
C identifiers exactly (the function name and the variable name as they appear
in the source file).
