# Preprocessing

Ceedling runs the real C preprocessor to answer questions about a test file or header, then rebuilds a usable C file from what it learns. It never reimplements preprocessing. A real preprocessor already understands every conditional and macro trick a project uses; an approximation would not.

The subsystem answers two questions and produces one artifact:

- **What does this file include?** A reconciled, categorized list of a file's own top-level `#include` directives — each tagged user or system, each rendered as it should appear in generated code.
- **What does this file contain once resolved?** The file's text with conditionals resolved and includes followed, either preserving macro directives (for later text extraction) or fully expanded (to see through a macro hiding a signature).
- **A reconstructed C file** built from that resolved text plus the reconciled include list, ready to compile or to feed a mock/Partial generator.

One class is the entry point: `Preprocessinator` (`preprocessinator.rb`). Every other class in this directory does one piece of the job and is named where that piece is described below. Release builds do not use any of this — a release build only needs true dependencies for staleness tracking, handled by a lighter tool.

## Where This Fits in a Test Build

`Preprocessinator`'s public methods are the whole interface. The test pipeline calls them from `test_invoker/` build stages; this document explains their mechanics, not the stage order (documented alongside the pipeline).

- `preprocess_bare_includes(filepath:, test:, search_paths:, flags:, defines:)` — the bare `#include` list only, for early stand-in generation. Returns `Array<Include>`.
- `generate_directives_only_output(filepath:, test:, flags:, include_paths:, vendor_paths:, defines:)` — runs the accurate pass, strips its comments, compacts it. Returns the raw output's path, or `nil` if the preprocessor failed.
- `preprocess_file_includes_common(test:, filepath:, directives_only_filepath:, fallback:, flags:, include_paths:, vendor_paths:, defines:)` — the full extract-reconcile-cache path for a mockable header or a Partial header/source. Returns the reconciled `Array<Include>`.
- `preprocess_mockable_header_file(...)`, `preprocess_partial_header_file_preserve_macros(...)`, `preprocess_partial_source_file_preserve_macros(...)`, `preprocess_test_file(...)` — each extracts includes (via the method above, except the test file, which already has its list), then rebuilds the file.
- `preprocess_partial_header_expand_macros(...)` / `preprocess_partial_source_expand_macros(...)` — the full-expansion pass, for signature extraction.
- `store_includes_list(...)` / `load_includes_list(...)` — the per-file YAML cache of a reconciled list.

## Reading a Line Marker

A C preprocessor flattens a file and every header it pulls in into one stream. To record which piece came from which file, it inserts *line markers*:

```
# 6 "src/module.c" 2
```

The integer is a line number in the named file. The trailing integers are flags: `1` = just entered a new file (an `#include`), `2` = just returned to the previous file, `3` = the entered file is a system header (found on a system path), `4` = implicit `extern "C"`. Walking these flags is how Ceedling attributes flattened output back to real files.

`PreprocessinatorLineMarkerIncludesExtractor` (`preprocessinator_line_marker_includes_extractor.rb`) does that walking. `LINE_MARKER_REGEX` matches a marker; it tolerates leading whitespace (`^\s*`), because `-fdirectives-only` gives an indented `#include` an indented marker (GH #1268). The extractor reads in binary mode — GCC output under a non-C locale carries non-ASCII bytes, and Windows `\r\n` must survive to a per-line `chomp!`.

## Finding Every Include, Accurately

Knowing a file's includes, and whether each is a user or system header, is harder than it sounds. An include-guarded header reached a second time through another path never reappears in the stream. So a single line-marker pass cannot be trusted as a complete top-level list.

Ceedling reconciles two things: a **bare list** of what the file depends on (undifferentiated), and an **accurate list** that categorizes each entry user or system but over-reports (it sees deep nesting). `PreprocessinatorIncludesHandler` (`preprocessinator_includes_handler.rb`) runs every pass and hands each pass's raw output to a parser built for it. `Includes.reconcile` (`includes/includes.rb`) then intersects them.

The bare list has **three contributors**, unioned and deduplicated by filename. Each catches what the others structurally cannot.

### Bare contributor 1 — the isolated gcc dependency pass

`PreprocessinatorIncludesHandler#extract_bare_includes(test:, filepath:, search_paths:, flags:, defines:)` runs:

```
gcc -E -M -MG -MP -I"build/vendor/ceedling" -D"UNIT_TEST" -DGNU_COMPILER -nostdinc -x c "test_module.c"
```

`-M` (not `-MM`) keeps system headers in the rule, so the later intersection filters them by agreement rather than by the compiler's guess. `-MG` treats a missing header as a to-be-generated file instead of an error. `-MP` emits a phony rule per dependency. `-nostdinc` and the vendor-only `-I` keep real project headers off the search path. Output is a make rule, not C:

```
test_module.o: test_module.c unity.h module.h \
  mock_dependency.h
```

`PreprocessinatorBareIncludesExtractor.extract_includes(make_rules)` (`preprocessinator_bare_includes_extractor.rb`) turns each phony `header:` line into a plain `Include`. The handler gates on `MAKE_RULE_MATCHER` first — no rule means the pass produced nothing usable, and it returns `[]`.

Restricting search paths is not enough on its own. A preprocessor's quoted-`#include` resolution *always* also checks the directory of the file being processed. A same-directory sibling header gets opened and recursed into regardless. So `extract_bare_includes` first stages a sibling-free copy of the file into a fresh temp directory (`@file_wrapper.stage_isolated_copies`), runs gcc against that, and removes the copy in an `ensure`. The temp directory is minted inside the test's own `preprocess/files/<test>/` build directory and is not named after the file — both keep the path short for Windows' legacy `MAX_PATH`. Each call gets its own directory, so concurrent preprocessing of sibling files never cross-contaminates.

This pass *can* resolve an `#include` whose target is a macro, because a command-line `-D` is visible even to the isolated copy. It *cannot* see a macro another header defines: a conditional gated on `#if SOMETHING_FROM_ANOTHER_HEADER` evaluates against an undefined macro, resolves the wrong way, and drops a real `#include`.

### Bare contributor 2 — the literal text scan (#1223)

`PreprocessinatorIncludesHandler#extract_bare_includes_from_text(filepath:)` scans the file's own text for anything shaped like an `#include "..."` or `#include <...>` line, evaluating no conditionals at all. It closes the gap above: an `#include` behind a guard the isolated pass can't evaluate still has a literal filename in the text.

The union is safe. `Includes.reconcile` still keeps an entry only if the accurate pass also reports it. The scan can restore an entry both a literal reading and a real preprocessor agree on; it cannot introduce a spurious one.

It has its own blind spot: an `#include` whose target is a macro has no literal filename to find.

### Bare contributor 3 — computed-include correlation (#1267)

`PreprocessinatorIncludesHandler#extract_computed_includes(filepath:, directives_only_filepath:)` covers the case both other contributors miss: a macro-target `#include` *and* a cross-header guard, e.g.

```c
#include "Types.h"                 // defines SOIL_MOISTURE_MAX
#if SOIL_MOISTURE_MAX > 0
#include INCLUDE_DEVICE(types2)    // -> STR(types2.h) -> "types2.h"
#endif
```

The isolated pass can't evaluate the guard; the text scan has no filename. But the accurate `-fdirectives-only` pass *does* open the header and emit an ordinary entering marker for it. The method recovers that resolution:

1. `computed_include_source_lines(filepath)` scans the raw source with `ParsingParcels#code_lines_with_num` (comments stripped, backslash continuations folded). It collects the 1-indexed line of every `#include` directive whose argument matches neither `PATTERNS::USER_INCLUDE_DIRECTIVE_FILENAME` nor `PATTERNS::SYSTEM_INCLUDE_DIRECTIVE_FILENAME` — a bare token, i.e. a macro. The line reported is the directive's ENDING physical line (`code_lines_with_num`'s 3rd yielded value), not its first: `-fdirectives-only` attributes a consumed multi-line directive's own entering marker to the last physical line it spans, not the first, so the two must agree on which line that is. For an ordinary single-line directive the start and end line are the same.
2. `PreprocessinatorLineMarkerIncludesExtractor#resolve_computed_includes(preprocessed_filepath:, source_basename:, source_lines:)` walks the directives-only output. It tracks `src_line`, the source line the next non-marker physical line maps to: a `# n "<source basename>" …` marker sets `src_line = n`; each body line of that file increments it. The macro-target directive is *replaced* by the entering marker for the header it pulled in, so it never appears as a body line — `src_line` still names that directive's line when its entering marker (`flag 1`, another file) appears. Body lines and markers of any other file are skipped, so a header's own nesting can't drift the count. It returns `{ source_line => resolved_path }` for every wanted line that produced an entering marker.
3. Each resolved path becomes a base `Include`.

`preprocess_file_includes_common` unions the result into `bare` right after contributor 2, guarded `unless fallback` — fallback has no directives-only stream to read. `Includes.reconcile` is untouched: the computed include is now corroborated in `bare` like a literal one and still gated by the accurate list.

A computed `#include` split across a backslash continuation, of any length, correlates correctly (characterized in the integration suite alongside the single-line shape). The one real limitation: computed-include resolution is unavailable in fallback mode, since there is no directives-only stream to correlate against at all.

### The accurate pass — directives-only

`generate_directives_only_output` runs:

```
gcc -E -I"src" -D"UNIT_TEST" -x c -fdirectives-only "test_module.c" -o "raw.c"
```

No `-dD`. Conditionals are resolved and includes followed, but macro directives and comments stay as written, and line markers show provenance:

```
# 1 "test_module.c"
# 1 "unity.h" 1
# 1 "module.h" 1
#define MODULE_LIMIT 10 // upper bound
void module_calculate(int value);
# 2 "test_module.c" 2
```

`PreprocessinatorIncludesHandler` reads this twice:

- `extract_user_includes_preprocess(name:, filepath:, preprocessed_filepath:)` → `PreprocessinatorLineMarkerIncludesExtractor#extract_includes_from_file(path, USER, test: name)`. No depth limit — a user header matters however deeply it nests. `test:` lets the extractor strip the test's own mock subdirectory off a resolved mock path.
- `extract_system_includes_preprocess(...)` → `extract_includes_from_file(path, SYSTEM, SYSTEM_INCLUDE_MAX_DEPTH)`. `SYSTEM_INCLUDE_MAX_DEPTH` is a literal `5` in the handler — a practical ceiling, since system headers nest deeply through their own wrappers and anything past a handful of levels is noise, not a project dependency. There is no config key for it.

`generate_directives_only_output` also strips the raw output's comments in place (`PreprocessinatorCommentStripper`) and writes a second, marker-free compacted file (`PreprocessinatorReconstructor`). Line-to-line correspondence with the source survives comment stripping, which is what the computed-include walk depends on.

### Reconciliation

`Includes.reconcile(bare:, user:, system:, test_filepath:, &on_ambiguous)`:

- `bare` must be plain `Include` objects only. `user` / `system` are `UserInclude` / `SystemInclude` (or `MockInclude`).
- A **user** entry survives if some bare entry corresponds to it *by path* — segment-wise, honoring whichever side carries less path. Two same-basename project files in different directories stay distinct. A bare entry matching more than one candidate resolves to the first in `user`'s order (real preprocessor-derived priority) and calls `on_ambiguous` with the bare path, the choice, and the also-rans.
- A **system** entry survives if some bare entry shares its *filename* (system headers legitimately reach one basename through several real files). The kept entry is rebuilt with `include_path:` recovered from `bare` via `best_bare_match`, so `<sys/stat.h>` renders as written, not collapsed to `<stat.h>`.
- A matched user entry renders filename-only by default: Ceedling adds every real source/test/include directory as its own individual search path (no project-root path), so a unique basename already finds the right file, and a resolved-fuller-path candidate (`#include "Types.h"` resolving to `src/Types.h`) would not be found via Ceedling's `-Isrc` convention if rendered verbatim. When two or more matched user entries in the same reconciliation share a basename — a genuine collision, e.g. `#include "hw/config.h"` and `#include "app/config.h"` in one file — each renders instead with the shortest trailing-path suffix of its own real, resolved `filepath` that's unique among the colliding group (`disambiguating_user_include_path`), growing past the first directory level only if that's still ambiguous. This never reaches further than the colliding files' own real containing directories, so it never risks a spelling Ceedling's own search paths can't find.
- `test_filepath` anchors a bare entry's own `..` and names the one file an `on_ambiguous` message should point at.

`Preprocessinator#reconcile_includes(bare:, user:, system:, test_filepath:, drop_mocked: true)` is the shared merge step. It calls `Includes.reconcile`, logs a `NOTICE` on each ambiguity, and — when `drop_mocked` — runs `Includes.sanitize!` to drop a header whose `cmock_mock_prefix`-named mock is also present. Two call sites use it, each owning its own bare source and caching:

- `preprocess_file_includes_common` — mockable headers and Partials. `drop_mocked: true`.
- `test_invoker/test_build_setup.rb` stage 4, third pass — the test file itself. `drop_mocked: false`, because a test's own `#include` of a mock is deliberate. Its bare source is stage 4's own list (no text or computed supplement).

The reconciled list is also cleaned of any self-reference (`clean_self_reference`, normalized-path comparison).

## Expanding a File in Full

A separate pass runs with every macro expanded, for the narrow case where a signature or visibility keyword hides behind a project macro (`#define PRIVATE static`). `Preprocessinator#preprocess_partial_{header,source}_expand_macros` funnel through `_preprocess_partial_expand_macros`, which runs `tools_test_file_full_preprocessor`:

```
gcc -E -I"src" -D"UNIT_TEST" -x c "test_module.c" -o "out.c"
```

`command[:options][:boom] = false` — a nonzero exit must fall back to directives-only signatures, not raise. On failure the method returns `nil`. This is the most expensive mode and is used sparingly.

Directives-only output still shows `PRIVATE void module_calculate(void)`; full-expansion output shows `static void module_calculate(void)` with the `#define` gone.

## Putting a File Back Together

Raw preprocessor output is not a self-contained C file. `PreprocessinatorFileAssembler` (`preprocessinator_file_assembler.rb`) runs the invocations above and stitches the output back. For the stitching it uses `PreprocessinatorReconstructor` (`preprocessinator_reconstructor.rb`), which walks the flattened stream by line marker and keeps only lines belonging to the file being reconstructed:

```
# 1 "some/file/we/do/not/want.c" 5
some_text_we_do_not_want();
# 11 "path/do/want.c" 99999
some_text_we_do_want();
# 3 "some/other/file/we/ignore.c" 5
ignored_text();
```

leaves only `some_text_we_do_want();`. `PreprocessinatorFileAssembler` then places the file's own original `#include` directives — drawn from the reconciled list — back at the top, ahead of the recovered body.

## Comments and Why They Go First

Later steps read macro definitions and marker macros straight out of preprocessor output. A stray comment that resembles a directive would be mistaken for one. `PreprocessinatorCommentStripper` (`preprocessinator_comment_stripper.rb`) removes comments before any such reading, using `CCommentScanner` — a `StringScanner` walk (see the c_extractor docs) that never mistakes a `//` or `/*` inside a string for a comment. A removed multi-line comment is replaced by the same number of blank lines, so every later line-number calculation stays correct.

## Finding Where a Snippet Came From

`PreprocessinatorCodeFinder` (`preprocessinator_code_finder.rb`) traces a piece of already-preprocessed text back to its original file and line by walking backward through the nearest line markers. Ceedling's Partials feature uses this to point a copied-out function at its true source location.

## Caching and the Fallback Path

Running a real preprocessor is expensive and files rarely change. `PreprocessinatorIncludesHandler` owns a per-file YAML cache of reconciled lists (`write_includes_list` / `load_includes_list`, keyed by test and filepath, guarded by a per-file `Mutex`). A corrupt cache raises a `YamlLoadException` wrapped with a clear message. Callers gate every cache use behind their own `DependencyTracker` staleness check.

When a real pass is impossible — the toolchain lacks `-fdirectives-only` (Apple Clang ignores it and warns), or a specific invocation fails — Ceedling falls back to a text scan of the original file, guided by `CPreprocessorConditionals` (`c_preprocessor_conditionals.rb`), which tracks `#ifdef` / `#ifndef` / `#if` / `#elif` / `#else` / `#endif` well enough to skip text real conditional compilation would exclude. `PreprocessinatorIncludesHandler#extract_{user,system}_includes_from_text(name:, filepath:, defines:)` are the fallback counterparts of the directives-only extractors. Fallback is per file: `generate_directives_only_output` returning `nil` for one file drops that file alone to the text path (`directives_only_filepath.nil?` → `fallback` true), while others use the accurate path. Fallback results are less certain, and computed-include resolution is unavailable there.

## Executable Specification

`spec/integration/includes_extraction_spec.rb` is the executable specification of everything above. Each example lays a small C tree on disk, runs the real Preprocessinator graph against real GCC (no `ceedling` build), and asserts the reconciled, rendered list — across accurate and fallback modes, every guard shape, the mock filter, same-basename collisions, and the computed-include matrix. The unit specs under `spec/units/preprocess/` cover each parser's branching in isolation.
