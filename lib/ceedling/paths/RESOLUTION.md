# Resolution

`Resolvinator` finds the file an `#include` names, by the compiler's rules. It resolves in every preprocessing mode from Ceedling's own model of the search order. Line markers and dependency files cross-check it wherever a build has them. Each resolution is recorded once, and later stages read the record.

## Contents

- [Include records](#include-records) are what a search starts from.
- [The model](#the-model) is what a search runs on: listings and the build plan's placements.
- [The search](#the-search) covers the quote rule, angle includes, joins and absolute include text.
- [Results](#results) covers a hit, shadowing, an unresolved include text and the near-miss error.
- [Resolution records](#resolution-records) covers what is kept for later stages and for delta builds.
- [Cross-checks](#cross-checks) compares the model with line markers and dependency files.
- [Fallback](#fallback) covers resolution when preprocessing fails.
- [Code](#code) lists the files and the interface.

## Include records

An include record holds one `#include`: its include text, its form, its includer and its line. Every resolution starts from one.

- **The text scan** gives a record for each `#include` line as written. It reads any include text between the quotes or angle brackets, whatever characters it holds.
- **Intake.** A record's include text passes intake when the record is made, as [PATHS.md](PATHS.md#intake) says. On Windows each `\` becomes `/`, since the file system reads `\` as a separator there. The record keeps the text as written for messages.
- **The includer** is held by its directory as the compiler opened it, which the quote rule searches, as [The search](#the-search) says. So one header reached through a symlink and also directly gives two records, one for each directory.
- **Line markers** give the headers the preprocessor entered. Each depth-1 entry answers one directive of the file being preprocessed. A depth-1 entry from the command line, as a forced include gives, answers no directive.
- **Printed directives.** Stage 4's second pass also prints each `#include` it executes, with its form and its include text after macro expansion, as [STAGES.md](STAGES.md#stage-4) says. A printed directive is active, even where an include guard or `#pragma once` leaves it no depth-1 entry.
- **The form** comes from the text scan's record for the same directive, since line markers don't carry it.
- **A computed `#include`**, whose include text a macro gives, has no text-scan record. Its printed directive gives its include text and form, and line markers show what it entered. The entry is matched to its directive's line by the includer's key, never by basename.
- **`#include_next`** gives a record as `#include` does, marked as a next include, since its search starts later, as [The search](#the-search) says.

## The model

A search asks one question of each directory it tries: does this directory hold the include text? The model answers without asking the disk file by file.

- **A directory of user files** answers from its listing. A directory outside the build root is listed once per build. Text with several segments descends listing by listing, so `drivers/uart.h` from `src` checks `src` for `drivers`, then `src/drivers` for `uart.h`.
- **Entries.** A listing entry answers only when it is a file, or a symlink that reaches one. A directory or a dangling symlink of that name is a miss, since the compiler skips it.
- **Directories on the way.** A join answers only when every directory its text passes through exists, since the kernel resolves each segment in turn. So `sub/../b.h` from `src` is a miss when `src/sub` doesn't exist, and a search path that doesn't exist answers nothing. A generated directory the build plan places counts as existing, since `Placeinator` creates it before any run that searches it.
- **A generated directory** answers from the build plan's placements, which [PLACEMENT.md](PLACEMENT.md) describes. A generated file resolves before it is written, as the compiler will find it.
- **A framework file's directory** answers from the build plan, which places the framework files.
- **Names** compare under the key rule of the directory's root, so a directory on a file system that folds case answers `Foo.h` with `foo.h`.

## The search

A search tries directories in order, and the first directory that holds the include text answers. Resolution follows the order GCC and Clang search. MSVC's `cl` also tries the directory of each open includer after the includer's own, which resolution doesn't model. So a release built with `cl` relies only on includes that GCC would also resolve.

1. **The quote rule.** A quoted include tries its includer's directory first. That is the directory of the includer's absolute spelling, the path the compiler opened it by, and never of its real spelling. So a header reached through a symlink to the file searches the link's directory, as GCC and Clang do. A generated includer's directory comes from the build plan.
2. **The search order.** Each search path of the compile's search order follows, in order. The stage search order sets that list for each compile, as [STAGES.md](STAGES.md#stage-search-orders) says.
3. **Angle includes** skip step 1.
4. **`#include_next`** continues after the search path that answered its includer, as GCC and Clang do. The includer's resolution record gives that search path. An includer that the quote rule reached restarts at the first search path. One reached by absolute spelling, and the file being compiled, search as `#include` does.

Three rules shape each join.

- **Absolute include text** names its file directly, with no search.
- **Climbing text** joins each directory and then collapses by the `..` rule, so `../inc_x.h` from search path `src/sub`, where `src/sub` is no symlink, names `src/inc_x.h`. The join answers only where each directory it passes through exists, as [The model](#the-model) says.
- **Include text is never changed** beyond intake's separators. No extension is swapped, no segment dropped and no case altered.

## Results

A search ends in a hit or leaves the include text unresolved. Each outcome has one handling.

- **A hit** is the `PathRef` of the file the answering directory holds.
- **Shadowing.** When later directories of the same search hold other files with the include text, by key, the hit shadows them. Shadowing compares user files and framework files only. A generated hit stands for its origin, so a substitute that answers ahead of its own origin shadows nothing. Ceedling logs a shadow at COMPLAIN with a NOTICE label. The message names the include as written, its file and line, the hit, each shadowed file and the search paths that hold them, and never a generated directory.
- **Unresolved.** An include text no directory answers is left to the compiler, which may find a system header in its own directories.
- **A letter-case slip.** On a root whose file system keeps case, a directory of the search may hold the include text but for letter case, as `src/uart.h` holds `Uart.h`. Ceedling logs that at COMPLAIN with a WARNING label, naming the include as written, its file and line, and the file. The include is still left to the compiler.
- **A near miss.** No directory answers a quoted include, but a user header ends with the include text by trailing match. It is judged after the directories `:files` ↳ `:include` headers add have joined the order, as [STAGES.md](STAGES.md#the-configured-order) says. Its handling depends on whether the compile processes the directive.
  - **A test file directive the compile processes** stops the build before any compile. That is one stage 4's first pass lists among the files it can't find, or any test file directive without test preprocessing. The error names the include text, the header and both fixes: a search path that joins the text to the header, or include text written from a search path.
  - **Any other record,** such as a header's text-scan record, may sit in a branch that is off. Its near miss logs at COMPLAIN with a NOTICE label, naming the include as written, its file and line, and the header. The include is left to the compiler. If the compile then fails on it, a BuildStepDoctor specialist names the header.
  - **The compiler's own directories** are never read, since search paths come only from configuration.

## Resolution records

A `ResolutionRecord` holds one resolution. The build plan holds every record for the run, and later stages read the records rather than search again.

| Field | Holds |
| --- | --- |
| `include` | The include record: include text, form, includer and line |
| `order` | The stage and a digest of the search order that was searched |
| `hit` | The file's `PathRef`, or nil for an unresolved include text |
| `misses` | Every directory tried before the hit, in order |
| `shadowed` | Every later directory that also held the include text |

The dependency cache saves each target's records between builds. A target that writes pinned includes, such as a runner, a Partial or an isolation copy, holds the records whose hits it pins, since its text follows them. A delta build marks a target stale in two cases:

- its hit changed, as any dependency change marks it;
- a file with the include text appears in one of its misses, so a new header now shadows the old one.

Under isolation, the isolation copy's origin gates the rebuild, never the copy itself, as [ISOLATION.md](ISOLATION.md#rebuilds) says.

## Cross-checks

Where a build has them, line markers and dependency files show what the compiler entered. They confirm the model and never replace it.

- Line markers exist only with test or mock preprocessing on. A dependency file exists only after a compile, from a toolchain that writes one.
- **Line markers.** Each depth-1 line-marker entry checks its directive's record. A printed directive with no entry checks nothing, since the compiler entered its file earlier.
- **Dependency files.** Each record of an object's compile checks that the object's dependency file lists its hit. Stage 14 resolves those records with the object's own stage search order, so a mock, a substitute, a Partial or a routes header that the dependency file lists is a record's hit like any other.
- **What checks nothing.** An unresolved record checks nothing, since the compiler's own directories answer it. A file the compiler entered that no record names, such as a system header's own include, is no mismatch. `-MMD` leaves out each file a `#pragma GCC system_header` or `#pragma clang system_header` brings in, so a hit it leaves out for that reason is no mismatch, and stays an input.
- **No line markers.** A directives-only run that succeeds but writes no line marker for its file, as with `-P`, gives no cross-check. Its records stand, and dependency tracking keeps them.
- **Mismatches.** Both comparisons are by key. A mismatch logs at COMPLAIN with a NOTICE label that names the include as written, its file and line, Ceedling's answer and the compiler's. Dependency tracking then uses the compiler's answer.
- **Origins.** In dependency tracking, each substitute's origin stands for it, as [ISOLATION.md](ISOLATION.md#rebuilds) says of isolation copies.

## Fallback

When a file's directives-only preprocessing fails, resolution runs on the file's text-scan records instead. The text scan evaluates no `#if`, so an include inside a branch that depends on another header's macro is a best-effort guess. Each fallback logs at COMPLAIN, which carries a WARNING label, and names the file and the limit. The build goes on.

- **The test file.** Stage 4's first pass evaluates every `#if` with stand-ins in place, so a fallback for the test file keeps only the text-scan records whose include text that pass reached: a file it entered or a name it listed as missing.

## Code

- `lib/ceedling/paths/resolvinator.rb` holds `Resolvinator`, a DIY object. It depends on the build plan, for placements, and on the logger. It keeps the listings for one build.
- `lib/ceedling/paths/resolution_record.rb` holds `ResolutionRecord`, an immutable value.
- `resolve( include, search_order: )` returns a `ResolutionRecord`. `listing( dir )` returns one directory's names under its key rule.
- Specs: `spec/units/paths/resolvinator_spec.rb` stubs listings and placements. The contract rows of area `RES` build real projects.
