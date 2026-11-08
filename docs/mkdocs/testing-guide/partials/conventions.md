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

Naming two same-named modules by directory lets one test file **test** both, and
**mock** both, as covered under [Naming a module by directory](directives.md#naming-a-module-by-directory).

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
lists of functions for testing and mocking, and the decorators are stripped
from the functions you select. What a Partial carries keeps its decorators, as
[described below](#what-a-partial-carries-from-your-module).

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

## What a Partial Carries From Your Module

A Partial brings along what your selected functions rely on. Your module's
code calls functions it only declares, and its header may define small
`static` or `inline` helpers. A Partial holding only the selected functions
would fail to compile or link without them. Ceedling copies them into the
Partial's generated implementation source, written as your module writes them.

### What is carried

A Partial carries three kinds of content beyond the functions you select.
Each comes along only when the code the Partial keeps uses it. The one
exception is a prototype of an inline function another header defines.

* **Prototypes of functions defined elsewhere.** Your module declares a
  function that another file defines. The prototype comes along when the
  Partial's code uses the function. A prototype that gives an inline function
  its external definition, described below, always comes along.
* **Prototypes of functions your test leaves out.** A test can subtract a
  function, such as `-engine_poll`, and define a stub of its own. The
  prototype comes along so a selected function calling it links to your stub.
* **Helpers your module header defines.** A `static` or `inline` function
  defined in the module header comes along when the Partial's code uses it.
  A use through a macro counts. So does a use by another helper that came
  along.

A function counts as used wherever the code names it. A call counts, and so
does taking its address, passing it as a callback, or listing it in a table of
handlers. A struct member, a parameter or a local variable that merely shares
a function's name does not count, and neither does a mention in a comment.

Each carried item keeps its original spelling and decorators. A carried helper
has any function-scope `static` promoted, as every function in a Partial does.
A line marker (`#line`) ahead of each item Ceedling can locate points back to
its original file and line, so compiler messages and coverage reports name your
own files.

!!! tip "See what a Partial carries"
    Run a test build with `--verbosity=debug` that generates the Partial, such
    as the first build after `ceedling clobber`. Each Partial lists what it
    carried and why.

### What is not carried

Some content stays behind, because carrying it could break a build that works.

* A helper the Partial's code never uses stays behind. Its own code never has
  to compile in the Partial.
* A prototype the Partial's code never uses stays behind. A header included
  later may define a macro of the same name, and the macro would mangle a
  prototype nothing needed.
* A function your module's source defines and your test does not select stays
  behind. That is what selecting a Partial means. A selected function that
  calls a `static` function in the source needs that function selected too.
  Add it with `+name`, or select the whole module with
  `TEST_PARTIAL_ALL_MODULE`.
* A `static` prototype stays behind unless its helper comes along.
* Nothing is added to a Partial's headers, so your test file sees only what
  the selection gives it. A test that calls a helper directly selects it with
  `+name`.

### Inline functions with an external definition

C99 gives an inline function its external definition through a declaration.
A header defines the function `inline`. One source file declares it
`extern inline`, `extern`, or with no `inline` at all. That source file's
object then holds the definition that an unoptimized call links to. A Partial
carries the declaration, so a test calling the function links.

Ceedling finds the inline body in the headers your source file includes. Under
[fallback preprocessing](#fallback-preprocessing) it cannot look there. Only a
declaration that says `inline` itself is then carried this way.

A Partial never mocks a function your module only declares when another header
defines it inline. The body lives in that header, which a mock cannot replace.
The Partial's implementation source carries the declaration instead.

A test that also mocks the module holding the inline body, as a Partial,
removes that body. Some compilers then warn that the inline function is not
defined. The mock supplies the definition, so the build still links.

### A module header without an include guard

A Partial stands in for your module header by defining that header's include
guard. A header guarded only by `#pragma once` has no guard to define. Another
header your module includes may pull the real header in again, helpers and
all. A carried copy of a helper would then collide with the real one.

A Partial therefore carries no helpers from a header without an include guard.
When it generates the Partial, it logs a notice naming the helpers the
Partial's code uses. Give the
header an include guard to have its helpers carried. Selecting a helper with
`+name` also works when no other header pulls the real header in.

### Repeated declarations

A carried prototype may repeat a declaration that one of your headers already
makes. That is valid C. Some builds warn about it with `-Wredundant-decls` and
fail on the warning with `-Werror`. Ceedling wraps carried prototypes in GCC
diagnostic pragmas that quiet that one warning for those lines alone. The
[`:partials` ↳ `:suppress_redundant_decls`](../../configuration/reference/partials.md#suppress_redundant_decls)
setting turns the wrapping off.

### Fallback preprocessing

[Fallback preprocessing](../conventions.md#fallback-test-build-preprocessing)
is best effort and only partially capable. It can keep two different copies of
one function, such as both sides of a conditional it cannot evaluate. A Partial
carries neither copy. When it generates the Partial, it logs a notice naming the
function. For a helper, the notice suggests selecting it with `+name`, which
selects the first copy.

## Function Pointers

A Partial reads function pointers in each common spelling, with or without a
typedef for their type. A function may take or return one. A module may hold
one, an array of them, or a pointer to an array. A Partial declares each such
variable with its whole type, so a test can assign it and call through it.

```c
void ticker_register(int (*cb)(int));   // a function taking a function pointer
int (*ticker_get(void))(int);           // a function returning one
static int (*s_hook)(int);              // a variable holding one
static int (*s_table[2])(int);          // an array of them
```

A table whose entries name `static` functions in your module's source needs
those functions selected too. Add them with `+name`, as for a selected function
that calls them.

A Partial reads each declaration as written, before macros expand. A macro that
spells part of a declarator can hide what the declaration names, as `WINAPI`
does in `void (WINAPI *fp)(int);`. Give such a function-pointer
type a name with a typedef and use the name in the declaration, or declare the
function directly. When a Partial finds no name at all for a function your
module defines, it stops the build with a message naming the definition.

<br/><br/>
