# Test Build Directive Macros Reference

For detailed usage guidance, purpose explanations, and examples for these
macros, see [Test Build Directive Macros](../testing-guide/build-directives.md).

Both macros are defined in `unity.h` and evaluate to empty strings at compile
time — they serve only as text markers for Ceedling's scanner. `#include "unity.h"`
must appear above their use in a test file.

!!! warning "Incompatible with conditional preprocessor blocks"
    `TEST_SOURCE_FILE()` and `TEST_INCLUDE_PATH()` cannot be enclosed in
    `#ifdef` or other conditional compilation preprocessor statements. See
    [preprocessing gotchas](../testing-guide/conventions.md#preprocessing-gotchas)
    for details.

## `TEST_SOURCE_FILE("filepath")`

Inject a specific source file into a test executable's build. Use this when
a source file has no corresponding header file that Ceedling can discover by
convention, or when you need to explicitly include an assembly file (`.s`) in
a test build that has assembly support enabled.

- Argument: a filepath string using forward slashes
- The file must exist within Ceedling's source file collection
- Multiple uses per test file are allowed, one per line

## `TEST_INCLUDE_PATH("path")`

Add a header search path to an individual test executable's compiler
invocation. This supplements — it does not replace — the `:paths` ↳ `:include`
entries from your project file.

- Argument: a path string using forward slashes
- Paths are relative to the working directory from which `ceedling` is executed
- Multiple uses per test file are allowed, one per line

<br/><br/>
