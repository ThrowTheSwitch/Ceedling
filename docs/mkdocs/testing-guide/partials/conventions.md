# Conventions and Terminology

## Modules

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

## Public / Private Functions

C has no access modifiers. Every function with external linkage is — from the
language's perspective — equally visible at link time. In the context of
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
[Partials function-selection by macro](directives.md#partials-function-selection-by-macro) section.
