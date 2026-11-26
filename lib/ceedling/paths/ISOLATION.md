# Isolation

Isolation makes every include in a test's build reach the test's substitutes, including the includes the quote rule would send to the origin. `Isolator` plans it from the build plan's resolution records, before stage 15. `Placeinator` places each isolation copy in the test's overlay, as [PLACEMENT.md](PLACEMENT.md#overlays) describes.

## Contents

- [The gap](#the-gap) says why overlays alone don't reach every substitute.
- [Planning](#planning) gives the rule `Isolator` applies, and when.
- [Copies](#copies) covers what an isolation copy holds and where it sits.
- [Sources](#sources) covers compiling a source from its copy.
- [Rebuilds](#rebuilds) covers how a copy's origin stands for the copy.
- [Code](#code) lists the files and the interface.

## The gap

Under `:treat_inlines` ↳ `:include`, CMock's copy substitutes each mocked header, and overlays carry every search-order path to it. The quote rule is the one path overlays can't carry. A file beside a substituted header that quote-includes it reaches the origin, since the compiler tries the includer's directory before any search path.

## Planning

`Isolator` closes the gap with isolation copies. It plans them from resolution records, so it needs no compile's output.

- **The rule.** Every user file the test's build enters that reaches a substituted header by the quote rule, directly or through other such files, gets an isolation copy.
- **By key.** Hits compare by key. So a file reached through any search path, `.` included, and by any spelling, counts the same way.
- **Its input.** `Isolator` reads the include records of every header and source the test's compiles enter. The text scan reads each such file once per change to it.
- **Timing.** Header copies are planned at stage 5, for the files the test's compiles enter by then. Source copies are planned at stage 14, once a test's sources are final, since `TEST_SOURCE_FILE()` entries arrive at stage 11 under test preprocessing. The header copies that only those sources enter are planned with them, at stage 14. All of it precedes stage 15, which writes no plan state.
- **Writing.** A header copy is written as soon as it is planned, so it exists before any run that can enter it.
- **No substitute, no copies.** A test that substitutes no header needs no isolation.
- **`#include_next` headers.** A header whose text holds `#include_next` never gets a copy. The copy's next search would continue after the copy's overlay, at the search path that overlay repeats, and so enter the copy's own origin. So where the rule calls for one, planning stops the build and names the header and the substituted header it reaches. This matches [PLACEMENT.md](PLACEMENT.md#pinned-includes)'s rule for pinned includes.

## Copies

An isolation copy sits at its origin's build subpath in the overlay, under the origin's name. Overlays reach it wherever user text would reach the origin through a search path, through a symlink or a climb included, as [PLACEMENT.md](PLACEMENT.md#overlays) says. The copy then reaches the substitutes.

- **Pinned includes.** The copy pins each of its origin's includes, so its own includes never depend on its directory. A computed include stays as written and logs at COMPLAIN with a WARNING label, as [PLACEMENT.md](PLACEMENT.md#pinned-includes) says.
- **`#line`.** Each copy opens with a `#line 1` directive naming its origin. Compiler messages, `__FILE__` and line markers then name the origin.
- **Stability.** A copy is an artifact like any other, owned in the ledger and rewritten only when its text changes.
- **The compilation database** names a copy's origin in the copy's place, as [EDGES.md](EDGES.md#compile_commandsjson) says. A replay can then reach a file beside the origin where the compile reached the test's substitute.

## Sources

A source in the isolated set compiles from its copy, in every object of its test. Its pinned includes name the files its origin's includes resolve to, with the test's substitutes in their place. So no directory moves in its search order, and its object takes the origin's build subpath as any source's does.

## Rebuilds

The dependency cache records a copy's origin, never the copy, as the dependency of every target that entered the copy. The build plan maps each copy to its origin, so no dependency file is rewritten.

A copy's pins are in the fingerprint of every object whose compile enters it, as [PLACEMENT.md](PLACEMENT.md#fingerprints) says. So a change to the test's substitutes rebuilds those objects, though the origin is unchanged.

## Code

- `lib/ceedling/paths/isolator.rb` holds `Isolator`, a DIY object. It depends on the build plan and `Placeinator`.
- `plan( test, stage: )` returns the isolation copies for one test's part of the build plan: header copies at stage 5, and at stage 14 the source copies with the header copies only those sources enter.
- Specs: `spec/units/paths/isolator_spec.rb` stubs resolution records. The contract rows of area `ISO` build real projects.
