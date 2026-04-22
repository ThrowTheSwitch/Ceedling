# Partials

> **Draft** — proposed new top-level section for `CeedlingPacket.md`.
> Insert before the **Build Directive Macros** section.
> Update the **Contents** table and its anchor links accordingly.

---

A _Partial_ is a pair of generated C files that Ceedling synthesises from an
existing C module (source + header) so that otherwise inaccessible parts of
the module can be cleanly tested and mocked within a single test build.

Partials are useful when a module contains:

* **Private functions** — declared `static` or `inline`, invisible to the
  linker and therefore to CMock.
* **Public functions** that you want to mock in one test but exercise directly
  in another, all within the same test executable.
* **Function-scoped `static` variables** — Ceedling promotes these to
  module scope in the generated implementation so that linker and coverage
  tools see them correctly.

## What Is a Partial?

Ceedling reads your real source and header files, extracts their C contents,
and writes two generated files for each partialized module:

| Generated file | Role | Default filename pattern |
|---|---|---|
| **Partial implementation** header | Declares the selected testable functions | `ceedling_partial_<module>_impl.h` |
| **Partial implementation** source | Defines the selected testable functions | `ceedling_partial_<module>_impl.c` |
| **Partial interface** header | Declares the selected mockable function signatures | `ceedling_partial_<module>_interface.h` |

CMock generates a mock from the interface header using the same convention
it uses for ordinary headers:

| Mock file | Default filename pattern |
|---|---|
| Generated CMock mock | `mock_ceedling_partial_<module>_interface.h` / `.c` |

> **Note:** The `ceedling_partial_` prefix and the `mock_` prefix are
> configurable via `CEEDLING_PARTIALS_PREFIX` and `CMOCK_MOCK_PREFIX` in
> your project compilation symbols. The defaults shown here match those
> defaults.

When a test file references a Partial, Ceedling excludes the original source
file from that test executable's build. Only the generated implementation
source is compiled in its place.

## A Simple Example

Consider a temperature sensor module:

```c
// sensor.h -----------------------------------------------
void Sensor_Init(void);
int  Sensor_ReadCelsius(void);
```

```c
// sensor.c -----------------------------------------------
#include "sensor.h"
#include "hal.h"        // hardware abstraction layer — to be mocked

// Private helper — static, not visible outside this translation unit
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

A test file that wants to:
1. **Test** `_ConvertRawToMilliCelsius()` directly (it is private / `static`)
2. **Mock** the public API `Sensor_Init` and `Sensor_ReadCelsius` when testing
   a higher-level module that calls them

```c
// test_sensor_partial.c -----------------------------------
#include "unity.h"
#include "ceedling.h"   // Required: defines Partial directive macros

// Make private functions available for direct testing
#include TEST_PARTIAL_PRIVATE_MODULE("sensor")

// Make the public API available as a mock
#include MOCK_PARTIAL_PUBLIC_MODULE("sensor")

void setUp(void)    {}
void tearDown(void) {}

// Test the private conversion helper directly
void test_ConvertRawToMilliCelsius_at_zero_raw(void)
{
    // _ConvertRawToMilliCelsius is now visible because it is in the
    // generated partial implementation that was compiled into this build.
    TEST_ASSERT_EQUAL_INT(-40000, _ConvertRawToMilliCelsius(0));
}

// Test the higher-level caller using a mock of the public API
void test_Application_uses_sensor(void)
{
    Sensor_ReadCelsius_ExpectAndReturn(25);   // from mock_ceedling_partial_sensor_interface
    // ... call the code under test that uses Sensor_ReadCelsius() ...
}
```

### What Ceedling does with this test file

1. Reads `sensor.c` and `sensor.h`, extracts all function definitions.
2. Classifies `_ConvertRawToMilliCelsius` as **private** (it is `static`)
   and `Sensor_Init`/`Sensor_ReadCelsius` as **public**.
3. Generates `ceedling_partial_sensor_impl.c` containing only
   `_ConvertRawToMilliCelsius` (the private function requested for testing).
4. Generates `ceedling_partial_sensor_interface.h` containing declarations
   for `Sensor_Init` and `Sensor_ReadCelsius` (the public functions to mock).
5. Runs CMock on the interface header to produce mock source.
6. Compiles the partial implementation source, the mock source, and the test
   file into the test executable — **without** compiling the original
   `sensor.c`.

## Conventions and Terminology

### Modules

In Ceedling, a _module_ is a C source file, a C header file, or a matched
source + header pair sharing the same base filename. The base filename —
without its extension — is the _module name_.

| Files present | Module name |
|---|---|
| `sensor.c` and `sensor.h` | `sensor` |
| `sensor.h` only | `sensor` |
| `sensor.c` only | `sensor` |

When both a source file and a header file share a name, Ceedling treats them
as a single module. Both files are read when generating a Partial: the source
file supplies function definitions (with bodies) and the header file supplies
any additional declarations. When only one file is present, only that file is
read.

All Partial directive macros take a module name — a bare filename stem with
no extension and no path:

```c
#include TEST_PARTIAL_PRIVATE_MODULE("sensor")   // module name: sensor
                                                 // NOT "sensor.c", NOT "path/to/sensor"
```

### Public and Private Functions

C has no access modifiers. Every function with external linkage is — from the
language's perspective — equally visible at link time. In the context of
Partials, Ceedling uses the terms _public_ and _private_ to describe a
practical distinction based on function decorators:

**Private functions** carry one or more of the following keywords anywhere in
their declaration or definition:

* `static`
* `inline`
* `__inline`
* `__inline__`

A `static` function has internal linkage: it is invisible to the linker
outside its translation unit, and therefore cannot be called or mocked from a
test build without special handling. Inline functions may be folded away by the
compiler entirely. Partials surface both kinds so that they can be tested or
mocked directly.

**Public functions** are everything else — functions with no visibility-
restricting decorator and ordinary external linkage.

This public/private distinction determines the base set of functions that
each `_MODULE` macro selects. It is documented in detail in the
[Function-selection modes](#function-selection-modes) section below.

## Partial Directive Macros

All Partial configuration is expressed through C preprocessor macros directly
in your test file. No separate configuration file is required. The macros
require `#include "ceedling.h"` — or equivalently `#include <ceedling.h>` —
to be present in the test file.

### `#include` conventions for Partial macros

The `_MODULE` macros each expand to a **string literal** that names a
generated header file. This means you use them as the argument to `#include`:

```c
#include "ceedling.h"  // Must come first — defines all Partial macros

#include TEST_PARTIAL_PRIVATE_MODULE("sensor")
//  ↑ expands to: #include "ceedling_partial_sensor_impl.h"

#include MOCK_PARTIAL_PUBLIC_MODULE("sensor")
//  ↑ expands to: #include "mock_ceedling_partial_sensor_interface.h"
```

A `TEST_PARTIAL_*_MODULE` macro always names an implementation header;
a `MOCK_PARTIAL_*_MODULE` macro always names a CMock mock header. The mode
(`PUBLIC`, `PRIVATE`, `MODULE`, `ALL_MODULE`) tells Ceedling _which_ functions
to put into each generated file — the `#include` path itself is identical for
all modes on the same side.

### Function-selection modes

Each side (test / mock) of a Partial is independently configured by exactly
one `_MODULE` macro call. The macro name determines the _base set_ of
functions that Ceedling places in the generated file before any explicit
additions or subtractions are applied.

**"Private" functions** are those decorated with any of `static`, `inline`,
`__inline`, or `__inline__`. **"Public" functions** are everything else.

#### Test side (`TEST_PARTIAL_*_MODULE`)

| Macro | Mode | Base set | Additions | Subtractions |
|---|---|---|---|---|
| `TEST_PARTIAL_PUBLIC_MODULE(mod)` | PUBLIC | All public functions | Cross-visibility (private) | Same-visibility (public) only |
| `TEST_PARTIAL_PRIVATE_MODULE(mod)` | PRIVATE | All private functions | Cross-visibility (public) | Same-visibility (private) only |
| `TEST_PARTIAL_MODULE(mod)` | ACCUMULATE | _(empty — additions-only)_ | Required; any function | Forbidden |
| `TEST_PARTIAL_ALL_MODULE(mod)` | DEDUCT | All functions (public + private) | Forbidden | Any function |

#### Mock side (`MOCK_PARTIAL_*_MODULE`)

| Macro | Mode | Base set | Additions | Subtractions |
|---|---|---|---|---|
| `MOCK_PARTIAL_PUBLIC_MODULE(mod)` | PUBLIC | All public functions | Cross-visibility (private) | Same-visibility (public) only |
| `MOCK_PARTIAL_PRIVATE_MODULE(mod)` | PRIVATE | All private functions | Cross-visibility (public) | Same-visibility (private) only |
| `MOCK_PARTIAL_MODULE(mod)` | ACCUMULATE | _(empty — additions-only)_ | Required; any function | Forbidden |
| `MOCK_PARTIAL_ALL_MODULE(mod)` | DEDUCT | All functions (public + private) | Forbidden | Any function |

> **Notes:**
> * `TEST_PARTIAL_MODULE` (ACCUMULATE) requires at least one addition via
>   `TEST_PARTIAL_CONFIG`; the same applies to `MOCK_PARTIAL_MODULE`.
> * `TEST_PARTIAL_ALL_MODULE` / `MOCK_PARTIAL_ALL_MODULE` (DEDUCT) with no
>   subtractions means "include every function".
> * Each module can appear in **at most one** `_MODULE` macro call per side
>   within a given test file.

### Configuration macros

`TEST_PARTIAL_CONFIG` and `MOCK_PARTIAL_CONFIG` refine the base set selected
by the corresponding `_MODULE` macro. Both macros require at least one function
name argument beyond the module name.

```c
TEST_PARTIAL_CONFIG("module", func1, func2, ...)
MOCK_PARTIAL_CONFIG("module", func1, func2, ...)
```

Each function name argument is treated as an **addition** or a **subtraction**
depending on an optional prefix character:

| Prefix | Meaning | Allowed modes |
|---|---|---|
| _(none)_ or `+` | Addition — include this function | PUBLIC, PRIVATE, ACCUMULATE |
| `-` | Subtraction — exclude this function | PUBLIC, PRIVATE, DEDUCT |

**Subtraction rules by mode:**

| Mode | Subtraction target | Addition target |
|---|---|---|
| PUBLIC | Public functions only | Private functions (cross-visibility) |
| PRIVATE | Private functions only | Public functions (cross-visibility) |
| ACCUMULATE | Forbidden | Any function (required) |
| DEDUCT | Any function | Forbidden |

### Cross-side exclusion

Any function explicitly added on one side via `_CONFIG` is **automatically
removed** from the other side's result. This prevents the same function from
appearing both in the partial implementation (compiled into the test build) and
in the mock (also compiled into the test build), which would produce a duplicate
symbol linker error.

```c
// _InternalHelper is added to the test side — Ceedling automatically
// removes it from the mock side even if it would otherwise be included there.
#include TEST_PARTIAL_PRIVATE_MODULE("mymodule")
TEST_PARTIAL_CONFIG("mymodule", "_InternalHelper")

#include MOCK_PARTIAL_PUBLIC_MODULE("mymodule")
// _InternalHelper will NOT appear in the mock regardless of its visibility
```

### Combining macros — worked examples

#### Test private functions; mock all public functions

```c
#include "ceedling.h"
#include TEST_PARTIAL_PRIVATE_MODULE("sensor")   // base: all private functions
#include MOCK_PARTIAL_PUBLIC_MODULE("sensor")    // base: all public functions
```

#### Test a specific private function; mock everything else

```c
#include "ceedling.h"
#include TEST_PARTIAL_MODULE("sensor")           // ACCUMULATE: starts empty
TEST_PARTIAL_CONFIG("sensor", "_ConvertRaw")    // add exactly this one function

#include MOCK_PARTIAL_ALL_MODULE("sensor")       // DEDUCT: starts with all functions
// _ConvertRaw is automatically excluded from mock because it was added to tests
```

#### Test all functions except one; mock nothing

```c
#include "ceedling.h"
#include TEST_PARTIAL_ALL_MODULE("sensor")       // DEDUCT: all functions
TEST_PARTIAL_CONFIG("sensor", "-Sensor_Init")   // subtract one
// No MOCK_PARTIAL_*_MODULE call — mock side disabled for this module
```

#### Test public functions plus one private helper; mock selected privates

```c
#include "ceedling.h"

// Test: start with all public functions, add one private
#include TEST_PARTIAL_PUBLIC_MODULE("sensor")
TEST_PARTIAL_CONFIG("sensor", "_ConvertRaw")

// Mock: start with all private functions, remove the one claimed by tests
#include MOCK_PARTIAL_PRIVATE_MODULE("sensor")
// _ConvertRaw is automatically excluded from mock (cross-side exclusion)
```

## Accessing Function-Scoped Static Variables

C allows variables to be declared `static` inside a function body. Unlike a
local variable, a function-scoped `static` variable persists across calls —
its storage is allocated once and retains its value for the lifetime of the
program. This persistence makes these variables useful for things like call
counters, cached state, and accumulated error totals.

In ordinary C, a function-scoped `static` variable is completely inaccessible
outside its containing function; the C standard does not provide any way to
take its address or read its value from another translation unit. This makes
it impossible to inspect or reset it from a test.

When Ceedling generates a Partial, it automatically promotes all function-scoped
`static` variables to module scope in the generated implementation files.
The original declaration inside the function body is replaced with a no-op
statement so that source line mappings for coverage reporting remain accurate.

### Renaming to prevent collisions

Multiple functions in the same module may each contain a function-scoped
`static` variable with the same name — for example, both `Foo_Init()` and
`Foo_Reset()` might each have `static uint32_t call_count = 0;`. Promoting
both to module scope without renaming would produce a duplicate symbol error.

Ceedling resolves this by prepending a prefix of `partial_` and the containing
function's name to each promoted variable's name:

```
partial_<function_name>_<variable_name>
```

For example:

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

### The `PARTIAL_LOCAL_VAR` macro

Typing `partial_Sensor_ReadCelsius_call_count` throughout a test file is
error-prone. The `PARTIAL_LOCAL_VAR` macro, defined in `ceedling.h`, assembles
the promoted name from its two components:

```c
PARTIAL_LOCAL_VAR(function_name, variable_name)
// expands to:
//   partial_##function_name##_##variable_name
```

`PARTIAL_LOCAL_VAR` is not a function call — it expands to a plain C identifier.
It can appear anywhere a variable name is legal: in expressions, assertions,
and assignments.

### Example

Extending the sensor module from the earlier example:

```c
// sensor.c -----------------------------------------------
int Sensor_ReadCelsius(void)
{
    static uint32_t sample_count = 0;  // tracks total calls
    sample_count++;

    uint16_t raw = HAL_SensorRead();
    return _ConvertRawToMilliCelsius(raw) / 1000;
}
```

Ceedling promotes `sample_count` to `partial_Sensor_ReadCelsius_sample_count`
and replaces the declaration inside the function with a no-op:

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

```c
// ceedling_partial_sensor_impl.h (generated) ---------------
// ...
extern uint32_t partial_Sensor_ReadCelsius_sample_count;
// ...
```

In the test file, `PARTIAL_LOCAL_VAR` makes the variable accessible for both
reset and assertion:

```c
// test_sensor_partial.c -----------------------------------
#include "unity.h"
#include "ceedling.h"
#include TEST_PARTIAL_PRIVATE_MODULE("sensor")
#include MOCK_PARTIAL_PUBLIC_MODULE("sensor")

void setUp(void)
{
    // Reset promoted static back to its initial value before each test
    PARTIAL_LOCAL_VAR(Sensor_ReadCelsius, sample_count) = 0;
}

void tearDown(void) {}

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

### What `PARTIAL_LOCAL_VAR` cannot do

`PARTIAL_LOCAL_VAR` is a token-pasting macro — it constructs a C identifier at
compile time. It cannot be used with a runtime string or a variable holding a
function name. Both arguments must be literal tokens that match the original
C identifiers exactly (the function name and the variable name as they appear
in the source file).
