# Sibling-Header Isolation and Reactive Collision Guidance

A mock or a Partial exists to substitute one header's content for another. That substitution only ever sees what a test file's own `#include` directives name directly -- it has no visibility into a module's full, transitive `#include` closure. A module reaching the *same real header* a second way, through some other, unrelated `#include` chain, can slip right past the substitution: the mock or Partial still gets generated and still gets `#include`d, but the real header's own content ends up in the compile too, unmocked. `TestBuildExecutor` prevents this gap where it can, and the build step doctor explains a collision that prevention can't resolve.

## Why it happens: quote-include's same-directory rule

C's `#include "..."` form checks the *including file's own directory* before it ever consults a search path (`-I`). A mock or Partial substitutes a header by relying on search-path order -- the mocks/Partials directory is listed ahead of the real header's own directory, so an ordinary `#include "the_header.h"` finds the substitute first. That ordering means nothing, though, to a *different* file that happens to live in the same directory as the real header and does its own `#include "the_header.h"`: that file's own directory is checked first, finds the real header sitting right beside it, and never consults `-I` at all. Nothing about this is a Ceedling bug in the ordinary sense -- it's C's own quote-include resolution rule, doing exactly what it's specified to do, in a situation Ceedling's substitution scheme didn't account for.

Every remedy below works the same way: a file is copied alone into a fresh directory, where its quoted `#include` has no neighbor to find. `QuoteIncludeIsolator` (`lib/ceedling/quote_include_isolator.rb`) owns that staging, its release, and mapping a copy's path back to its original.

A copy is a tool for compiling, never a dependency. Its directory takes a new name every time and is removed afterward, so dependency tracking records the original wherever a copy was used. An unchanged rebuild then compiles nothing, and an edit to an original rebuilds what reached it through a copy.

## Prevention: `isolate_sibling_headers`

Right after a test file's own compile, its freshly-written `.d` dependency file already reveals every real header reachable from it -- including a header whose content only got *reached*, not necessarily *used* (gcc's dependency output is guard-blind: a header still counts as a dependency even when its content was fully skipped by an already-satisfied include guard). For prevention, that's enough: knowing two files merely *could* collide is all a fix needs, since it doesn't have to resolve which copy would actually win.

Isolation can redirect a quoted `#include` only to a file of the same name earlier on the search path. CMock writes one for each header it mocks under `:cmock` ↳ `:treat_inlines: :include`: an inline-stripped copy in the mocks directory. Nothing else does, so isolation considers only those headers (`TestSubstitutions#shadowed_headers`). With other mocks and with Partials, a sibling's quoted `#include` would find the real header through the search paths anyway.

`isolate_sibling_headers` (in `TestBuildExecutor`) parses that `.d` file and checks, for each of those headers, whether the same directory also holds some other header the test's compile reached and that quote-includes it by name. Any it finds get staged, together, into one new directory of their own via `QuoteIncludeIsolator#isolate` -- copied there alone, with nothing else beside them, so their own `#include` of the real header can no longer take the same-directory shortcut and gets forced through search paths instead, where CMock's copy is listed first. Each copy opens with `#line 1 "<original path>"`, so diagnostics, `__FILE__`, debug info and coverage data name the original header. The test's own object then recompiles with that isolation directory prepended to its search paths.

Isolation acts only one level deep, and only around a header CMock copies. A directory elsewhere in the same dependency list can hold several headers the test reaches, none of them mocked or Partialized. It is shaped the same way, but nothing designates which occupant should win, so isolation leaves it alone and logs nothing. If the compilation then fails with a collision there, the doctor's shared-directory diagnosis explains it (see below).

The isolated directory this produces is a *throwaway*: it's always freshly, fully derived from files already tracked by the dependency tracker, so it can never itself go stale independently and needs no tracking of its own. The test's own retry compile writes to a separate dependencies path that's never registered -- only the original attempt's own `.d` file (real headers, real paths) is what the dependency tracker keeps, unchanged. The directory itself is scoped to this one test's whole build, not to a single object: every other object in the same test needs to see the same corrected search paths, which is why `stage_build_objects` compiles a test's own file in a batch fully completed before any other object in that test starts (a real barrier, since `Batchinator#exec` blocks until every item in a batch finishes -- without it, another object could finish compiling with the original, uncorrected paths before the fix landed). The testable keeps the whole isolation, its directory and its copies, in `header_isolation`. The directory is removed once, after both batches of the whole build finish or when a compile fails.

Every later object compiled with the isolation directory keeps it out of its dependencies two ways:

- Its staleness meta records its search paths without the directory, plus the isolated originals under `isolated:`. A change to which files are isolated rebuilds the object, while the directory's own name never counts.
- `QuoteIncludeIsolator#restore_dependencies` rewrites its `.d` file to name each original in place of its copy before it is registered. An edit to an original then rebuilds every object that reached it through the copy.

`extract_bare_includes` (`preprocess/preprocessinator_includes_handler.rb`) stages an isolated copy for an unrelated reason -- limiting a preprocessor scan to a file's own top-level `#include`s -- using the same `QuoteIncludeIsolator` this mechanism does; see its own comment there for that story.

## Sources under test: `compile_isolated_source`

A source under test can sit beside a header its test mocks and quote-include it directly. Under `:cmock` ↳ `:treat_inlines: :include` that source finds the real header first, so the real inline bodies run in place of the mock. Sibling-header isolation never sees this case: the source is not a header, and it never appears in the test file's `.d` file.

`TestBuildExecutor#inline_mocked_sibling_header` decides it up front, before any compile. A source qualifies when mocks are enabled, inline handling is `:include`, the mock is not a Partial mock, the source is not the test file, the source shares the real header's directory, and `QuoteIncludeIsolator#includes_by_name?` finds the header named in a quoted `#include`. Only then does CMock's same-basename shadow exist on the search path for the source to reach.

`compile_isolated_source` compiles a qualifying source from a copy staged alone by `QuoteIncludeIsolator#within`. Three details keep the copy invisible to everything except header lookup:

- The copy opens with `#line 1 "<original path>"`, so diagnostics, `__FILE__`, debug info and coverage data name the original at its original line numbers.
- The original's directory is appended after every other search path. The copy's other quoted includes, relative paths among them, still resolve, while the mocks directory keeps precedence.
- `QuoteIncludeIsolator#restore_dependencies` rewrites the compile's `.d` file to name the original before it is registered, so dependency tracking never records a file that is removed when the compile ends.

`Generator#generate_object_file_c` receives the copy as `compile_source:`. Plugins and logs keep receiving the original as `:source`. Each staging lives for one compile and writes nothing to the testable, so it never interacts with the two-pass barrier in `stage_build_objects`. Like header isolation it acts one level deep. A source reaching the real header only through a private header of its own is not redirected.

## What isolation can't fix: Partials, and the reactive fallback

CMock's own mock generation, when `:treat_inlines: :include` is configured, produces a same-basename shadow of the real header -- a safe replacement sharing the real header's own filename and include guard, which is exactly what gives an isolated sibling's own `#include` something to fall through to on `-I`. Partials generates *distinctly-named* files instead; there's never a same-basename replacement waiting on a search path for an isolated sibling to find, so isolation never runs for a Partialized header. When a Partial's own generated content and its module's real, un-Partialized header both reach one compile, isolation has structurally nothing to redirect -- the collision is a straightforward `redeclaration`/`conflicting types`/`previous definition` compile error, and it stays one no matter how the search paths are arranged.

`HeaderCollisionSpecialist` (`lib/ceedling/diagnostics/`) is the deliberate fallback, for this case and for any other collision isolation doesn't resolve. When a test's compilation fails, `TestBuildExecutor` hands its output and inputs to the build step doctor (see `diagnostics/DOCTOR.md`). The specialist matches the redeclaration and conflicting-types wordings of many toolchains, then examines the case two ways. Each logs a notice at `ERRORS` verbosity before the compiler's error is raised:

- **A substituted header colliding with its real content.** The output names a real header this test mocks or Partializes. The notice explains how the real content can arrive through a second `#include` chain, and how to break it.
- **A collision in a shared directory.** The output names a header whose directory holds other headers this test reaches, none of them substituted and none of them Ceedling's own. The first compilation attempt's `.d` file decides what the test reaches. A toolchain that writes no `.d` file leaves the directory's listing instead. One notice is logged per such directory, naming only the headers the compiler named. It explains the quote-include rule, isolation's limits, and how to make each declaration arrive once.

Both read the same failure, so one compilation can draw both notices.
