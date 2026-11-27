# Partials

A Partial directive's `#include` reaches its Partial through a route, which Ceedling writes from the directive's own text. The compiler never expands a directive's module directory or module. Each Partial sits at its module's build subpath, so its place follows the header the compiler resolves. A Partial's own includes are pinned, and an include of another Partial module's header is remapped to that module's Partial header.

## Contents

- [Routes](#routes) covers `PartialRoutinator`, the routes header and line keys.
- [Placement](#placement) covers where a Partial's files go.
- [Remapping](#remapping) covers `PartialRemapinator` and a Partial's includes of other Partial modules.
- [Module qualifiers](#module-qualifiers) covers the C names of same-named modules.
- [Directive arguments](#directive-arguments) covers how Ceedling reads a directive's module directory and module.
- [A missing route](#a-missing-route) covers the one failure routes leave.
- [Code](#code) lists the files.

## Routes

A route is the name a Partial directive's `#include` expands to, keyed by the directive's line. `PartialRoutinator` writes one routes header per test, which defines each route as its Partial file's absolute spelling, as a pinned include names its file.

- **`ceedling.h`.** Every Partial directive that forms an `#include` expands to `__PARTIALS_ROUTE_L` joined with `__LINE__`. Neither the module directory nor the module appears in the macro expansion. The `CONFIG` directives expand to nothing.
- **The header.** `ceedling.h` includes `CEEDLING_PARTIALS_ROUTES`, which each run that reads a Partial directive defines as `<ceedling_partials_routes.h>`. The header sits at the top of the Partials root, and that root ends the run's order.
- **Content.** For a test whose line 3 reads `#include TEST_PARTIAL_MODULE_AT(sensors/soil, Calibration)`, the header holds one define for it.

```c
#define __PARTIALS_ROUTE_L3 "/w/proj/build/test/partials/test/test_cal/_t_/src/sensors/soil/ceedling_partial_sensors_soil_Calibration_impl.h"
```

- **Lines.** Compilers differ on the `__LINE__` of a directive continued over several lines. So a route is defined under every line its directive spans. No two directives share a line, so the names never collide.
- **Assembled directives.** A directive written inside a `#define`, as in `#define SENSOR TEST_PARTIAL_MODULE(sensor)`, expands at each `#include SENSOR`. So its route is defined under each test file line whose `#include` names that macro.
- **The test file alone.** A route is keyed by a line of the test file, so a Partial directive in a header the test includes could match the wrong route. Ceedling's text scan of the test's headers finds such a directive, and the build stops before compiling, naming the header and its line.
- **Stage 4.** Stage 4 has its own routes header, at the top of the stand-in root, which routes each line to the Partial's blank stand-in.
- **Rewrites.** A routes header is rewritten only when its content changes, which happens when a directive's text or line changes, or its Partial's placement moves.

## Placement

`Placeinator` places a Partial's files at the build subpath of its module header's directory below the test's Partials root. A module with no header takes its source's directory. `PartialModuleMatchinator` gives the header and source, so the placement follows the header the compiler resolves, never the directive's text.

- **Names.** A Partial's files are `ceedling_partial_<module>_impl.c` and `_impl.h`, `_interface.h`, `_types.h` and `_extras.h`. `<module>` is folded as a C name is, so `my-sensor` writes `my_sensor`, and for an `_AT` directive it carries its module qualifier.
- **Same-named modules.** Two modules of one name in one test sit in their own directories.
- **Mock Partials.** CMock's mock of a Partial's interface sits beside the interface.
- **Reach.** Routes reach every Partial file. The test's search order needs no Partial module directory.

## Remapping

A Partial carries its module's includes, each pinned to its resolution record's hit, or to the test's substitute for it, as every pinned include is. `PartialRemapinator` remaps an include whose hit is another Partial module's header in the same test. The goal is fidelity: a Partial's copied code compiles as its module's source did. So the implementation source keeps the other module's real header, and the three headers name that module's Partial header.

| The other module is | In the implementation source, the include names its | In the implementation, interface and types headers, it names its |
| --- | --- | --- |
| a Test Partial | real header | types header |
| a Mock Partial | real header | interface header |
| both | real header | interface header |

- **Why the source differs.** The implementation source is its own compile, which no other Partial header enters, so the real header gives its code every declaration its module's source had. The headers are included beside other Partial headers in the test, so they take the other module's Partial header, which keeps each type defined once.

- **By key.** The remap compares the hit's key with each Partial module header's key. It never compares names or trailing segments.
- **Staleness.** A Partial's fingerprint holds the files its pins name, so it regenerates whenever a pin changes. That happens when a Partial module whose header it includes joins the test, leaves it or changes between Test and Mock, and when the test gains or loses a substitute for a header it includes.
- **One definition.** A types header writes its types only when its module's own header has not arrived first. The interface and implementation headers define the types header's wanted macro before they define the module header's include guard, and the types header writes under that macro, as the extras header does. The types header defines its own wanted macro too, so it works when included directly.
- **Wanted macro names.** Each is `CEEDLING_PARTIAL_WANTED_<hash>_<MODULE>_<ROLE>`, from the Partial header it gates. The hash comes from that header's path, as a generated include guard's does, so two modules of one name in different directories never share one. `drivers/ceedling_partial_sensor_types.h` gives `CEEDLING_PARTIAL_WANTED_CAADF630_SENSOR_TYPES`.
- **The module header elsewhere.** A Mock Partial's interface defines its module header's include guard, so a user header that includes the module header afterward adds nothing.
- **Collisions it can't prevent.** A Partial's content can still meet its module header's real declarations another way, such as through a header that remapping doesn't reach. A compile that then fails on a redeclaration gets guidance from BuildStepDoctor's `HeaderCollisionSpecialist`, which names the header that arrived a second way.

## Module qualifiers

Two same-named modules in one test need distinct C names, since C has one namespace. A module qualifier keeps the names Ceedling forms apart.

- **The qualifier.** An `_AT` directive's module directory, as [Directive arguments](#directive-arguments) reads it, with each `/` and every other character a C name can't hold written as `_`, as the module's own name is. `TEST_PARTIAL_PUBLIC_MODULE_AT(a, util)` qualifies its names by `a`, and `_AT(drivers-v2, util)` by `drivers_v2`.
- **Collisions.** Folding can give two directives one name, as `_AT(a/b, util)` and `_AT(a, b_util)` both give `a_b_util`. So can a bare module beside a qualified one, as `a_util` beside `_AT(a, util)`, and two bare modules, as `my-sensor` beside `my_sensor`. Two directives in one test whose names fold alike fail at the text scan, before any compile, and the error lists both.
- **Bare directives** stay unqualified, since one test can't hold two bare modules of one name.
- **What it covers.** Every C name Ceedling forms from the module's name, such as a `PARTIAL_TYPE()` type and a promoted static's type. A promoted static's variable, `partial_<function>_<variable>`, holds no module name, so it takes none. It also covers the Partial's file names, so CMock's names for two Mock Partials stay apart whatever `:mock_name_include_folder` says. Routes keep file names out of the test.
- **In a test.** A test names a qualified module as `<qualifier>_<module>`, as in `PARTIAL_TYPE(a_util, s_ctx)`.
- **Function names** stay the module's own. Two same-named modules that define one function name still collide at link, as C requires.

## Directive arguments

Ceedling reads each directive's module directory and module as text, from the test file's text scan. The compiler never sees them, so no macro can change them.

- **Macros are text.** `_AT(platform/linux, port)` names `platform/linux` on every toolchain, and a module named `unix` is the module `unix`.
- **Spaces.** In an unquoted module directory or module, spaces next to each `/`, `-`, `+` and `.` drop, so `src / drivers - v2` names `src/drivers-v2` and `my - sensor` names `my-sensor`, undoing what clang-format writes. The trim runs before every rule, so a spaced `..` is still a climb.
- **Quotes.** A module directory may be quoted. Ceedling strips one pair of double quotes and reads the text between them as written, with no C escapes and no trim, then applies the rules. So a directory whose name holds a spaced operator, as in `a - b`, is written quoted, as in `_AT("a - b", sensor)`. A module stays bare text, since its name is folded into C names.
- **Rules.** A module directory is relative, holds no `..` and is not absolute. Each refusal names the directive, its file and line, and the rule.
- **Characters C reads.** A directory that holds a comma, a parenthesis, an apostrophe or `/*` breaks the directive's macro call before Ceedling's rules apply, so it must be quoted. A BuildStepDoctor specialist, `PartialArgumentSpecialist`, explains the compiler's error for an unquoted one.

## A missing route

A directive that the text scan doesn't read has no route, and the compiler reports an `#include` with no file name. A BuildStepDoctor specialist, `PartialRouteSpecialist`, explains that failure.

- **Symptoms.** GCC's `#include expects "FILENAME" or <FILENAME>` or Clang's `expected "FILENAME" or <FILENAME>`, on a line whose `#include` names a macro, in a test that includes `ceedling.h`. The line need not hold a Partial directive, since a directive another macro assembles expands where that macro is used. Clang's "expanded from macro" note names the macro.
- **Guidance.** It quotes the line as written, and names the two usual causes: a directive assembled in a way the text scan doesn't follow, or one split in a way it doesn't follow.
- **Stage 4.** Stage 4's directives-only run meets a missing route first. It is attended like a full expansion, so the specialist's guidance stops the build there, in place of a fallback.

## Code

- `lib/ceedling/paths/partial_routinator.rb` holds `PartialRoutinator`, a DIY object. `write( test )` writes a test's routes headers from its build plan part.
- `lib/ceedling/paths/partial_remapinator.rb` holds `PartialRemapinator`, a DIY object. `remap( record, test )` gives an include's pinned file, and `qualifier( partial )` gives a module qualifier.
- `lib/ceedling/ceedling.h` defines the Partial directives. Partials generation stays in `lib/ceedling/partials/` and calls these components.
- `PartialRouteSpecialist` and `PartialArgumentSpecialist` live in `lib/ceedling/diagnostics/`.
- Specs: `spec/units/paths/<file>_spec.rb` for each file. The contract rows of area `PART` build real projects, with GCC and Clang.
