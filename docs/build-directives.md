# Build Directive Macros

## Overview of Build Directive Macros

Ceedling supports a small number of build directive macros. At present,
these macros are only for use in test files.

By placing these macros in your test files, you may control aspects of an 
individual test executable's build from within the test file itself.

These macros are actually defined in Unity, but they evaluate to empty 
strings. That is, the macros do nothing and only serve as text markers for 
Ceedling to parse. But, by placing them in your test files they 
communicate instructions to Ceedling when scanned at the beginning of a 
test build.

**_Notes:_**

- Since these macros are defined in _unity.h_, it's essential to 
  `#include "unity.h"` before making use of them in your test file. 
  Typically, _unity.h_ is referenced at or near the top of a test file
  anyhow, but this is an important detail to call out.
- **`TEST_SOURCE_FILE()` and `TEST_INCLUDE_PATH()`, new in Ceedling 
  1.0.0, are incompatible with enclosing conditional compilation C 
  preprocessing statements.** See
  [Ceedling's preprocessing documentation](conventions.md#preprocessing-gotchas) 
  for more details.

## `TEST_SOURCE_FILE()`

### `TEST_SOURCE_FILE()` Purpose

The `TEST_SOURCE_FILE()` build directive allows the simple injection of 
a specific source file into a test executable's build.

The Ceedling [convention](conventions.md) of compiling and linking 
any C file that corresponds in name to an `#include`d header file does 
not always work. A given source file may not have a header file that 
corresponds directly to its name. In some specialized cases, a source 
file may not rely on a header file at all.

Attempting to `#include` a needed C source file directly is both ugly and
can cause various build problems with duplicated symbols, etc.

`TEST_SOURCE_FILE()` is the way to cleanly and simply add a given C file
to the executable built from a test file. `TEST_SOURCE_FILE()` is also one 
of the best methods for adding an assembly file to the build of a given 
test executable—if assembly support is enabled for test builds.

### `TEST_SOURCE_FILE()` Usage

The argument for the `TEST_SOURCE_FILE()` build directive macro is a 
single filename or filepath as a string enclosed in quotation marks. Use
forward slashes for path separators. The filename or filepath must be 
present within Ceedling's source file collection.

To understand your source file collection:

- See the documentation for project file configuration section 
  [`:paths`](configuration/reference/paths.md).
- Dump a listing your project's source files with the command line task
  `ceedling files:source`.

Multiple uses of `TEST_SOURCE_FILE()` are perfectly fine. You'll likely
want one per line within your test file.

### `TEST_SOURCE_FILE()` Example

```c
/*
 * Test file test_mycode.c to exercise functions in mycode.c.
 */
 
#include "unity.h"    // Contains TEST_SOURCE_FILE() definition
#include "support.h"  // Needed symbols and macros
//#include "mycode.h" // Header file corresponding to mycode.c by convention does not exist

// Tell Ceedling to compile and link mycode.c as part of the test_mycode executable
TEST_SOURCE_FILE("foo/bar/mycode.c")

// --- Unit test framework calls ---

void setUp(void) {
  ...
}

void test_MyCode_FooBar(void) {
  ...
}
```

## `TEST_INCLUDE_PATH()`

### `TEST_INCLUDE_PATH()` Purpose

The `TEST_INCLUDE_PATH()` build directive allows a header search path to
be injected into the build of an individual test executable.

Unless you have a pretty funky C project, generally at least one search path entry
is necessary for every test executable build. That path can come from a `:paths`  
↳ `:include` entry in your project configuration or by using `TEST_INCLUDE_PATH()` 
in a test file.

Please see [Configuring Your Header File Search Paths](conventions.md#search-paths-for-test-builds)
for an overview of Ceedling's options and conventions for header file search paths.

### `TEST_INCLUDE_PATH()` Usage

`TEST_INCLUDE_PATH()` entries in your test file are only an additive customization.
The path will be added to the base / common path list specified by 
`:paths`  ↳ `:include` in the project file. If no list is specified in your project 
configuration, `TEST_INCLUDE_PATH()` entries will comprise the entire header search 
path list.

The argument for the `TEST_INCLUDE_PATH()` build directive macro is a single 
filepath as a string enclosed in quotation marks. Use forward slashes for 
path separators.

**_Note_**: At present, a limitation of the `TEST_INCLUDE_PATH()` build directive 
macro is that paths are relative to the working directory from which you are 
executing `ceedling`. A change to your working directory could require updates to 
the path arguments of dall instances of `TEST_INCLUDE_PATH()`.

Multiple uses of `TEST_INCLUDE_PATH()` are perfectly fine. You'll likely want one 
per line within your test file.

### `TEST_INCLUDE_PATH()` Example

```c
/*
 * Test file test_mycode.c to exercise functions in mycode.c.
 */

#include "unity.h"    // Contains TEST_INCLUDE_PATH() definition
#include "somefile.h" // Needed symbols and macros

// Add the following to the compiler's -I search paths used to
// compile all components comprising the test_mycode executable.
TEST_INCLUDE_PATH("foo/bar/")
TEST_INCLUDE_PATH("/usr/local/include/baz/")

// --- Unit test framework calls ---

void setUp(void) {
  ...
}

void test_MyCode_FooBar(void) {
  ...
}
```

<br/>
