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

!!! note "Decorators a macro supplies are recognized too"
    Generating a Partial expands your module's macros to see the keywords
    behind them, so a macro such as `PRIVATE` or `STATICINLINE` works as the
    keyword it stands for. A function a macro makes `static` is written from
    its expanded signature, and every line of its body keeps its place. A
    variable a macro makes `static` loses `static` the same way.

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
A mock keeps its own share of your header, as
[described below](#what-a-mock-partial-keeps-from-your-header).

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

## What a Mock Partial Keeps From Your Header

A Mock Partial keeps the rest of your module header for the code that includes
it. Its interface header stands in for your real header wherever your test
build includes it, and CMock mocks only the functions you select. Code that
includes your header may still use the rest of it, such as a `static inline`
helper, a `static const` table, an `extern` variable, or a function you leave
unmocked. A module your test mocks but doesn't test keeps that content in a
header of its own, `ceedling_partial_<module>_extras.h`.

The interface header includes the extras header where your header's own
declarations end, so a kept helper can call a mocked function your header
declares. CMock never reads the extras header, so nothing in it becomes a
mock. Your test file sees what it keeps too, through the mock.

!!! tip "See what a mock keeps"
    Run a test build with `--verbosity=debug` that generates the Partial, such
    as the first build after `ceedling clobber`. Each mock lists what it kept.

### What is kept

* **Helpers your header defines.** Each `static` or `inline` function in your
  header that your test doesn't mock is kept as your header writes it. A
  function-scope `static` in it is promoted, as in every Partial.
* **`static` variables your header defines.**
* **`extern` declarations** of variables, as your header writes them.
* **Prototypes of functions your test doesn't mock.**

### What is left out

Some content stays behind, because keeping it could break a build that works.

* Anything your module's source defines. A mock stands in for your header
  alone.
* A variable your header defines without `static`. Every file that includes
  the header would define it again.
* A `static` or `inline` prototype whose helper isn't kept.
* A prototype that a function-like macro of the same name rewrites, since
  calls use the macro.
* A `static` variable, or a `static` helper that isn't `inline`, that names a
  function your module declares and your test doesn't mock. Your test build may
  hold no definition of that function. A compiler can emit such an item even
  where nothing uses it, and the test would fail to link. An item that names
  anything left out this way stays behind too.
* Under [fallback preprocessing](#fallback-preprocessing), an item with two
  different copies, such as both sides of a conditional. Identical copies are
  kept once. An item that names a function with two different prototypes stays
  behind too, `inline` helpers included.

### A mocked header without an include guard

A header without an include guard can still arrive through another include,
helpers and all, as it can for a
[Test Partial](#a-module-header-without-an-include-guard). A kept copy of a
helper or a `static` variable would then collide with the real one. A mock of
such a header keeps only its `extern` declarations and prototypes. When it
generates the Partial, Ceedling logs a notice naming the helpers and variables
the mock leaves behind. Give the header an include guard to have them kept.
`#pragma once` is not an include guard. Ceedling relies on include guards to
stand a mock in for a header, so a `#pragma once` header is treated as one
without a guard.

### A module both tested and mocked

A module that one test both tests and mocks gets no extras header. Its
implementation source carries what its own code uses, as
[described above](#what-a-partial-carries-from-your-module). Another Partial in
that test that includes the module's header gets the mock's interface in its
place, which declares only the mocked functions. Code in that Partial that uses
the header's helpers or `static` variables fails to compile or link.

When it generates the Partial, Ceedling logs a notice naming what the other
Partials use. Two changes work around it:

1. Test the module in a test file of its own, and only mock it in this one.
1. Move what the other Partials use into a header your module header includes.
   The mock keeps that header's `#include`.

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
does in `void (WINAPI *fp)(int);`. For a function pointer, give its type a name
with a typedef and use the name in the declaration. For a function a macro
declares, declare the function directly. When a Partial finds no name at all
for a function your module defines, it stops the build with a message naming
the definition.

<br/><br/>
