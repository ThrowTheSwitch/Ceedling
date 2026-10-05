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

All Partial directive macros take a module name — a bare filename stem with no
extension and no quotation marks:

```c
// Module name: 'sensor'
// Not "sensor.c" (no quotation marks) and not "path/to/sensor" (see below)
#include TEST_PARTIAL_PRIVATE_MODULE(sensor)
```

### Distinguishing a module by directory

A module name without path information, can ambiguously names multiple files 
whenever a project holds multiple modules of the same name in different 
directories. The `_AT` variant of every `_MODULE` macro takes that module's 
directory as a separate first argument:

```c
// Two sensors, each with its own Calibration module
#include TEST_PARTIAL_PRIVATE_MODULE_AT(sensors/soil, Calibration)
#include TEST_PARTIAL_PRIVATE_MODULE_AT(sensors/light, Calibration)
```

The directory is matched against the trailing end of a real file's path, so you
supply only as much of it as it takes to distinguish the module you mean.
`sensors/soil` and `soil` both reach `src/sensors/soil/Calibration.c` as long as
no other module's path also ends that way.

The directory is written as bare text, like the module name — no quotation marks
— and it is relative, never absolute. A Partial is generated relative to the
project root.

The directory must be the macro's own first argument. Writing a path inside the
module argument of a bare macro instead does not work, for reasons covered in
[Rules for the directory argument](directives.md#rules-for-the-directory-argument).

Naming a directory is optional. A bare module name using a non-`_AT` macros is
sufficient when no duplicate modules exist. And, when multiple modules are 
present, it continues to resolve the way a compiler's own header search does — 
the first match among the ordered search paths wins.

Naming two same-named modules by directory lets one test file **test** both. It
cannot **mock** both — a limitation of how CMock names a mock's contents, covered
under [Naming a module by
directory](directives.md#naming-a-module-by-directory).

!!! tip "When Ceedling cannot tell two modules apart"
    A bare module name matching more than one module is reported with the
    candidates Ceedling found and the `_AT` macro that resolves it. The message
    names the modules as you would write them, not the generated files.

## Public / Private Functions

C has no access modifiers. Every function with external linkage is — from the
language's perspective — equally visible at link time. In the context of
Partials, Ceedling uses the more modern terms _public_ and _private_ to 
describe a practical distinction based on function decorators:

### Private functions

“Private” functions carry one or more of the following keywords anywhere in
their declaration or definition:

* `static`
* `inline`
* `__inline`
* `__inline__`
* `__forceinline`

A `static` function has internal linkage. It is invisible to the linker
outside its containing translation unit, and therefore cannot be called or 
mocked from a test build without special handling. `inline` functions may be 
folded away by the compiler entirely. Partials use decorators to organize
lists of functions for testing and mocking, but the decorators are stripped
in the resulting generated code.

!!! note "Because of preproccesing only the “private” keywords are recognized"
    The preprocesing steps that are part of generating Partials expand any
    macros (e.g. `INLINE` or `STATICINLINE`) to the actual keywords decorating
    function signatures. As such, only the keywords above must be handled.

### Public functions

“Public” functions are everything else — functions with no visibility-
restricting decorator and ordinary external linkage.

This public/private distinction is one set of filters for assembling a list
of functions each `_MODULE` macro selects. The filtering and collection is 
documented in detail in the 
[Partials function-selection by macro](directives.md#partials-function-selection-by-macro) section.

<br/><br/>
