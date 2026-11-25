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
- **Line markers** give the headers the preprocessor entered. Each depth-1 entry answers one directive of the file being preprocessed.
- **The form** comes from the text scan's record for the same directive, since line markers don't carry it.
- **A computed `#include`**, whose include text a macro gives, has no text-scan record. Line markers show what it entered. The entry is matched to its directive's line by the includer's key, never by basename.

## The model

A search asks one question of each directory it tries: does this directory hold the include text? The model answers without asking the disk file by file.

- **A directory of user files** answers from its listing. A directory outside the build root is listed once per build. Text with several segments descends listing by listing, so `drivers/uart.h` from `src` checks `src` for `drivers`, then `src/drivers` for `uart.h`.
- **A generated directory** answers from the build plan's placements, which [PLACEMENT.md](PLACEMENT.md) describes. A generated file resolves before it is written, as the compiler will find it.
- **A framework file's directory** answers from the build plan, which places the framework files.
- **Names** compare under the key rule of the directory's root, so a directory on a file system that folds case answers `Foo.h` with `foo.h`.

## The search

A search tries directories in order, and the first directory that holds the include text answers.

1. **The quote rule.** A quoted include tries its includer's directory first. A generated includer's directory comes from the build plan.
2. **The search order.** Each search path of the compile's search order follows, in order. The stage search order sets that list for each compile, as [STAGES.md](STAGES.md#stage-search-orders) says.
3. **Angle includes** skip step 1.

Three rules shape each join.

- **Absolute include text** names its file directly, with no search.
- **Climbing text** joins each directory and then collapses by the `..` rule, so `../inc_x.h` from search path `src/sub` names `src/inc_x.h`.
- **Include text is never changed.** No extension is swapped, no segment dropped and no case altered.

## Results

A search ends in a hit or leaves the include text unresolved. Each outcome has one handling.

- **A hit** is the `PathRef` of the file the answering directory holds.
- **Shadowing.** When later directories of the same search also hold the include text, the hit shadows them. Ceedling logs it at COMPLAIN with a NOTICE label. The message names the include text, the hit, the search order and each shadowed candidate.
- **Unresolved.** An include text no directory answers is left to the compiler, which may find a system header in its own directories.
- **A near miss stops the build.** If no directory answers a quoted include but a user header ends with the include text by trailing match, the build stops before any compile. The error names the include text, the header and both fixes: a search path that joins the text to the header, or include text written from a search path.

## Resolution records

A `ResolutionRecord` holds one resolution. The build plan holds every record for the run, and later stages read the records rather than search again.

| Field | Holds |
| --- | --- |
| `include` | The include record: include text, form, includer and line |
| `order` | The stage and a digest of the search order that was searched |
| `hit` | The file's `PathRef`, or nil for an unresolved include text |
| `misses` | Every directory tried before the hit, in order |
| `shadowed` | Every later directory that also held the include text |

The dependency cache saves each target's records between builds. A delta build marks a target stale in two cases:

- its hit changed, as any dependency change marks it;
- a file with the include text appears in one of its misses, so a new header now shadows the old one.

Under isolation, the isolation copy's origin gates the rebuild, never the copy itself, as [ISOLATION.md](ISOLATION.md#rebuilds) says.

## Cross-checks

Where a build has them, line markers and dependency files show what the compiler entered. They confirm the model and never replace it.

- Line markers exist only with test or mock preprocessing on. A dependency file exists only after a compile, from a toolchain that writes one.
- Each depth-1 line-marker entry checks its directive's record. Each dependency file's names check its object's records. Both comparisons are by key.
- A mismatch logs at COMPLAIN with a NOTICE label that names both answers. Dependency tracking then uses the compiler's answer.

## Fallback

When a file's directives-only preprocessing fails, resolution runs on the file's text-scan records instead. The text scan evaluates no `#if`, so an include inside a branch that depends on another header's macro is a best-effort guess. Each fallback logs at COMPLAIN, which carries a WARNING label, and names the file and the limit. The build goes on.

## Code

- `lib/ceedling/paths/resolvinator.rb` holds `Resolvinator`, a DIY object. It depends on the build plan, for placements, and on the logger. It keeps the listings for one build.
- `lib/ceedling/paths/resolution_record.rb` holds `ResolutionRecord`, an immutable value.
- `resolve( include, search_order: )` returns a `ResolutionRecord`. `listing( dir )` returns one directory's names under its key rule.
- Specs: `spec/units/paths/resolvinator_spec.rb` stubs listings and placements. The contract rows of area `RES` build real projects.
