# Partial Directive Macros

All Partial configuration is expressed through C macros placed
in your test file. No separate configuration file is required. The macros
require `#include "ceedling.h"` present in the test file above and before
their use.

The [Partial `_MODULE` macros](#partials-function-selection-by-macro) accomplish the following:

1. Expand to a filename for the preceding `#include` directive.
1. Provide a module name for Ceedling to process for the resulting Partial.
1. Assemble a base set of functions to test or mock.

The optional Partial `_CONFIG` macros modify the base set of functions 
from (3). Modifying a base set of functions is documented in detail in the
[Partials function list configuration macros](#partials-function-list-configuration-macros)
section.

## Directive Macros Example

```c
// Required before we can use the Partials directive macros
#include "ceedling.h"

// Mock all `static` and/or `inline` functions of `mymodule`
#include MOCK_PARTIAL_PRIVATE_MODULE(mymodule)

// But, remove `InternalHelper()` from the mocks
MOCK_PARTIAL_CONFIG(mymodule, -_InternalHelper)
```

!!! tip "Enable obnoxious level logging to inspect Partials generation"
    Add `--verbosity obnoxious` (or `-v 4`) to your `test:` command line invocation
    for detailed logging of the C extraction and Partials generations for your test
    build. The logged lists of functions and variables can help you fine tune or
    troubleshoot your Partials configuration.

## `#include` conventions

The `_MODULE` macros each expand to a **string literal** that names a
generated header file. This means you use them as the argument to `#include`:

```c
// Must come first -- defines all Partial macros
#include "ceedling.h"

#include TEST_PARTIAL_*_MODULE(sensor)
// ↑ Expands to: #include "ceedling_partial_sensor_impl.h"
```

A `TEST_PARTIAL_*_MODULE` macro always names an implementation header.

```c
#include "ceedling.h"

#include MOCK_PARTIAL_*_MODULE(sensor)
// ↑ Expands to: #include "mock_ceedling_partial_sensor_interface.h"
```

A `MOCK_PARTIAL_*_MODULE` macro always names a mockable interface header.

The filters in place of `*` in the macro names — `PUBLIC`, `PRIVATE`, `ALL`, 
and none — tell Ceedling how to initialize internal function lists (that 
can be optionally modified) towards injecting the collected functions into 
each Partial. 

## Partials function-selection by macro

Each test or mock Partial is independently configured by exactly
one `_MODULE` macro call. The macro determines the _base set_ of
functions that Ceedling collects towards generating a Partial. Once
the base set of functions is determined, explicit additions or 
subtractions can be applied with `_CONFIG` macros.

This scheme gives you the, test author, full control of which functions
are injected into which type of Partial while avoiding laboriously
listing each function individually.

### Partials base function filters

* `[TEST/MOCK]_PARTIAL_ALL_MODULE()`
* `[TEST/MOCK]_PARTIAL_PUBLIC_MODULE()`
* `[TEST/MOCK]_PARTIAL_PRIVATE_MODULE()`
* `[TEST/MOCK]_PARTIAL_MODULE()`

| Macro | Base set of functions | Additions | Subtractions |
|---:|---|---|---|
| `_ALL_MODULE` | All functions | Forbidden | Any function |
| `_PUBLIC_MODULE` | All public functions | Add private | Remove public |
| `_PRIVATE_MODULE` | All private functions | Add public | Remove private |
| `_MODULE` | Empty | Any function (at least one) | Forbidden |

#### Example base sets of function by filter

| Functions | `ALL` | `PUBLIC` | `PRIVATE` | None |
|---:|---|---|---|---|
| void foo(void) | foo | foo | bar | |
| static void bar(void) | bar | baz | oof | |
| int baz(void) | baz | | | |
| inline int oof(int) | oof | | | |

**Notes:**

* `*_PARTIAL_MODULE` requires at least one addition via `*_PARTIAL_CONFIG` 
  (see next section).
* `*_PARTIAL_ALL_MODULE` with no subtractions adds every module function to
  base set of functions.
* Each module can appear in **at most one** `TEST_PARTIAL_*_MODULE` and 
  `MOCK_PARTIAL_*_MODULE` macro within a given test file.

### Partials function list configuration macros

`TEST_PARTIAL_CONFIG` and `MOCK_PARTIAL_CONFIG` refine the base set of functions
filtered by the corresponding `_MODULE` macro. Both `_CONFIG` macros require at 
least one function name argument beyond the module name.

Note that no quotation marks are needed.

```c
TEST_PARTIAL_CONFIG(module, func1, func2, ...)
MOCK_PARTIAL_CONFIG(module, func1, func2, ...)
```

Similar to the convenion in Ceedling‘s `paths:` and `files:` YAML configuration 
sections, each function name argument is treated as an **addition** or a 
**subtraction** depending on an optional prefix character:

| Prefix | Meaning |
|---:|---|
| _(none)_ or `+` | Add this function to the Partial<br/>(`<function>` or `+<function>`) |
| `-` | Exclude this function from the Partial<br/>(`-<function>`) |

```c
TEST_PARTIAL_CONFIG(module, +func1, +func2, -func3)
MOCK_PARTIAL_CONFIG(module,  func1,  func2, -func3)
```

#### Addition & subtraction rules by mode

| Macro | Filter | Subtraction target | Addition target |
|---:|---|---|---|
| `_PUBLIC_MODULE` | Public | Public functions only | Private functions |
| `_PRIVATE_MODULE` | Private | Private functions only | Public functions |
| `_MODULE` | Accumulate | Forbidden | Any function (one required) |
| `_ALL_MODULE` | Deduct | Any function | Forbidden |

## `TEST_` / `MOCK_` Partials exclusion

Any function explicitly added on one side via a Partial `_CONFIG` macro is 
**automatically removed** from the complementary function list (if it exists).
This prevents the same function from accidentally appearing both in a Partial 
implementation and Partial mock, which would produce a duplicate symbol linker 
error.

```c
// `_InternalHelper()` added to the test side
// while automatically removed from the mock side.
#include TEST_PARTIAL_PRIVATE_MODULE(mymodule)
TEST_PARTIAL_CONFIG(mymodule, _InternalHelper)

// `_InternalHelper()` will NOT appear in the mock.
#include MOCK_PARTIAL_PUBLIC_MODULE(mymodule)
```

## Partials configuration examples

### Test a specific private function; Mock everything else

```c
#include "ceedling.h"

#include TEST_PARTIAL_MODULE(sensor)     // Starts empty
TEST_PARTIAL_CONFIG(sensor, _ConvertRaw) // Add exactly this one function

#include MOCK_PARTIAL_ALL_MODULE(sensor) // Starts with all functions
// `_ConvertRaw()` is automatically excluded from the Partial mock
```

### Test all functions except one; Mock nothing

```c
#include "ceedling.h"

#include TEST_PARTIAL_ALL_MODULE(sensor)  // All functions
TEST_PARTIAL_CONFIG(sensor, -Sensor_Init) // Subtract one
```

### Test public functions plus one private helper; Mock selected private functions

```c
#include "ceedling.h"

// Test: Start with all public functions
//       and add one private function
#include TEST_PARTIAL_PUBLIC_MODULE(sensor)
TEST_PARTIAL_CONFIG(sensor, _ConvertRaw)

// Mock: Start with no functions
//       and add a private function
#include MOCK_PARTIAL_MODULE(sensor)
MOCK_PARTIAL_CONFIG(sensor, _ReadIOValue)
```
